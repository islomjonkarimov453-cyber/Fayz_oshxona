import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_editor_screen.dart';

/// Admin: statistika, hisobotlar, sotuvlar tarixi va sozlamalar.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _tabs = [
    ('📊 Umumiy', Icons.dashboard_outlined),
    ('🐟 Baliq', Icons.set_meal_outlined),
    ('🥤 Non va ichimlik', Icons.local_drink_outlined),
    ('🧾 Sotuvlar', Icons.receipt_long_outlined),
    ('⚙️ Sozlamalar', Icons.settings_outlined),
  ];

  int _tab = 0;
  String _period = 'today';

  AppStore get _store => widget.store;

  int get _from {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case 'today':
        return today.millisecondsSinceEpoch;
      case 'week':
        return today
            .subtract(const Duration(days: 6))
            .millisecondsSinceEpoch;
      default:
        return 0;
    }
  }

  List<Sale> get _sales =>
      _store.snapshot.sales.where((sale) => sale.time >= _from).toList();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        return Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = index == _tab;
                  final (label, icon) = _tabs[index];
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => _tab = index),
                    avatar: Icon(
                      icon,
                      size: 16,
                      color: selected ? palette.priText : palette.mut,
                    ),
                    label: Text(label),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? palette.priText : palette.tx,
                    ),
                    selectedColor: palette.pri,
                    backgroundColor: palette.card,
                    side: BorderSide(color: palette.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),
            if (_tab != 4)
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  children: [
                    for (final entry in const [
                      ('today', 'Bugun'),
                      ('week', 'Oxirgi 7 kun'),
                      ('all', 'Hammasi'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _period == entry.$1,
                          onSelected: (_) =>
                              setState(() => _period = entry.$1),
                          label: Text(entry.$2),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _period == entry.$1
                                ? palette.priText
                                : palette.tx,
                          ),
                          selectedColor: palette.ok,
                          backgroundColor: palette.card,
                          side: BorderSide(color: palette.line),
                          showCheckmark: false,
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: switch (_tab) {
                0 => _homeTab(context),
                1 => _fishTab(context),
                2 => _otherTab(context),
                3 => _salesTab(context),
                _ => _SettingsTab(store: _store),
              },
            ),
          ],
        );
      },
    );
  }

  Widget _scroll(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
      children: children,
    );
  }

  Widget _homeTab(BuildContext context) {
    final palette = AppPalette.of(context);
    final sales = _sales;
    final revenue =
        sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final fees = sales.fold<double>(0, (sum, sale) => sum + sale.fee);
    final itemsTotal =
        sales.fold<double>(0, (sum, sale) => sum + sale.sub);
    final fishKg = sales.fold<double>(
      0,
      (sum, sale) =>
          sum +
          fishKeys.fold<double>(
              0, (inner, key) => inner + (sale.items[key] ?? 0)),
    );

    final busy = _store.snapshot.tables.entries
        .where((entry) => !isSaboyKey(entry.key))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final recent = sales.reversed.take(5).toList();

    return _scroll([
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: [
          KpiCard(
            value: '${money(revenue)} so\'m',
            label: 'Umumiy tushum (xizmat bilan)',
            color: palette.pri,
          ),
          KpiCard(
            value: '${money(itemsTotal)} so\'m',
            label: 'Taomlar summasi',
            color: palette.ok,
          ),
          KpiCard(
            value: '${money(fees)} so\'m',
            label: 'Xizmat haqi',
            color: palette.warn,
          ),
          KpiCard(
            value: '${sales.length}',
            label: 'Chiqarilgan cheklar',
            color: palette.mut,
          ),
          KpiCard(
            value: '${quantityText(fishKg)} kg',
            label: 'Sotilgan baliq',
            color: palette.pri,
          ),
          KpiCard(
            value: '${busy.length} / $roomCount',
            label: 'Hozir band honalar',
            color: palette.bad,
          ),
        ],
      ),
      const SectionTitle('Hozir band honalar'),
      Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: busy.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Hamma hona bo\'sh',
                  style: TextStyle(color: palette.mut),
                ),
              )
            : Column(
                children: busy.map((entry) {
                  final total = _store.totalFor(entry.key, entry.value.items);
                  return InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderEditorScreen(
                          store: _store,
                          tableKey: entry.key,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tableLabel(entry.key),
                                  style: TextStyle(
                                    color: palette.tx,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (entry.value.address.isNotEmpty)
                                  Text(
                                    '📍 ${entry.value.address}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.mut,
                                      fontSize: 11.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${money(total)} so\'m',
                            style: TextStyle(
                              color: palette.tx,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 18, color: palette.mut),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
      if (recent.isNotEmpty) ...[
        const SectionTitle('Oxirgi cheklar'),
        ...recent.map(
          (sale) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SaleTile(
              sale: sale,
              onTap: () =>
                  showReceipt(context, sale, _store.snapshot),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _fishTab(BuildContext context) {
    final palette = AppPalette.of(context);
    final sales = _sales;
    double qtyOf(String key) =>
        sales.fold<double>(0, (sum, sale) => sum + (sale.items[key] ?? 0));
    double amountOf(String key) => sales.fold<double>(
          0,
          (sum, sale) =>
              sum +
              (sale.items[key] ?? 0) * _salePrice(sale, key),
        );

    final totalKg =
        fishKeys.fold<double>(0, (sum, key) => sum + qtyOf(key));
    final totalAmount =
        fishKeys.fold<double>(0, (sum, key) => sum + amountOf(key));

    return _scroll([
      Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ...fishKeys.map((key) {
              final quantity = qtyOf(key);
              final amount = amountOf(key);
              final share = totalKg > 0 ? quantity / totalKg : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            productName(key),
                            style: TextStyle(
                              color: palette.tx,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${quantityText(quantity)} kg',
                          style: TextStyle(
                            color: palette.tx,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${money(_store.price(key))} so\'m/kg · ${money(amount)} so\'m',
                            style: TextStyle(
                              color: palette.mut,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        Text(
                          '${(share * 100).round()}%',
                          style: TextStyle(
                            color: palette.mut,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 7,
                        backgroundColor: palette.line,
                        color: palette.pri,
                      ),
                    ),
                  ],
                ),
              );
            }),
            Divider(color: palette.line),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Jami baliq',
                    style: TextStyle(
                      color: palette.tx,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${quantityText(totalKg)} kg · ${money(totalAmount)} so\'m',
                  style: TextStyle(
                    color: palette.tx,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _otherTab(BuildContext context) {
    final palette = AppPalette.of(context);
    final sales = _sales;
    double qtyOf(String key) =>
        sales.fold<double>(0, (sum, sale) => sum + (sale.items[key] ?? 0));
    double amountOf(String key) => sales.fold<double>(
          0,
          (sum, sale) =>
              sum +
              (sale.items[key] ?? 0) * _salePrice(sale, key),
        );
    final total =
        otherKeys.fold<double>(0, (sum, key) => sum + amountOf(key));

    return _scroll([
      Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ...otherKeys.map((key) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName(key),
                            style: TextStyle(
                              color: palette.tx,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${money(_store.price(key))} so\'m / dona',
                            style: TextStyle(
                              color: palette.mut,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${quantityText(qtyOf(key))} dona',
                          style: TextStyle(
                            color: palette.tx,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${money(amountOf(key))} so\'m',
                          style: TextStyle(
                            color: palette.mut,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            Divider(color: palette.line),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Jami',
                    style: TextStyle(
                      color: palette.tx,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${money(total)} so\'m',
                  style: TextStyle(
                    color: palette.tx,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _salesTab(BuildContext context) {
    final sales = _sales.reversed.toList();
    return _scroll([
      if (sales.isEmpty)
        const EmptyCard('Bu davrda sotuv yo\'q')
      else
        ...sales.map(
          (sale) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SaleTile(
              sale: sale,
              onTap: () => showReceipt(context, sale, _store.snapshot),
            ),
          ),
        ),
    ]);
  }

  double _salePrice(Sale sale, String key) =>
      sale.prices[key] ?? _store.price(key);
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, required this.onTap});

  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final summary = _itemsSummary(sale.items);
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.ok.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  size: 20,
                  color: palette.ok,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '№${sale.id} · ${tableLabel(sale.table)}',
                            style: TextStyle(
                              color: palette.tx,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          dateTimeText(sale.time),
                          style: TextStyle(
                            color: palette.mut,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.mut,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${money(sale.total)}',
                style: TextStyle(
                  color: palette.tx,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _itemsSummary(Map<String, double> items) {
  final parts = <String>[];
  for (final product in products) {
    final quantity = items[product.key] ?? 0;
    if (quantity <= 0) continue;
    parts.add(
      '${product.name} ${quantityText(quantity)} ${product.unit}',
    );
  }
  return parts.isEmpty ? '—' : parts.join(', ');
}

/// Narxlar va xizmat foizini tahrirlash.
class _SettingsTab extends StatefulWidget {
  const _SettingsTab({required this.store});

  final AppStore store;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late final Map<String, TextEditingController> _priceControllers;
  late final TextEditingController _serviceController;

  @override
  void initState() {
    super.initState();
    final snapshot = widget.store.snapshot;
    _priceControllers = {
      for (final product in products)
        product.key: TextEditingController(
          text: quantityText(snapshot.price(product.key)),
        ),
    };
    _serviceController = TextEditingController(
      text: quantityText(snapshot.service),
    );
  }

  @override
  void dispose() {
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    _serviceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prices = <String, double>{};
    for (final entry in _priceControllers.entries) {
      final value = double.tryParse(
        entry.value.text.trim().replaceAll(',', '.'),
      );
      if (value == null || value < 0) {
        showMessage(
          context,
          '${productName(entry.key)} narxini to\'g\'ri kiriting',
          error: true,
        );
        return;
      }
      prices[entry.key] = value;
    }
    final service = double.tryParse(
      _serviceController.text.trim().replaceAll(',', '.'),
    );
    if (service == null || service < 0 || service > 100) {
      showMessage(context, 'Xizmat foizi 0–100 oralig\'ida bo\'lishi kerak',
          error: true);
      return;
    }

    await runMutation(
      context,
      widget.store,
      () => widget.store.saveSettings(prices: prices, service: service),
      successText: 'Narxlar saqlandi',
    );
  }

  Future<void> _resetAll() async {
    final palette = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hammasini tozalash'),
        content: const Text(
          'Barcha sotuvlar, buyurtmalar va stol holatlari o\'chiriladi.\n'
          'Davom etasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.bad),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tozalash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await runMutation(
      context,
      widget.store,
      () => widget.store.resetAll(),
      successText: 'Hamma ma\'lumot tozalandi',
    );
  }

  Widget _priceField(String key) {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${productName(key)} (so\'m)',
          style: TextStyle(color: palette.mut, fontSize: 11.5),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _priceControllers[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: TextStyle(fontSize: 15, color: palette.tx),
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
      children: [
        const SectionTitle('🐟 Baliq narxlari (1 kg)'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: fishKeys.map(_priceField).toList(),
        ),
        const SectionTitle('🥤 Non va ichimliklar (1 dona)'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: otherKeys.map(_priceField).toList(),
        ),
        const SectionTitle('Xizmat haqi'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foiz (%)',
              style: TextStyle(color: palette.mut, fontSize: 11.5),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _serviceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: TextStyle(fontSize: 15, color: palette.tx),
              decoration: const InputDecoration(
                suffixText: '%',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: widget.store.mutating ? null : _save,
          icon: const Icon(Icons.save_outlined, size: 19),
          label: const Text('Narxlarni saqlash'),
        ),
        const SizedBox(height: 26),
        Text(
          'Xavfli bo\'lim',
          style: TextStyle(
            color: palette.bad,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.store.mutating ? null : _resetAll,
          icon: Icon(Icons.delete_forever, size: 19, color: palette.bad),
          label: Text(
            'Barcha sotuvlarni tozalash',
            style: TextStyle(color: palette.bad),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: palette.bad.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Diqqat: bu amal qaytarilmaydi.',
          style: TextStyle(color: palette.mut, fontSize: 11.5),
        ),
      ],
    );
  }
}
