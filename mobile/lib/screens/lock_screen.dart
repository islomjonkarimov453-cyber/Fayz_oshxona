import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// Ilova PIN kodi — birinchi ochilishda so'raladi, keyin eslab qolinadi.
/// Kodni o'zgartirish uchun shu yerni tahriring.
const String kAppPin = '1234';
const String _prefsUnlockedKey = 'app_unlocked';

Future<bool> isAppUnlocked() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsUnlockedKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> markAppUnlocked() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsUnlockedKey, true);
  } catch (_) {
    // Saqlab bo'lmasa ham davom etamiz.
  }
}

/// Bir martalik PIN ekrani.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entered = '';
  bool _error = false;

  void _press(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _error = false;
    });
    if (_entered.length == 4) {
      if (_entered == kAppPin) {
        markAppUnlocked().then((_) => widget.onUnlocked());
      } else {
        setState(() {
          _error = true;
          _entered = '';
        });
      }
    }
  }

  void _back() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
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
                  const SizedBox(height: 20),
                  Text(
                    'Orzu Baliqxonasi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: palette.tx,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kirish kodi',
                    style: TextStyle(color: palette.mut, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < _entered.length;
                      return Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? (_error ? palette.bad : palette.pri)
                              : Colors.transparent,
                          border: Border.all(
                            color: _error
                                ? palette.bad
                                : filled
                                    ? palette.pri
                                    : palette.line,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_error) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Kod noto\'g\'ri, qayta urinib ko\'ring',
                      style: TextStyle(color: palette.bad, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 28),
                  for (var row = 0; row < 3; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (col) {
                          final digit = '${row * 3 + col + 1}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: _PinKey(
                              label: digit,
                              onTap: () => _press(digit),
                            ),
                          );
                        }),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 76),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _PinKey(
                          label: '0',
                          onTap: () => _press('0'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _PinKey(
                          icon: Icons.backspace_outlined,
                          onTap: _back,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.card,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: palette.line),
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, color: palette.tx, size: 26)
              : Text(
                  label!,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: palette.tx,
                  ),
                ),
        ),
      ),
    );
  }
}
