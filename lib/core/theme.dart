import 'package:flutter/material.dart';

abstract final class AppColors {
  static const green = Color(0xFF008B57);
  static const darkGreen = Color(0xFF044B41);
  static const navy = Color(0xFF081C3A);
  static const muted = Color(0xFF75849A);
  static const mint = Color(0xFFE7F7ED);
  static const background = Color(0xFFF6F9F8);
  static const border = Color(0xFFE3EBE8);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.green,
    primary: AppColors.green,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: AppColors.background,
  fontFamily: 'Inter',
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: AppColors.navy,
      letterSpacing: -1.1,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: AppColors.navy,
      letterSpacing: -.7,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: AppColors.navy,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.navy,
    ),
    bodyLarge: TextStyle(fontSize: 15, color: AppColors.navy),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.navy, height: 1.45),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.green,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontFamily: 'Inter',
      fontSize: 19,
      fontWeight: FontWeight.w700,
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: AppColors.green,
      side: const BorderSide(color: AppColors.green),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFFAFCFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.green, width: 1.5),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: AppColors.mint,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    ),
  ),
  dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
);
