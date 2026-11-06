import 'package:flutter/material.dart';

/// Veb-versiyadagi ranglar palitrasi (light + dark).
class AppPalette {
  const AppPalette({
    required this.bg,
    required this.card,
    required this.tx,
    required this.mut,
    required this.pri,
    required this.priText,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.line,
  });

  final Color bg;
  final Color card;
  final Color tx;
  final Color mut;
  final Color pri;
  final Color priText;
  final Color ok;
  final Color warn;
  final Color bad;
  final Color line;

  static const light = AppPalette(
    bg: Color(0xFFF4F8FB),
    card: Color(0xFFFFFFFF),
    tx: Color(0xFF12263A),
    mut: Color(0xFF64798C),
    pri: Color(0xFF0B7FAB),
    priText: Color(0xFFFFFFFF),
    ok: Color(0xFF1B9A5A),
    warn: Color(0xFFD98A00),
    bad: Color(0xFFC93C3C),
    line: Color(0xFFDBE6EE),
  );

  static const dark = AppPalette(
    bg: Color(0xFF0C1822),
    card: Color(0xFF142533),
    tx: Color(0xFFE6F0F7),
    mut: Color(0xFF8FA6B8),
    pri: Color(0xFF2AA6D6),
    priText: Color(0xFF04141D),
    ok: Color(0xFF34C37F),
    warn: Color(0xFFF0AD2E),
    bad: Color(0xFFEE6B6B),
    line: Color(0xFF24394A),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildAppTheme(Brightness brightness) {
  final palette =
      brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: palette.pri,
    brightness: brightness,
  ).copyWith(
    primary: palette.pri,
    onPrimary: palette.priText,
    surface: palette.card,
    onSurface: palette.tx,
    error: palette.bad,
    outline: palette.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: palette.card,
      foregroundColor: palette.tx,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: palette.line)),
    ),
    cardTheme: CardThemeData(
      color: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.line, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: palette.pri.withValues(alpha: 0.16),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tx),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? palette.pri : palette.mut);
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.bg,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.pri, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(color: palette.line),
        foregroundColor: palette.tx,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF20384A)
          : const Color(0xFF1D3448),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
