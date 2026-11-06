import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'admin_screen.dart';
import 'cook_screen.dart';
import 'waiter_screen.dart';

/// Uch rol uchun umumiy karkas (pastdagi navigatsiya).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.store,
    this.initialIndex = 0,
    this.locked = false,
  });

  final AppStore store;
  final int initialIndex;

  /// true bo'lsa — faqat bitta rol ko'rsatiladi (pastki navigatsiyasiz).
  final bool locked;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  Future<void> _openSettings() async {
    final url = await promptServerUrl(context, widget.store.baseUrl);
    if (url == null) return;
    if (!mounted) return;
    await widget.store.setBaseUrl(url);
    if (!mounted) return;
    showMessage(
      context,
      widget.store.online ? 'Serverga ulandi ✓' : 'Server topilmadi',
      error: !widget.store.online,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final store = widget.store;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final pendingCook = store.snapshot.tickets
            .where((ticket) => !ticket.done && !ticket.accepted)
            .length;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.pri, palette.ok],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🐟', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Orzu Baliqxonasi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: palette.tx,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              StatusPill(online: store.online),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Menyu',
                onSelected: (value) {
                  if (value == 'server') _openSettings();
                  if (value == 'refresh') store.refresh();
                  if (value == 'exit') Navigator.of(context).pop();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'server',
                    child: ListTile(
                      leading: Icon(Icons.dns_outlined),
                      title: Text('Server manzili'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Yangilash'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (!widget.locked)
                    const PopupMenuItem(
                      value: 'exit',
                      child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Rol tanlashga qaytish'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (store.mutating)
                const LinearProgressIndicator(minHeight: 2),
              if (!store.online)
                Material(
                  color: palette.bad.withValues(alpha: 0.12),
                  child: InkWell(
                    onTap: _openSettings,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off, size: 16, color: palette.bad),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Server bilan aloqa yo\'q — manzilni tekshiring',
                              style: TextStyle(
                                color: palette.bad,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 18, color: palette.bad),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: switch (_index) {
                  0 => WaiterScreen(store: store),
                  1 => CookScreen(store: store),
                  _ => AdminScreen(store: store),
                },
              ),
            ],
          ),
          bottomNavigationBar: widget.locked
              ? null
              : NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.table_bar_outlined),
                selectedIcon: Icon(Icons.table_bar),
                label: 'Ofitsiant',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: pendingCook > 0,
                  label: Text('$pendingCook'),
                  child: const Icon(Icons.soup_kitchen_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pendingCook > 0,
                  label: Text('$pendingCook'),
                  child: const Icon(Icons.soup_kitchen),
                ),
                label: 'Oshpaz',
              ),
              const NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Admin',
              ),
            ],
          ),
        );
      },
    );
  }
}
