import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Lazily-built but cached ThemeData. Building Material3 ThemeData isn't
/// cheap (it composes ColorScheme + all the sub-themes + text themes), so
/// computing it on every MaterialApp rebuild is wasted work and a noticeable
/// hitch when the user toggles theme mode.
class AppTheme {
  static final ThemeData lightTheme = _buildLightTheme();
  static final ThemeData darkTheme = _buildDarkTheme();

  // ── Light ─────────────────────────────────────────────────────────
  static ThemeData _buildLightTheme() {
    const cs = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primary,

      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.accentLight,
      onSecondaryContainer: AppColors.accent,

      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerHighest: Color(0xFFEEF2EF),
      surfaceContainer: Color(0xFFF2F5F2),
      surfaceContainerLow: Color(0xFFF6F8F6),
      surfaceContainerLowest: AppColors.surface,

      outline: AppColors.border,
      outlineVariant: AppColors.divider,
      shadow: Colors.black,

      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: cs,

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: Color(0x0D000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
    );
  }

  // ── Dark ──────────────────────────────────────────────────────────
  static ThemeData _buildDarkTheme() {
    // Forest-green palette tweaked for dark backgrounds.
    const darkBg = Color(0xFF121712);            // scaffold
    const darkSurface = Color(0xFF1B221C);       // cards
    const darkSurfaceHigh = Color(0xFF252D26);   // chips, info panels
    const darkSurfaceMid = Color(0xFF1F2620);
    const darkSurfaceLow = Color(0xFF181D18);

    const onSurface = Color(0xFFE6ECE7);         // primary text
    const onSurfaceVariant = Color(0xFFB2BDB4);  // secondary text — visible on dark
    const outline = Color(0xFF3A4239);
    const outlineVariant = Color(0xFF2A2F2A);

    const cs = ColorScheme.dark(
      primary: AppColors.primaryDark,           // brighter forest green
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF1F3F2F),
      onPrimaryContainer: AppColors.primaryDark,

      secondary: AppColors.accent,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF3B231C),
      onSecondaryContainer: AppColors.accent,

      surface: darkSurface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerHighest: darkSurfaceHigh,
      surfaceContainer: darkSurfaceMid,
      surfaceContainerLow: darkSurfaceLow,
      surfaceContainerLowest: darkBg,

      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Colors.black,

      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryDark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: cs,

      // Make all default text colors honor onSurface/onSurfaceVariant so
      // widgets that don't explicitly read colorScheme still pick up the
      // right color when the user is in dark mode.
      textTheme: const TextTheme().apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),

      cardTheme: const CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: outlineVariant),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: onSurfaceVariant,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide:
              const BorderSide(color: AppColors.primaryDark, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        hintStyle: const TextStyle(color: onSurfaceVariant),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 1,
      ),
    );
  }
}
