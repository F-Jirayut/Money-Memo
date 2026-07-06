import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData darkPremium() {
    const scheme = ColorScheme.dark(
      primary: Color(0xFFD6B46A),
      onPrimary: Color(0xFF201704),
      secondary: Color(0xFF55D6BE),
      onSecondary: Color(0xFF04201B),
      tertiary: Color(0xFF8CB4FF),
      surface: Color(0xFF10151D),
      onSurface: Color(0xFFE8EDF5),
      surfaceContainer: Color(0xFF151B25),
      surfaceContainerHighest: Color(0xFF252D3A),
      error: Color(0xFFFF8A8A),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B0F14),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF0B0F14),
        foregroundColor: Color(0xFFE8EDF5),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: const Color(0xFF151B25),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF263241)),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF10151D),
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF151B25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A3545)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A3545)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFD6B46A),
        foregroundColor: Color(0xFF201704),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF263241)),
    );
  }
}
