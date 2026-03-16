import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const tokens = AppThemeTokens(
      appBackground: Color(0xFFF4F6FA),
      surface: Colors.white,
      surfaceElevated: Colors.white,
      surfaceMuted: Color(0xFFF7F9FD),
      surfaceBorder: Color(0xFFE3E8F1),
      surfaceShadow: Color(0x140F172A),
      glassBackground: Color(0xCCFFFFFF),
      glassBorder: Color(0x33E3E8F1),
      primaryText: Color(0xFF18243D),
      secondaryText: Color(0xFF5A6D8B),
      accent: Color(0xFF1B2D63),
      accentSoft: Color(0xFFDCE4F4),
      accentGradient: LinearGradient(
        colors: [Color(0xFF1B2D63), Color(0xFF2A4186)],
      ),
      hero: Color(0xFFFF6A00),
      heroGlow: Color(0xFFFF9248),
      success: Color(0xFF11C979),
      warning: Color(0xFFF8A200),
      badgeOrange: Color(0xFFFF6A3D),
      accentBlue: Color(0xFF3B82F6),
      purple: Color(0xFF695CFF),
      pink: Color(0xFFFF2A68),
      green: Color(0xFF14C77F),
      railBackground: Color(0xFFF7F9FD),
      mobileNavBackground: Colors.white,
      cardRadius: 24,
      pillRadius: 22,
      contentMaxWidth: 1120,
      railWidth: 92,
    );

    final colorScheme = _buildColorScheme(
      tokens: tokens,
      brightness: Brightness.light,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return _themeFromTokens(
      tokens: tokens,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.appBackground,
      filledButtonForegroundColor: Colors.white,
      outlinedForegroundColor: tokens.accent,
    );
  }

  static ThemeData dark() {
    const tokens = AppThemeTokens(
      appBackground: Color(0xFF0F172A),
      surface: Color(0xFF1E293B),
      surfaceElevated: Color(0xFF263146),
      surfaceMuted: Color(0xFF18202D),
      surfaceBorder: Color(0xFF334155),
      surfaceShadow: Color(0x99000000),
      glassBackground: Color(0x991E293B),
      glassBorder: Color(0x3364748B),
      primaryText: Color(0xFFF8FAFC),
      secondaryText: Color(0xFF94A3B8),
      accent: Color(0xFF72A3FF),
      accentSoft: Color(0xFF24314B),
      accentGradient: LinearGradient(
        colors: [Color(0xFF72A3FF), Color(0xFF3B82F6)],
      ),
      hero: Color(0xFFFF7E33),
      heroGlow: Color(0xFFFF9248),
      success: Color(0xFF22D3EE),
      warning: Color(0xFFFBBF24),
      badgeOrange: Color(0xFFFF8C63),
      accentBlue: Color(0xFF72A3FF),
      purple: Color(0xFFA78BFA),
      pink: Color(0xFFFB7185),
      green: Color(0xFF34D399),
      railBackground: Color(0xFF0F172A),
      mobileNavBackground: Color(0xFF0F172A),
      cardRadius: 24,
      pillRadius: 22,
      contentMaxWidth: 1120,
      railWidth: 92,
    );

    final colorScheme = _buildColorScheme(
      tokens: tokens,
      brightness: Brightness.dark,
      onPrimary: const Color(0xFF0F172A),
      onSecondary: Colors.white,
    );

    return _themeFromTokens(
      tokens: tokens,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.appBackground,
      filledButtonForegroundColor: const Color(0xFF0F172A),
      outlinedForegroundColor: tokens.primaryText,
    );
  }

  static ColorScheme _buildColorScheme({
    required AppThemeTokens tokens,
    required Brightness brightness,
    required Color onPrimary,
    required Color onSecondary,
  }) {
    return ColorScheme.fromSeed(
      seedColor: tokens.accent,
      brightness: brightness,
    ).copyWith(
      primary: tokens.accent,
      onPrimary: onPrimary,
      secondary: tokens.hero,
      onSecondary: onSecondary,
      surface: tokens.surface,
      onSurface: tokens.primaryText,
      outlineVariant: tokens.surfaceBorder,
      shadow: tokens.surfaceShadow,
    );
  }

  static ThemeData _themeFromTokens({
    required AppThemeTokens tokens,
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required Color filledButtonForegroundColor,
    required Color outlinedForegroundColor,
  }) {
    final textTheme = GoogleFonts.outfitTextTheme(
      TextTheme(
        displayLarge: TextStyle(
          fontSize: 46,
          height: 1.05,
          fontWeight: FontWeight.w800,
          color: tokens.primaryText,
          letterSpacing: -1.5,
        ),
        displaySmall: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: tokens.primaryText,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 30,
          height: 1.14,
          fontWeight: FontWeight.w800,
          color: tokens.primaryText,
          letterSpacing: -1,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: tokens.primaryText,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: tokens.primaryText,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: tokens.primaryText,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: tokens.primaryText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: tokens.secondaryText,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: tokens.secondaryText,
        ),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarThemeData(
        backgroundColor: tokens.surface,
        elevation: 0,
        scrolledUnderElevation: 8,
        surfaceTintColor: tokens.appBackground.withValues(alpha: 0.1),
        foregroundColor: tokens.primaryText,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: tokens.surfaceShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: BorderSide(color: tokens.surfaceBorder, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaceMuted,
        disabledColor: tokens.surfaceMuted,
        selectedColor: tokens.accentSoft,
        side: BorderSide(color: tokens.surfaceBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.pillRadius),
        ),
        labelStyle: textTheme.bodySmall?.copyWith(
          color: tokens.primaryText,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceMuted.withValues(alpha: 0.5),
        hintStyle: textTheme.titleMedium?.copyWith(
          color: tokens.secondaryText.withValues(alpha: 0.6),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
        prefixIconColor: tokens.secondaryText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius - 4),
          borderSide: BorderSide(color: tokens.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius - 4),
          borderSide: BorderSide(color: tokens.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius - 4),
          borderSide: BorderSide(color: tokens.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: filledButtonForegroundColor,
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.pillRadius),
          ),
          textStyle: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: outlinedForegroundColor,
          side: BorderSide(color: tokens.surfaceBorder),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.pillRadius),
          ),
          textStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          textStyle: textTheme.titleMedium,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.titleMedium),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return tokens.surface;
            }
            return tokens.surfaceMuted;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return tokens.primaryText;
            }
            return tokens.secondaryText;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: tokens.surfaceBorder)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.pillRadius - 4),
            ),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.accent;
          }
          return tokens.secondaryText.withValues(alpha: 0.5);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.accentSoft;
          }
          return tokens.surfaceMuted;
        }),
      ),
      dividerColor: tokens.surfaceBorder,
    );
  }
}
