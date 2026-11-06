import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';
import '../sound.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_editor_screen.dart';

/// Oshpaz ekrani: yangi buyurtmalar, qabul qilish va "tayyor" belgilash.
class CookScreen extends StatefulWidget {
  const CookScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen> {
  bool _alarmOn = false;

  AppStore get _store => widget.store;

  Set<int> get _currentPending => _store.snapshot.tickets
      .where((ticket) => !ticket.done && !ticket.accepted)
      .map((ticket) => ticket.id)
      .toSet();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _syncAlarm();
  }

  /// Qabul qilinmagan buyurtma bor-yo'qligiga qarab alarmni yoqadi/o'chiradi.
  void _syncAlarm() {
    final hasPending = _currentPending.isNotEmpty;
    if (hasPending == _alarmOn) return;
    _alarmOn = hasPending;
    if (hasPending) {
      SoundFx.startAlarm();
    } else {
      SoundFx.stopAlarm();
    }
  }

  void _onStoreChanged() {
    _syncAlarm();
  }

  @override
  void dispose() {
    if (_alarmOn) SoundFx.stopAlarm();
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  Future<void> _newSaboy() async {
    if (_store.mutating) return;
    try {
      final key = await _store.createSaboy();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderEditorScreen(store: _store, tableKey: key),
        ),
      );
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final snapshot = _store.snapshot;
        final open = snapshot.tickets.where((ticket) => !ticket.done).toList()
          ..sort((a, b) => b.time.compareTo(a.time));
        final done = snapshot.tickets.where((ticket) => ticket.done).toList()
          ..sort((a, b) => b.time.compareTo(a.time));
        final recentDone = done.take(4).toList();

        return RefreshIndicator(
          onRefresh: () => _store.refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              FilledButton.icon(
                onPressed: _store.mutating ? null : _newSaboy,
                icon: const Icon(Icons.takeout_dining),
                label: const Text('SABOY (olib ketadi)'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.warn,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ovozli signal: yangi buyurtma kelganda chalinadi',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.mut, fontSize: 11.5),
              ),
              SectionTitle('Yangi buyurtmalar (${open.length})'),
              if (open.isEmpty)
                const EmptyCard('Hozircha buyurtma yo\'q')
              else
                ...open.map((ticket) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TicketCard(
                        ticket: ticket,
                        store: _store,
                        onAccept: () => runMutation(
                          context,
                          _store,
                          () => _store.acceptTicket(ticket.id),
                          successText: 'Qabul qilindi',
                        ),
                        onReady: () => runMutation(
                          context,
                          _store,
                          () => _store.readyTicket(ticket.id),
                          successText: 'Tayyor deb belgilandi 🔥',
                        ),
                      ),
                    )),
              if (recentDone.isNotEmpty) ...[
                const SectionTitle('Tayyor bo\'lganlar'),
                ...recentDone.map((ticket) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TicketCard(
                        ticket: ticket,
                        store: _store,
                        onAccept: null,
                        onReady: null,
                      ),
                    )),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.store,
    required this.onAccept,
    required this.onReady,
  });

  final Ticket ticket;
  final AppStore store;
  final VoidCallback? onAccept;
  final VoidCallback? onReady;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final statusColor = ticket.done
        ? palette.ok
        : ticket.accepted
            ? palette.pri
            : palette.warn;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ticket.done
            ? palette.card
            : ticket.accepted
                ? palette.card
                : palette.warn.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: ticket.done ? 0.4 : 0.65),
          width: ticket.accepted || ticket.done ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                tableLabel(ticket.table),
                style: TextStyle(
                  color: palette.tx,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${timeText(ticket.time)}',
                style: TextStyle(color: palette.mut, fontSize: 12),
              ),
              const Spacer(),
              if (ticket.done)
                Icon(Icons.check_circle, color: palette.ok, size: 20)
              else if (!ticket.accepted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.warn.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'YANGI',
                    style: TextStyle(
                      color: palette.warn,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          if (isSaboyKey(ticket.table)) ...[
            const SizedBox(height: 10),
            _AddressField(store: store, tableKey: ticket.table),
          ],
          const SizedBox(height: 10),
          if (ticket.fishOrders.isNotEmpty)
            ...ticket.fishOrders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            productName(order.key),
                            style: TextStyle(
                              color: palette.tx,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${quantityText(order.kg)} kg · ${order.onionLabel}',
                          style: TextStyle(
                            color: palette.tx,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
          else
            ...ticket.items.entries.where((entry) => entry.value > 0).map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          productName(entry.key),
                          style: TextStyle(
                            color: palette.tx,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${quantityText(entry.value)} ${productByKey(entry.key).unit}',
                        style: TextStyle(
                          color: palette.tx,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (!ticket.done) ...[
            const SizedBox(height: 12),
            if (ticket.accepted)
              FilledButton.icon(
                onPressed: store.mutating ? null : onReady,
                icon: const Icon(Icons.local_fire_department, size: 20),
                label: const Text('Baliq pishdi'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.ok,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )
            else
              FilledButton.icon(
                onPressed: store.mutating ? null : onAccept,
                icon: const Icon(Icons.notifications_active, size: 20),
                label: const Text('Qabul qildim'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.warn,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AddressField extends StatefulWidget {
  const _AddressField({required this.store, required this.tableKey});

  final AppStore store;
  final String tableKey;

  @override
  State<_AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<_AddressField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.store.table(widget.tableKey).address,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text == widget.store.table(widget.tableKey).address) return;
    try {
      await widget.store.mutate(
        () => widget.store.saveAddress(widget.tableKey, text),
      );
      if (mounted) showMessage(context, 'Manzil saqlandi');
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      style: TextStyle(fontSize: 13.5, color: palette.tx),
      decoration: InputDecoration(
        labelText: '📍 Manzil',
        hintText: 'Mijoz manzili',
        suffixIcon: IconButton(
          icon: const Icon(Icons.check, size: 20),
          onPressed: _save,
        ),
      ),
    );
  }
}
