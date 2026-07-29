import 'package:flutter/material.dart';

abstract final class BrandColors {
  static const yellow = Color(0xFFFFC400);
  static const yellowSoft = Color(0xFFFFE27A);
  static const ink = Color(0xFF151515);
  static const paper = Color(0xFFFFFBF1);
  static const darkSurface = Color(0xFF202020);
  static const success = Color(0xFF16834B);
  static const warning = Color(0xFF9A6500);
  static const error = Color(0xFFB42318);
}

abstract final class AppSpacing {
  static const xs = 6.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 40.0;
}

abstract final class AppRadii {
  static const input = 14.0;
  static const card = 24.0;
  static const pill = 999.0;
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final accessibleAccent = isDark
        ? BrandColors.yellowSoft
        : BrandColors.warning;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: BrandColors.yellow,
      onPrimary: BrandColors.ink,
      secondary: isDark ? BrandColors.yellowSoft : BrandColors.ink,
      onSecondary: isDark ? BrandColors.ink : Colors.white,
      tertiary: accessibleAccent,
      onTertiary: isDark ? BrandColors.ink : Colors.white,
      error: isDark ? const Color(0xFFFFB4AB) : BrandColors.error,
      onError: isDark ? const Color(0xFF690005) : Colors.white,
      surface: isDark ? BrandColors.darkSurface : BrandColors.paper,
      onSurface: isDark ? const Color(0xFFF4F0E8) : BrandColors.ink,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF141414)
          : BrandColors.paper,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1.05,
          letterSpacing: -1.1,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF292929) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: _border(scheme.onSurface.withValues(alpha: 0.18)),
        enabledBorder: _border(scheme.onSurface.withValues(alpha: 0.18)),
        focusedBorder: _border(scheme.tertiary, width: 2),
        errorBorder: _border(scheme.error),
        focusedErrorBorder: _border(scheme.error, width: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.yellow,
          foregroundColor: BrandColors.ink,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.input),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF222222) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.onSurface.withValues(alpha: 0.12),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
