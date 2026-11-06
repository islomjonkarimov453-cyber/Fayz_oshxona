import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'screens/role_screen.dart';
import 'store.dart';
import 'theme.dart';

/// Build paytida beriladigan rol: waiter | cook | admin.
/// Bo'sh bo'lsa — rol tanlash ekrani ko'rsatiladi.
const String _appRole = String.fromEnvironment('APP_ROLE');

int? get _lockedIndex => switch (_appRole) {
      'waiter' => 0,
      'cook' => 1,
      'admin' => 2,
      _ => null,
    };

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FayzApp());
}

class FayzApp extends StatefulWidget {
  const FayzApp({super.key});

  @override
  State<FayzApp> createState() => _FayzAppState();
}

class _FayzAppState extends State<FayzApp> {
  late final AppStore _store;
  bool _unlocked = false;
  bool _unlockChecked = false;

  @override
  void initState() {
    super.initState();
    _store = AppStore();
    _store.init();
    isAppUnlocked().then((value) {
      if (!mounted) return;
      setState(() {
        _unlocked = value;
        _unlockChecked = true;
      });
    });
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fayz Baliqxonasi',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          if (!_store.ready || !_unlockChecked) {
            return const _SplashScreen();
          }
          if (!_unlocked) {
            return LockScreen(
              onUnlocked: () => setState(() => _unlocked = true),
            );
          }
          final locked = _lockedIndex;
          if (locked != null) {
            return HomeShell(store: _store, initialIndex: locked, locked: true);
          }
          return RoleScreen(store: _store);
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [palette.pri, palette.ok],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: const Text('🐟', style: TextStyle(fontSize: 42)),
            ),
            const SizedBox(height: 18),
            Text(
              'Fayz Baliqxonasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: palette.tx,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: palette.pri,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Serverga ulanmoqda...',
              style: TextStyle(color: palette.mut, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
