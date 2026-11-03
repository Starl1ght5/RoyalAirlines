import 'package:flutter/material.dart';

/// AppColors
/// ---------
/// Fuente única de verdad para todos los colores de Royal Airlines.
/// NUNCA se debe duplicar esta clase ni crear paletas alternativas
/// en otros archivos. Cualquier color nuevo que se necesite en un
/// módulo futuro debe agregarse AQUÍ, no en el widget que lo usa.
///
/// Paleta inspirada en aerolíneas premium (Qatar Airways / Emirates)
/// combinada con la limpieza visual de Apple Design.
class AppColors {
  AppColors._(); // Evita instanciación (clase estática pura).

  // ---------------------------------------------------------------------
  // Colores primarios de marca
  // ---------------------------------------------------------------------

  /// Azul marino profundo — base corporativa premium con un aire más
  /// contemporáneo que la versión previa.
  static const Color primary = Color(0xFF102E4A);

  /// Variante clara del primario, ideal para fondos elevadores y CTA.
  static const Color primaryLight = Color(0xFF1D4F7A);

  /// Variante muy oscura del primario para AppBars, fondos intensos y
  /// profundidad visual durante la navegación.
  static const Color primaryDark = Color(0xFF0A1E34);

  /// Dorado cálido y premium — una versión más moderna que mantiene la
  /// sensación de lujo sin ser demasiado clásico.
  static const Color gold = Color(0xFFE0A857);

  /// Variante clara del dorado para chips y destacados sutiles.
  static const Color goldLight = Color(0xFFF4D39A);

  // ---------------------------------------------------------------------
  // Neutros (más aire, más claridad, más “premium móvil”)
  // ---------------------------------------------------------------------

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF3F9);

  static const Color textPrimary = Color(0xFF1B2331);
  static const Color textSecondary = Color(0xFF5D6A7A);
  static const Color textTertiary = Color(0xFF8A96A8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color divider = Color(0xFFE5EBF2);
  static const Color border = Color(0xFFE3E8F1);

  // ---------------------------------------------------------------------
  // Colores de estado (más vivos y legibles)
  // ---------------------------------------------------------------------

  static const Color success = Color(0xFF1AA87C);
  static const Color error = Color(0xFFE35D5D);
  static const Color warning = Color(0xFFF1B14E);
  static const Color info = Color(0xFF4A88DA);

  // ---------------------------------------------------------------------
  // Gradientes reutilizables
  // ---------------------------------------------------------------------

  /// Gradiente de marca usado en Splash, headers y botones principales.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, Color(0xFF204D7C)],
  );

  /// Gradiente dorado, usado en acentos, badges premium o CTAs especiales.
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldLight],
  );

  /// Gradiente sutil para fondos de tarjeta "glass" sobre superficies
  /// claras (bordes superiores más luminosos que los inferiores).
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFD)],
  );

  // ---------------------------------------------------------------------
  // Overlays y superficies auxiliares (glassmorphism / skeletons)
  // ---------------------------------------------------------------------

  /// Velo blanco translúcido usado sobre imágenes o gradientes oscuros
  /// para lograr paneles "glass" legibles (chips, mini-tarjetas).
  static const Color glassOverlay = Color(0x1FFFFFFF);

  /// Base y brillo para placeholders de carga tipo skeleton, evitando
  /// depender de un paquete externo de shimmer.
  static const Color skeletonBase = Color(0xFFE7ECF3);
  static const Color skeletonHighlight = Color(0xFFF4F7FB);
}
