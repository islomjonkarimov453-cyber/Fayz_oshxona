import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_shell.dart';

/// Kirish ekrani: rol tanlash va server manzilini sozlash.
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _openSettings(BuildContext context) async {
    final url = await promptServerUrl(context, store.baseUrl);
    if (url == null) return;
    if (!context.mounted) return;
    await store.setBaseUrl(url);
    if (!context.mounted) return;
    showMessage(
      context,
      store.online ? 'Serverga ulandi ✓' : 'Server topilmadi. Manzilni tekshiring.',
      error: !store.online,
    );
  }

  void _enter(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeShell(store: store, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [palette.pri, palette.ok],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: palette.pri.withValues(alpha: 0.25),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text('🐟', style: TextStyle(fontSize: 46)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Orzu Baliqxonasi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.tx,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Boshqaruv tizimi · mobil ilova',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.mut, fontSize: 14),
                      ),
                      const SizedBox(height: 18),
                      Center(child: StatusPill(online: store.online)),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          store.baseUrl,
                          style: TextStyle(color: palette.mut, fontSize: 12),
                        ),
                      ),
                      if (!store.online) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: palette.bad.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: palette.bad.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 20, color: palette.bad),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Server bilan aloqa yo\'q.\n'
                                  '${store.lastError ?? 'Kompyuterda Django serverini ishga tushiring va manzilni sozlang.'}',
                                  style: TextStyle(
                                    color: palette.tx,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),
                      Text(
                        'Rolingizni tanlang',
                        style: TextStyle(
                          color: palette.mut,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _RoleCard(
                        icon: Icons.table_bar_outlined,
                        color: palette.ok,
                        title: 'Ofitsiant',
                        subtitle: 'Honalar, buyurtma va chek',
                        onTap: () => _enter(context, 0),
                      ),
                      const SizedBox(height: 10),
                      _RoleCard(
                        icon: Icons.soup_kitchen_outlined,
                        color: palette.warn,
                        title: 'Oshpaz',
                        subtitle: 'Yangi buyurtmalar va baliq tayyorlash',
                        onTap: () => _enter(context, 1),
                      ),
                      const SizedBox(height: 10),
                      _RoleCard(
                        icon: Icons.insights_outlined,
                        color: palette.pri,
                        title: 'Admin',
                        subtitle: 'Statistika, narxlar va sozlamalar',
                        onTap: () => _enter(context, 2),
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openSettings(context),
                              icon: const Icon(Icons.dns_outlined, size: 18),
                              label: const Text('Serverni sozlash'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            tooltip: 'Yangilash',
                            onPressed: () => store.refresh(),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.tx,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.mut,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.mut),
            ],
          ),
        ),
      ),
    );
  }
}
