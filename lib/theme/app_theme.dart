import 'package:flutter/material.dart';

class AppTheme {
  // Replit :root renkleri
  static const Color background = Color(0xFFF8FAFC); // 210 40% 98%
  static const Color foreground = Color(0xFF0F172A); // 222 47% 11%
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0); // 214 32% 91%
  static const Color muted = Color(0xFFF1F5F9); // 210 40% 96%
  static const Color mutedForeground = Color(0xFF64748B); // 215 16% 47%

  static const Color primary = Color(0xFF2563EB); // 221 83% 53%
  static const Color primaryForeground = Color(0xFFF8FAFC);

  static const Color destructive = Color(0xFFEF4444);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: primaryForeground,
      surface: card,
      onSurface: foreground,
      error: destructive,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: card,
      foregroundColor: foreground,
      elevation: 0,
      centerTitle: true,
    ),
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.6),
      ),
      labelStyle: const TextStyle(color: mutedForeground),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // rounded-2xl
        side: const BorderSide(color: border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: primaryForeground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: primaryForeground,
    ),
  );
}
