import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';

/// AppTheme
/// --------
/// Ensambla el [ThemeData] de Material 3 de la app. Usa 'Plus Jakarta
/// Sans' de Google Fonts — una tipografía geométrica y elegante, con
/// buen peso en los números (importante para precios/horarios), en
/// vez de la Roboto por defecto de Android que se ve genérica.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.gold,
        surface: AppColors.surface,
        error: AppColors.error,
        tertiary: AppColors.goldLight,
      ),
      textTheme: baseTextTheme.copyWith(
        // Títulos grandes: peso alto, letter-spacing ligeramente
        // negativo (look editorial/premium en vez de "app genérica").
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: Color(0x33204D7C),
        selectionHandleColor: AppColors.primary,
      ),
    );
  }
}

/// AppShadows
/// ----------
/// Fuente única de sombras reutilizables. Antes cada tarjeta definía su
/// propio `BoxShadow` con valores distintos (blur, alpha, offset), lo que
/// generaba inconsistencias sutiles de profundidad entre pantallas. Usa
/// estas listas en vez de crear sombras nuevas en cada widget.
class AppShadows {
  AppShadows._();

  /// Sombra suave estándar para tarjetas en reposo (listas, secciones).
  static final List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  /// Sombra un poco más marcada para elementos flotantes (bottom sheets,
  /// tarjetas seleccionadas, botones destacados).
  static final List<BoxShadow> floating = [
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
  ];

  /// Resplandor dorado sutil, para tarjetas/badges que representan la
  /// opción "premium" o seleccionada dentro de un grupo.
  static final List<BoxShadow> goldGlow = [
    BoxShadow(
      color: AppColors.gold.withValues(alpha: 0.28),
      blurRadius: 20,
      spreadRadius: -2,
      offset: const Offset(0, 6),
    ),
  ];
}
