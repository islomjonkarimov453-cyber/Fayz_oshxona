import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

List<FishOrder> _fishFromTable(TableData table) {
  final details = table.fishOrders
      .where((order) => fishKeys.contains(order.key) && order.kg > 0)
      .toList();
  final covered = <String, double>{};
  for (final order in details) {
    covered[order.key] = round2((covered[order.key] ?? 0) + order.kg);
  }
  final result = List<FishOrder>.from(details);
  for (final key in fishKeys) {
    final qty = table.items[key] ?? 0;
    final remaining = round2(qty - (covered[key] ?? 0));
    if (remaining > 0.001) {
      result.add(FishOrder(key: key, kg: remaining, onion: 'sovussiz', cut: 'butun'));
    }
  }
  return result;
}

/// Buyurtma tahrirlash: miqdor kiritish, oshxonaga yuborish va chek yopish.
class OrderEditorScreen extends StatefulWidget {
  const OrderEditorScreen({
    super.key,
    required this.store,
    required this.tableKey,
  });

  final AppStore store;
  final String tableKey;

  @override
  State<OrderEditorScreen> createState() => _OrderEditorScreenState();
}

class _OrderEditorScreenState extends State<OrderEditorScreen> {
  final Map<String, double> _draft = {};
  final Set<String> _removed = {};
  final List<Map<String, dynamic>> _fishOrders = [];
  List<FishOrder> _existingFish = [];
  bool _fishDirty = false;
  final TextEditingController _address = TextEditingController();
  bool _fishPicker = false;
  bool _busy = false;

  String get _key => widget.tableKey;
  AppStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _address.text = _store.table(_key).address;
    _existingFish = _fishFromTable(_store.table(_key));
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Map<String, double> get _existing => _store.table(_key).items;

  List<FishOrder> get _allFish => [
        ..._existingFish,
        ..._fishOrders.map(
          (order) => FishOrder.fromJson(Map<String, dynamic>.from(order)),
        ),
      ];

  Map<String, double> _numericItems() {
    final items = <String, double>{};
    _existing.forEach((key, value) {
      if (!fishKeys.contains(key) && key != '_fish' && !_removed.contains(key)) {
        items[key] = value;
      }
    });
    _draft.forEach((key, value) {
      if (value > 0 && !fishKeys.contains(key) && !_removed.contains(key)) {
        items[key] = round2((items[key] ?? 0) + value);
      }
    });
    final quantities = <String, double>{};
    for (final order in _allFish) {
      if (order.kg > 0) {
        quantities[order.key] = round2((quantities[order.key] ?? 0) + order.kg);
      }
    }
    quantities.forEach((key, value) => items[key] = value);
    return items;
  }

  Map<String, dynamic> _billItems() {
    final items = <String, dynamic>{..._numericItems()};
    if (_allFish.isNotEmpty) {
      items['_fish'] = _allFish
          .map(
            (order) => {
              'key': order.key,
              'kg': order.kg,
              'onion': order.onion,
              'cut': order.cut,
            },
          )
          .toList();
    }
    return items;
  }

  Map<String, double> get _combined => _numericItems();

  double get _newSubtotal =>
      _store.snapshot.money(_draft) +
      _fishOrders.fold<double>(
        0,
        (sum, order) =>
            sum + asDouble(order['kg']) * _store.price((order['key'] ?? '').toString()),
      );

  void _setDraft(String key, double value) {
    if (_removed.contains(key)) return;
    setState(() {
      if (value <= 0) {
        _draft.remove(key);
      } else {
        _draft[key] = round2(value);
      }
    });
  }

  void _change(String key, double delta) {
    _setDraft(key, (_draft[key] ?? 0) + delta);
  }

  Future<void> _editQuantity(String key) async {
    final controller =
        TextEditingController(text: quantityText(_draft[key] ?? 0));
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${productName(key)} miqdori'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            suffixText: productByKey(key).unit,
            hintText: '0',
          ),
          onSubmitted: (text) =>
              Navigator.of(dialogContext).pop(_parse(text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_parse(controller.text)),
            child: const Text('Tayyor'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) _setDraft(key, value);
  }

  double? _parse(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _deleteExisting(String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mahsulotni o‘chirish'),
        content: Text('${productName(key)} ni buyurtmadan o‘chirasizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Yo‘q'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ha'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _removed.add(key);
      _draft.remove(key);
    });
  }

  void _restoreExisting(String key) {
    setState(() => _removed.remove(key));
  }

  Future<void> _saveAddress() async {
    final text = _address.text.trim();
    if (text == _store.table(_key).address) return;
    await runMutation(
      context,
      _store,
      () => _store.saveAddress(_key, text),
      successText: 'Manzil saqlandi',
    );
  }

  /// Baliq tanlangach: sovusli/sovussiz va butun/kusok so'raladi.
  Future<void> _askOnion(String key, double kg) async {
    final onion = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${productName(key)} — ${quantityText(kg)} kg'),
        content: const Text('Piyoz turi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('sovussiz'),
            child: const Text('Sovussiz'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('sovusli'),
            child: const Text('Sovusli'),
          ),
        ],
      ),
    );
    if (onion == null || !mounted) return;
    final cut = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${productName(key)} — ${quantityText(kg)} kg'),
        content: const Text('Butun yoki kusok?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('butun'),
            child: const Text('Butun'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('kusok'),
            child: const Text('Kusok'),
          ),
        ],
      ),
    );
    if (cut == null || !mounted) return;
    setState(() {
      _fishOrders.add({'key': key, 'kg': kg, 'onion': onion, 'cut': cut});
    });
  }

  Future<void> _editExistingFish(int index) async {
    final order = _existingFish[index];
    final kgController = TextEditingController(text: quantityText(order.kg));
    var onion = order.onion;
    var cut = order.cut;
    final result = await showDialog<FishOrder>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${productName(order.key)} — tahrirlash'),
        content: StatefulBuilder(
          builder: (dialogContext, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: kgController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(labelText: 'Og\'irligi (kg)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: onion,
                decoration: const InputDecoration(labelText: 'Piyoz'),
                items: const [
                  DropdownMenuItem(value: 'sovusli', child: Text('Sovusli')),
                  DropdownMenuItem(value: 'sovussiz', child: Text('Sovussiz')),
                ],
                onChanged: (value) =>
                    setDialogState(() => onion = value ?? onion),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: cut,
                decoration: const InputDecoration(labelText: 'Shakli'),
                items: const [
                  DropdownMenuItem(value: 'butun', child: Text('Butun')),
                  DropdownMenuItem(value: 'kusok', child: Text('Kusok')),
                ],
                onChanged: (value) =>
                    setDialogState(() => cut = value ?? cut),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              final kg = asDouble(kgController.text);
              if (kg <= 0) return;
              Navigator.of(dialogContext).pop(
                FishOrder(key: order.key, kg: kg, onion: onion, cut: cut),
              );
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    kgController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _existingFish[index] = result;
      _fishDirty = true;
    });
  }

  Future<void> _deleteFishAt(int index) async {
    final existing = index < _existingFish.length;
    if (existing) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Baliqni o\'chirish'),
          content: const Text('Bu baliqni buyurtmadan o\'chirasizmi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Yo\'q'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ha'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      setState(() {
        _existingFish.removeAt(index);
        _fishDirty = true;
      });
    } else {
      setState(() => _fishOrders.removeAt(index - _existingFish.length));
    }
  }

  Widget _fishRow(BuildContext context, int index, FishOrder order) {
    final palette = AppPalette.of(context);
    final existing = index < _existingFish.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName(order.key),
                  style: TextStyle(
                    color: palette.tx,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${quantityText(order.kg)} kg · ${order.onionLabel} · ${order.cutLabel}${existing ? '' : ' · yangi'}',
                  style: TextStyle(color: palette.mut, fontSize: 12),
                ),
              ],
            ),
          ),
          if (existing)
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 20, color: palette.pri),
              onPressed: () => _editExistingFish(index),
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: palette.bad),
            onPressed: () => _deleteFishAt(index),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_busy ||
        (_newSubtotal <= 0 &&
            _fishOrders.isEmpty &&
            !_fishDirty &&
            _removed.isEmpty)) {
      return;
    }
    setState(() => _busy = true);

    final items = _billItems();
    final fish = <String, double>{};
    for (final order in _fishOrders) {
      final key = (order['key'] ?? '').toString();
      final quantity = asDouble(order['kg']);
      if (quantity > 0) fish[key] = round2((fish[key] ?? 0) + quantity);
    }
    final fishOrders = _fishOrders.isEmpty
        ? null
        : List<Map<String, dynamic>>.from(_fishOrders);

    try {
      await _store.mutate(() async {
        if (items.isEmpty) {
          await _store.deleteTableState(_key);
        } else {
          await _store.saveTableState(
            _key,
            items,
            address: _address.text.trim(),
            linkedTable: _store.table(_key).linkedTable,
          );
          if (fish.isNotEmpty) {
            await _store.createTicket(_key, fish, fishOrders: fishOrders);
          }
        }
      });
      if (!mounted) return;
      final combinedFish = _allFish;
      setState(() {
        _draft.clear();
        _fishOrders.clear();
        _existingFish = combinedFish;
        _fishDirty = false;
        _removed.clear();
      });
      showMessage(
        context,
        fish.isEmpty ? 'Buyurtma saqlandi' : 'Oshxonaga yuborildi 🐟',
      );
    } catch (error) {
      if (mounted) {
        showMessage(context, errorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeTable() async {
    if (_busy) return;
    final items = _billItems();
    final numericItems = _numericItems();
    final subtotal = _store.snapshot.money(numericItems);
    if (subtotal <= 0) return;

    setState(() => _busy = true);
    final pct = _store.servicePercentFor(_key);
    final fee = (subtotal * pct / 100).roundToDouble();
    final total = round2(subtotal + fee);

    try {
      final sale = await _store.createSale({
        'table': _key,
        'items': items,
        'sub': round2(subtotal),
        'pct': pct.round(),
        'fee': fee,
        'total': total,
        'prices': _store.snapshot.prices,
        'address': _address.text.trim(),
        'linked_table': _store.table(_key).linkedTable,
        'clear_table': true,
      });
      if (!mounted) return;
      await showReceipt(context, sale, _store.snapshot);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        showMessage(context, errorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _goBack() async {
    final exists = _store.snapshot.tables.containsKey(_key);
    final empty = _store.table(_key).items.isEmpty &&
        _draft.isEmpty &&
        _fishOrders.isEmpty;
    if (isSaboyKey(_key) && exists && empty) {
      try {
        await _store.mutate(() => _store.deleteTableState(_key));
      } catch (_) {
        // Bo'sh saboyni o'chirib bo'lmasa ham chiqamiz.
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final combined = _combined;
        final subtotal = _store.snapshot.money(combined);
        final pct = _store.servicePercentFor(_key);
        final fee = (subtotal * pct / 100).roundToDouble();
        final total = subtotal + fee;
        final canSend = (_newSubtotal > 0 ||
                _fishOrders.isNotEmpty ||
                _fishDirty ||
                _removed.isNotEmpty) &&
            !_busy;
        final canClose = subtotal > 0 && !_busy;
        final allFish = _allFish;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _busy ? null : _goBack,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    tableLabel(_key),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              if (isSaboyKey(_key)) ...[
                TextField(
                  controller: _address,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveAddress(),
                  decoration: InputDecoration(
                    labelText: '📍 Manzil',
                    hintText: 'Mijoz manzili',
                    suffixIcon: IconButton(
                      tooltip: 'Manzilni saqlash',
                      icon: const Icon(Icons.check),
                      onPressed: _busy ? null : _saveAddress,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _FishSection(
                store: _store,
                pickerOpen: _fishPicker,
                onTogglePicker: () =>
                    setState(() => _fishPicker = !_fishPicker),
                onPickFish: (entry) => _askOnion(entry.key, entry.kg),
              ),
              if (allFish.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Buyurtmadagi baliqlar',
                  style: TextStyle(
                    color: palette.tx,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < allFish.length; i++)
                  _fishRow(context, i, allFish[i]),
              ],
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.line),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            'Boshqa',
                            style: TextStyle(
                              color: palette.mut,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final key in otherKeys) _row(context, key),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.line),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _sumRow(context, 'Taomlar', subtotal),
                    const SizedBox(height: 6),
                    _sumRow(
                      context,
                      'Xizmat haqi (${pct.round()}%)',
                      fee,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: palette.line, height: 1),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Jami',
                            style: TextStyle(
                              color: palette.tx,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${money(total)} so\'m',
                          style: TextStyle(
                            color: palette.tx,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_draft.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Yangi qo\'shilgan: ${money(_newSubtotal)} so\'m',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.mut, fontSize: 12),
                ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canSend ? _send : null,
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: const Text('Oshxonaga'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canClose ? _closeTable : null,
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Chek'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.ok,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, String key) {
    final palette = AppPalette.of(context);
    final def = productByKey(key);
    final existing = _existing[key] ?? 0;
    final draft = _draft[key] ?? 0;
    final removed = _removed.contains(key);
    final effectiveExisting = removed ? 0.0 : existing;
    final combined = effectiveExisting + draft;
    final price = _store.price(key);
    final unit = def.unit;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.name,
                  style: TextStyle(
                    color: palette.tx,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${money(price)} so\'m / $unit'
                  '${effectiveExisting > 0 ? '  ·  buyurtmada: ${quantityText(effectiveExisting)} $unit' : ''}'
                  '${removed ? '  ·  o‘chirildi' : ''}'
                  '${key == 'tabaka' ? '  ·  qoldiq: ${quantityText(_store.snapshot.stock['tabaka'] ?? 0)} dona' : ''}',
                  style: TextStyle(color: palette.mut, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _StepButton(
            icon: Icons.remove,
            enabled: !removed && draft > 0,
            onTap: () => _change(key, -def.step),
          ),
          InkWell(
            onTap: removed ? null : () => _editQuantity(key),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 36,
              alignment: Alignment.center,
              child: Text(
                quantityText(draft),
                style: TextStyle(
                  color: palette.tx,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            enabled: !removed,
            onTap: () => _change(key, def.step),
          ),
          if (existing > 0)
            IconButton(
              icon: Icon(
                removed ? Icons.undo : Icons.delete_outline,
                size: 20,
                color: removed ? palette.pri : palette.bad,
              ),
              tooltip: removed ? 'Qaytarish' : 'O‘chirish',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () =>
                  removed ? _restoreExisting(key) : _deleteExisting(key),
            ),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: Text(
              money(combined * price),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.tx,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumRow(BuildContext context, String label, double value) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: palette.mut, fontSize: 13.5),
          ),
        ),
        Text(
          '${money(value)} so\'m',
          style: TextStyle(color: palette.tx, fontSize: 13.5),
        ),
      ],
    );
  }
}

class _FishSection extends StatefulWidget {
  const _FishSection({
    required this.store,
    required this.pickerOpen,
    required this.onTogglePicker,
    required this.onPickFish,
  });

  final AppStore store;
  final bool pickerOpen;
  final VoidCallback onTogglePicker;
  final ValueChanged<FishStock> onPickFish;

  @override
  State<_FishSection> createState() => _FishSectionState();
}

class _FishSectionState extends State<_FishSection> {
  String _cat = 'sazan';

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final store = widget.store;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '🐟 BALIQ',
                style: TextStyle(
                  color: palette.tx,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: widget.onTogglePicker,
              icon: Icon(
                widget.pickerOpen ? Icons.expand_less : Icons.expand_more,
                size: 20,
              ),
              label: const Text('Baliq qo\'shish'),
            ),
          ],
        ),
        if (widget.pickerOpen)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.line),
            ),
            child: Builder(
              builder: (context) {
                final entries = store.snapshot.fishList
                    .where((entry) => entry.key == _cat)
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: fishKeys.map((key) {
                        final selected = key == _cat;
                        return ChoiceChip(
                          label: Text(productByKey(key).name),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _cat = key),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    if (entries.isEmpty)
                      Text(
                        'Bu turdagi baliq hali kiritilmagan',
                        style: TextStyle(color: palette.mut, fontSize: 12),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: entries.map((entry) {
                          final def = productByKey(entry.key);
                          return OutlinedButton(
                            onPressed: () => widget.onPickFish(entry),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${quantityText(entry.kg)} kg',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${def.name} · ${money(store.price(entry.key))} so\'m/kg',
                                  style: TextStyle(
                                    color: palette.mut,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      width: 34,
      height: 36,
      child: Material(
        color: palette.bg,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: palette.line),
            ),
            child: Icon(
              icon,
              size: 19,
              color: enabled ? palette.tx : palette.mut.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
