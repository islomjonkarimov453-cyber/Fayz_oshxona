import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_editor_screen.dart';

/// Ofitsiant: honalar ro'yxati va tayyor taom bildirishnomalari.
class WaiterScreen extends StatelessWidget {
  const WaiterScreen({super.key, required this.store});

  final AppStore store;

  void _openTable(BuildContext context, String key) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderEditorScreen(store: store, tableKey: key),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final snapshot = store.snapshot;
        final ready = snapshot.readyTickets;

        final roomKeys = <String>[
          for (var i = 1; i <= roomCount; i++) '$i',
          ...snapshot.tables.keys.where(
            (key) =>
                !isSaboyKey(key) && int.tryParse(key) != null && int.parse(key) > roomCount,
          ),
        ];
        final saboyKeys = snapshot.tables.keys
            .where((key) => isSaboyKey(key))
            .toList()
          ..sort();

        return RefreshIndicator(
          onRefresh: () => store.refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (ready.isNotEmpty) ...[
                ...ready.map((ticket) => _ReadyAlert(
                      ticket: ticket,
                      store: store,
                      onAck: () => runMutation(
                        context,
                        store,
                        () => store.seenTicket(ticket.id),
                        successText: 'Olib borildi',
                      ),
                    )),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '🍽 HONALAR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.tx,
                      ),
                    ),
                  ),
                  Text(
                    '${snapshot.tables.length} band',
                    style: TextStyle(color: palette.mut, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Hona raqamini tanlang',
                style: TextStyle(color: palette.mut, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720
                      ? 4
                      : constraints.maxWidth >= 480
                          ? 3
                          : 2;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                    children: roomKeys
                        .map((key) => _TableCard(
                              tableKey: key,
                              table: snapshot.tables[key],
                              store: store,
                              onTap: () => _openTable(context, key),
                            ))
                        .toList(),
                  );
                },
              ),
              if (saboyKeys.isNotEmpty) ...[
                const SectionTitle('🥡 SABOY (olib ketadi)'),
                ...saboyKeys.map(
                  (key) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SaboyRow(
                      tableKey: key,
                      table: snapshot.tables[key]!,
                      store: store,
                      onTap: () => _openTable(context, key),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sync, size: 16, color: palette.mut),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ma\'lumotlar har 2 sekundda avtomatik yangilanadi',
                        style: TextStyle(color: palette.mut, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReadyAlert extends StatelessWidget {
  const _ReadyAlert({
    required this.ticket,
    required this.store,
    required this.onAck,
  });

  final Ticket ticket;
  final AppStore store;
  final VoidCallback onAck;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final summary = fishKeys
        .where((key) => (ticket.items[key] ?? 0) > 0)
        .map((key) =>
            '${productName(key)} ${quantityText(ticket.items[key]!)} kg')
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.ok.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.ok.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔥 ${tableLabel(ticket.table)}: baliq pishdi!',
                  style: TextStyle(
                    color: palette.tx,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$summary · ${timeText(ticket.doneAt ?? ticket.time)}',
                  style: TextStyle(color: palette.mut, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.ok,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: store.mutating ? null : onAck,
            child: const Text('Olib bordim'),
          ),
        ],
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.tableKey,
    required this.table,
    required this.store,
    required this.onTap,
  });

  final String tableKey;
  final TableData? table;
  final AppStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final busy = table != null;
    final subtotal = table == null ? 0.0 : store.snapshot.money(table!.items);

    return Material(
      color: busy
          ? palette.warn.withValues(alpha: 0.10)
          : palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: busy
                  ? palette.warn.withValues(alpha: 0.55)
                  : palette.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hona $tableKey',
                      style: TextStyle(
                        color: palette.tx,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    busy ? Icons.people_alt : Icons.event_available,
                    size: 18,
                    color: busy ? palette.warn : palette.ok,
                  ),
                ],
              ),
              const Spacer(),
              if (busy) ...[
                Text(
                  'Band',
                  style: TextStyle(
                    color: palette.warn,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${money(subtotal)} so\'m',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.tx,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else
                Text(
                  'Bo\'sh',
                  style: TextStyle(
                    color: palette.ok,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaboyRow extends StatelessWidget {
  const _SaboyRow({
    required this.tableKey,
    required this.table,
    required this.store,
    required this.onTap,
  });

  final String tableKey;
  final TableData table;
  final AppStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final subtotal = store.snapshot.money(table.items);
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
            border: Border.all(color: palette.warn.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Icon(Icons.takeout_dining, color: palette.warn),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tableLabel(tableKey),
                      style: TextStyle(
                        color: palette.tx,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (table.address.isNotEmpty)
                      Text(
                        '📍 ${table.address}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.mut, fontSize: 12),
                      )
                    else
                      Text(
                        'Manzil kiritilmagan',
                        style: TextStyle(color: palette.mut, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Text(
                '${money(subtotal)} so\'m',
                style: TextStyle(
                  color: palette.tx,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: palette.mut),
            ],
          ),
        ),
      ),
    );
  }
}
