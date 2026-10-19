import 'package:flutter/material.dart';

/// LuveDuve design system — dark, neon, "cockpit" look.
class Tech {
  Tech._();

  static const bg = Color(0xFF04060E);
  static const surface = Color(0xFF0B1020);
  static const surfaceHi = Color(0xFF121A33);
  static const cyan = Color(0xFF00E5FF);
  static const violet = Color(0xFF8B5CF6);
  static const magenta = Color(0xFFFF2D95);
  static const amber = Color(0xFFFFB020);
  static const mint = Color(0xFF2DFFB0);
  static const text = Color(0xFFE8EEFA);
  static const muted = Color(0xFF8793AD);

  static const brand = LinearGradient(
    colors: [cyan, violet, magenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Small monospace label style used for the "terminal" feel.
  static TextStyle mono({
    double size = 11,
    Color color = muted,
    FontWeight weight = FontWeight.w500,
    double spacing = 1.3,
  }) =>
      TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier', 'Menlo'],
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: spacing,
      );

  static Color accentFor(String type) {
    switch (type) {
      case 'Verse':
        return cyan;
      case 'Hook':
        return magenta;
      case 'Chorus':
        return violet;
      case 'Bridge':
        return amber;
      case 'PreChorus':
        return mint;
      case 'Outro':
        return const Color(0xFF4DA3FF);
      default:
        return const Color(0xFFB0B8CC);
    }
  }

  static final dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(22),
    side: BorderSide(color: cyan.withValues(alpha: .25)),
  );

  static OutlineInputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  static ThemeData theme() {
    const scheme = ColorScheme.dark(
      primary: cyan,
      secondary: violet,
      tertiary: magenta,
      surface: surface,
      onSurface: text,
      surfaceContainerHigh: surfaceHi,
      error: Color(0xFFFF5C7A),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme:
          ThemeData.dark().textTheme.apply(bodyColor: text, displayColor: text),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: cyan,
        selectionHandleColor: cyan,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: .04),
        isDense: true,
        hintStyle: TextStyle(color: muted.withValues(alpha: .7)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: _border(Colors.white.withValues(alpha: .08)),
        enabledBorder: _border(Colors.white.withValues(alpha: .08)),
        disabledBorder: _border(Colors.white.withValues(alpha: .04)),
        focusedBorder: _border(cyan, 1.4),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cyan,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cyan,
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHi,
        contentTextStyle: const TextStyle(color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cyan.withValues(alpha: .4)),
        ),
      ),
    );
  }
}
