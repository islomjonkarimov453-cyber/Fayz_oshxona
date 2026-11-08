import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

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
  final List<Map<String, dynamic>> _fishOrders = [];
  final TextEditingController _address = TextEditingController();
  bool _fishPicker = false;
  bool _busy = false;

  String get _key => widget.tableKey;
  AppStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _address.text = _store.table(_key).address;
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Map<String, double> get _existing => _store.table(_key).items;

  Map<String, double> get _combined =>
      _store.mergedItems(_key, _draft);

  double get _newSubtotal => _store.snapshot.money(_draft);

  void _setDraft(String key, double value) {
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

  /// Baliq tanlangach: sovusli/sovussiz so'raladi, tanlov oshpazga boradi.
  Future<void> _askOnion(String key, double kg) async {
    final onion = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${productName(key)} — ${quantityText(kg)} kg'),
        content: const Text('Qanday tayyorlaymiz?'),
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
    setState(() {
      _draft[key] = round2((_draft[key] ?? 0) + kg);
      _fishOrders.add({'key': key, 'kg': kg, 'onion': onion});
    });
  }

  Future<void> _send() async {
    if (_busy || _newSubtotal <= 0) return;
    setState(() => _busy = true);

    final draft = Map<String, double>.from(_draft);
    final merged = _store.mergedItems(_key, draft);
    final fish = <String, double>{};
    for (final key in fishKeys) {
      final quantity = draft[key] ?? 0;
      if (quantity > 0) fish[key] = quantity;
    }
    final fishOrders = _fishOrders.isEmpty
        ? null
        : List<Map<String, dynamic>>.from(_fishOrders);

    try {
      await _store.mutate(() async {
        await _store.saveTableState(
          _key,
          merged,
          address: _address.text.trim(),
        );
        if (fish.isNotEmpty) {
          await _store.createTicket(_key, fish, fishOrders: fishOrders);
        }
      });
      if (!mounted) return;
      setState(() {
        _draft.clear();
        _fishOrders.clear();
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
    final items = _combined;
    final subtotal = _store.snapshot.money(items);
    if (subtotal <= 0) return;

    setState(() => _busy = true);
    final pct = _store.servicePercentFor(_key);
    final fee = (subtotal * pct / 100).roundToDouble();

    try {
      final saleItems = <String, dynamic>{...items};
      if (_fishOrders.isNotEmpty) {
        saleItems['_fish'] = List<Map<String, dynamic>>.from(_fishOrders);
      }
      final sale = await _store.createSale({
        'table': _key,
        'items': saleItems,
        'sub': subtotal,
        'pct': pct.round(),
        'fee': fee,
        'total': subtotal + fee,
        'prices': _store.snapshot.prices,
        'address': _address.text.trim(),
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
    final empty = _store.table(_key).items.isEmpty && _draft.isEmpty;
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
        final canSend = _newSubtotal > 0 && !_busy;
        final canClose = subtotal > 0 && !_busy;

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
                    for (final key in fishKeys)
                      if (key == 'sazan' ||
                          ((_existing[key] ?? 0) + (_draft[key] ?? 0)) > 0)
                        _row(context, key),
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
    final combined = existing + draft;
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
                  '${existing > 0 ? '  ·  buyurtmada: ${quantityText(existing)} $unit' : ''}'
                  '${key == 'tabaka' ? '  ·  qoldiq: ${quantityText(_store.snapshot.stock['tabaka'] ?? 0)} dona' : ''}',
                  style: TextStyle(color: palette.mut, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _StepButton(
            icon: Icons.remove,
            enabled: draft > 0,
            onTap: () => _change(key, -def.step),
          ),
          InkWell(
            onTap: () => _editQuantity(key),
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
            enabled: true,
            onTap: () => _change(key, def.step),
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
