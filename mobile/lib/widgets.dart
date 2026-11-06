import 'package:flutter/material.dart';

import 'api.dart';
import 'constants.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is Exception) return error.toString().replaceFirst('Exception: ', '');
  return error.toString();
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor:
          error ? AppPalette.of(context).bad : null,
      duration: Duration(seconds: error ? 5 : 3),
    ),
  );
}

/// O'zgartirish amalini bajarib, natija haqida xabar beradi.
Future<bool> runMutation(
  BuildContext context,
  AppStore store,
  Future<void> Function() action, {
  String successText = 'Saqlandi',
}) async {
  try {
    await store.mutate(action);
    if (context.mounted) showMessage(context, successText);
    return true;
  } catch (error) {
    if (context.mounted) showMessage(context, errorMessage(error), error: true);
    return false;
  }
}

/// Onlayn/oflayn holat indikatori.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = online ? palette.ok : palette.bad;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'onlayn' : 'aloqa yo\'q',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: palette.tx,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Text(text, style: TextStyle(color: palette.mut)),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 0,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.tx,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: palette.mut, fontSize: 12.5, height: 1.25),
          ),
        ],
      ),
    );
  }
}

/// Server manzilini so'rash oynasi. Saqlansa — yangi manzilni qaytaradi.
Future<String?> promptServerUrl(
  BuildContext context,
  String currentUrl,
) async {
  final controller = TextEditingController(text: currentUrl);
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final palette = AppPalette.of(dialogContext);
      return AlertDialog(
        title: const Text('Server manzili'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Django server manzilini kiriting. Telefonda ishlatish uchun '
              'kompyuterning Wi-Fi IP manzilini yozing, masalan:\n'
              'http://192.168.1.25:8000',
              style: TextStyle(fontSize: 13, color: palette.mut, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'http://192.168.1.25:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Saqlash'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return value;
}

/// Chek oynasi. Yopilguncha kutish uchun `await` qilish mumkin.
Future<void> showReceipt(
  BuildContext context,
  Sale sale,
  AppSnapshot snapshot,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: ReceiptView(sale: sale, snapshot: snapshot),
        ),
      ),
    ),
  );
}

class ReceiptView extends StatelessWidget {
  const ReceiptView({
    super.key,
    required this.sale,
    required this.snapshot,
  });

  final Sale sale;
  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF111111);
    final priceMap = {...snapshot.prices, ...sale.prices};
    double priceFor(String key) => priceMap[key] ?? 0;

    final lines = sale.items.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(18),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: ink,
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ORZU BALIQXONASI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              'Chek №${sale.id}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const Divider(color: ink, height: 18, thickness: 0.7),
            Text(
              '${tableLabel(sale.table)}'
              '${sale.address.isNotEmpty ? '\n📍 ${sale.address}' : ''}'
              '\n${dateTimeText(sale.time)}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const Divider(color: ink, height: 18, thickness: 0.7),
            ...lines.map((entry) {
              final product = productByKey(entry.key);
              final amount = entry.value * priceFor(entry.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${product.name} ${quantityText(entry.value)} ${product.unit}',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    Text(
                      money(amount),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              );
            }),
            const Divider(color: ink, height: 18, thickness: 0.7),
            _row('Taomlar', money(sale.sub)),
            if (sale.pct > 0) _row('Xizmat (${sale.pct.round()}%)', money(sale.fee)),
            _row('JAMI:', '${money(sale.total)} so\'m', bold: true),
            const Divider(color: ink, height: 18, thickness: 0.7),
            const Text(
              'Rahmat! Yana kutamiz 🐟',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Yopish'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(String left, String right, {bool bold = false}) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      fontSize: bold ? 15 : 13.5,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(left, style: style)),
          Text(right, style: style),
        ],
      ),
    );
  }
}
