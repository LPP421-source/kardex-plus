// lib/theme/app_theme.dart
//
// Tema visual de Kardex+, extraído directamente del código que
// generó Stitch para el Dashboard y el menú lateral. La idea es
// que TODA la app use estos mismos colores y tipografía de forma
// automática, sin tener que rediseñar cada pantalla a mano.
//
// Los nombres de los colores de abajo (primary, onPrimary,
// surfaceContainer, etc.) son exactamente los mismos que usa el
// sistema de diseño "Material 3" de Google — por eso encajan
// directo en el ColorScheme de Flutter.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Paleta de colores (tal cual la generó Stitch) ---
  static const _primary = Color(0xFF005BB3);
  static const _onPrimary = Color(0xFFFFFFFF);
  static const _primaryContainer = Color(0xFF0073DF);
  static const _onPrimaryContainer = Color(0xFFFEFCFF);
  static const _primaryFixed = Color(0xFFD6E3FF);
  static const _onPrimaryFixed = Color(0xFF001B3D);
  static const _primaryFixedDim = Color(0xFFA9C7FF);
  static const _onPrimaryFixedVariant = Color(0xFF00468C);

  static const _secondary = Color(0xFF49607C);
  static const _onSecondary = Color(0xFFFFFFFF);
  static const _secondaryContainer = Color(0xFFC7DFFF);
  static const _onSecondaryContainer = Color(0xFF4B637E);
  static const _secondaryFixed = Color(0xFFD1E4FF);
  static const _onSecondaryFixed = Color(0xFF011D35);
  static const _secondaryFixedDim = Color(0xFFB0C9E8);
  static const _onSecondaryFixedVariant = Color(0xFF314863);

  static const _tertiary = Color(0xFF255BA6);
  static const _onTertiary = Color(0xFFFFFFFF);
  static const _tertiaryContainer = Color(0xFF4374C0);
  static const _onTertiaryContainer = Color(0xFFFEFCFF);
  static const _tertiaryFixed = Color(0xFFD6E3FF);
  static const _onTertiaryFixed = Color(0xFF001B3E);
  static const _tertiaryFixedDim = Color(0xFFAAC7FF);
  static const _onTertiaryFixedVariant = Color(0xFF00458D);

  static const _error = Color(0xFFBA1A1A);
  static const _onError = Color(0xFFFFFFFF);
  static const _errorContainer = Color(0xFFFFDAD6);
  static const _onErrorContainer = Color(0xFF93000A);

  static const _surface = Color(0xFFF8F9FF);
  static const _onSurface = Color(0xFF0B1C30);
  static const _surfaceDim = Color(0xFFCBDBF5);
  static const _surfaceBright = Color(0xFFF8F9FF);
  static const _surfaceContainerLowest = Color(0xFFFFFFFF);
  static const _surfaceContainerLow = Color(0xFFEFF4FF);
  static const _surfaceContainer = Color(0xFFE5EEFF);
  static const _surfaceContainerHigh = Color(0xFFDCE9FF);
  static const _surfaceContainerHighest = Color(0xFFD3E4FE);
  static const _onSurfaceVariant = Color(0xFF414754);

  static const _outline = Color(0xFF717786);
  static const _outlineVariant = Color(0xFFC0C6D6);

  static const _inverseSurface = Color(0xFF213145);
  static const _onInverseSurface = Color(0xFFEAF1FF);
  static const _inversePrimary = Color(0xFFA9C7FF);
  static const _surfaceTint = Color(0xFF005DB7);

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _primary,
    onPrimary: _onPrimary,
    primaryContainer: _primaryContainer,
    onPrimaryContainer: _onPrimaryContainer,
    primaryFixed: _primaryFixed,
    onPrimaryFixed: _onPrimaryFixed,
    primaryFixedDim: _primaryFixedDim,
    onPrimaryFixedVariant: _onPrimaryFixedVariant,
    secondary: _secondary,
    onSecondary: _onSecondary,
    secondaryContainer: _secondaryContainer,
    onSecondaryContainer: _onSecondaryContainer,
    secondaryFixed: _secondaryFixed,
    onSecondaryFixed: _onSecondaryFixed,
    secondaryFixedDim: _secondaryFixedDim,
    onSecondaryFixedVariant: _onSecondaryFixedVariant,
    tertiary: _tertiary,
    onTertiary: _onTertiary,
    tertiaryContainer: _tertiaryContainer,
    onTertiaryContainer: _onTertiaryContainer,
    tertiaryFixed: _tertiaryFixed,
    onTertiaryFixed: _onTertiaryFixed,
    tertiaryFixedDim: _tertiaryFixedDim,
    onTertiaryFixedVariant: _onTertiaryFixedVariant,
    error: _error,
    onError: _onError,
    errorContainer: _errorContainer,
    onErrorContainer: _onErrorContainer,
    surface: _surface,
    onSurface: _onSurface,
    surfaceDim: _surfaceDim,
    surfaceBright: _surfaceBright,
    surfaceContainerLowest: _surfaceContainerLowest,
    surfaceContainerLow: _surfaceContainerLow,
    surfaceContainer: _surfaceContainer,
    surfaceContainerHigh: _surfaceContainerHigh,
    surfaceContainerHighest: _surfaceContainerHighest,
    onSurfaceVariant: _onSurfaceVariant,
    outline: _outline,
    outlineVariant: _outlineVariant,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: _inverseSurface,
    onInverseSurface: _onInverseSurface,
    inversePrimary: _inversePrimary,
    surfaceTint: _surfaceTint,
  );

  /// Tipografía: "Space Grotesk" para títulos (como en el diseño
  /// original) e "Inter" para el resto del texto (sustituto de
  /// "Geist", que todavía no está disponible en el paquete
  /// google_fonts de Flutter).
  static TextTheme get _textTheme {
    final base = TextTheme(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 32,
        height: 38 / 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.96,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.44,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.18,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.16,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.44,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        height: 12 / 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );

    // Aplicamos el color de texto correcto (onSurface) a todos los
    // estilos que definimos arriba, para no tener que escribirlo
    // manualmente en cada uno.
    return base.apply(bodyColor: _onSurface, displayColor: _onSurface);
  }

  static ThemeData get themeData {
    final scheme = colorScheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: _textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}