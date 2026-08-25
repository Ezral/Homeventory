import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual language: moss + charcoal map of the home — not purple, not cream terracotta.
abstract final class AppColors {
  static const moss = Color(0xFF1F5C4A);
  static const mossDeep = Color(0xFF143D33);
  static const mossSoft = Color(0xFFD7E8E0);
  static const ink = Color(0xFF1B2421);
  static const inkMuted = Color(0xFF5A6B64);
  static const paper = Color(0xFFF3F6F4);
  static const paperElevated = Color(0xFFFFFFFF);
  static const amber = Color(0xFFC9892B);
  static const danger = Color(0xFFA33B2D);
  static const line = Color(0xFFCBD8D1);
}

abstract final class AppTextStyles {
  static const bulkCell = TextStyle(
    fontSize: 11,
    height: 1.25,
    color: AppColors.ink,
  );
  static const bulkCellHint = TextStyle(
    fontSize: 11,
    height: 1.2,
    color: AppColors.inkMuted,
  );
}

ThemeData buildHomeventoryTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.moss,
      onPrimary: Colors.white,
      secondary: AppColors.amber,
      onSecondary: AppColors.ink,
      surface: AppColors.paperElevated,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      outline: AppColors.line,
    ),
    scaffoldBackgroundColor: AppColors.paper,
  );

  final poppins = GoogleFonts.poppinsTextTheme(base.textTheme);

  return base.copyWith(
    textTheme: poppins.copyWith(
      displayLarge: poppins.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -1.2,
      ),
      displayMedium: poppins.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.8,
      ),
      headlineLarge: poppins.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineMedium: poppins.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      headlineSmall: poppins.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleLarge: poppins.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleMedium: poppins.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: poppins.bodyLarge?.copyWith(color: AppColors.ink, height: 1.4),
      bodyMedium: poppins.bodyMedium?.copyWith(
        color: AppColors.inkMuted,
        height: 1.4,
      ),
      labelLarge: poppins.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: poppins.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        fontSize: 20,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.moss,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: poppins.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.mossDeep,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.line, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paperElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.moss, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.mossSoft,
      labelStyle: poppins.labelMedium?.copyWith(color: AppColors.mossDeep),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: poppins.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
