import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UrjaTheme {
  // Brand Colors (Lovable/Tailwind inspired)
  static const Color darkBackground = Color(0xFF030712); // Deep Dark Blue/Black
  static const Color cardBackground = Color(0xFF111827); // Slightly lighter for fallback
  static const Color glassBorder = Color(0xFF1F2937); // Thin border
  static const Color primaryGreen = Color(0xFF22C55E); // Electric Green
  static const Color accentCyan = Color(0xFF06B6D4); // Cyan for gradients
  static const Color textPrimary = Color(0xFFF9FAFB); // Clean White
  static const Color textSecondary = Color(0xFF9CA3AF); // Muted Gray

  // Legacy/Fallback
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFFFFFFF); // Pure White
  static const Color lightCardBackground = Color(0xFFF0F2F5); // Slightly darker greyish-white for tiles
  static const Color lightTextPrimary = Color(0xFF1F2937); // Dark Grey/Black
  static const Color lightTextSecondary = Color(0xFF6B7280); // Medium Grey
  static const Color lightBorder = Color(0xFFE5E7EB); // Light Grey Border

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightCardBackground,
      dividerColor: lightBorder,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: accentCyan,
        surface: lightCardBackground,
        error: errorRed,
        onSurface: lightTextPrimary,
        onSurfaceVariant: lightTextSecondary,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold, letterSpacing: -1.0),
          headlineMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          titleLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: lightTextSecondary),
          bodyMedium: TextStyle(color: lightTextSecondary),
          bodySmall: TextStyle(color: lightTextSecondary),
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(color: lightTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(
        color: lightTextSecondary,
        size: 24,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: primaryGreen,
        surface: Colors.transparent, // For glass effect
        error: errorRed,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, letterSpacing: -1.0),
          headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: textSecondary),
          bodyMedium: TextStyle(color: textSecondary),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.03), // Glass base
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: glassBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),
      // Global Fix for White Lines/Highlights
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      navigationRailTheme: const NavigationRailThemeData(
        indicatorColor: Colors.transparent,
      ),
    );
  }
}
