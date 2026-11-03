/// AppSpacing
/// ----------
/// Escala de espaciado única para toda la app. Antes cada widget
/// usaba números sueltos (14, 16, 18, 20...) elegidos a ojo, lo que
/// generaba pequeñas inconsistencias visuales entre pantallas. Esta
/// escala sigue un incremento de 4px (estándar en diseño de apps
/// móviles), y todo widget nuevo o remodelado debe usar estos valores
/// en vez de números mágicos.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Padding horizontal estándar de pantalla completa (listas, forms).
  static const double screenPadding = 20;

  /// Radio de esquina para tarjetas grandes (FlightCard, SearchCard).
  static const double radiusLg = 22;

  /// Radio de esquina para elementos medianos (botones, inputs, chips).
  static const double radiusMd = 16;

  /// Radio de esquina para elementos pequeños (badges, tags).
  static const double radiusSm = 10;

  /// Radio de esquina extra grande, para hojas modales (bottom sheets)
  /// y contenedores hero que necesitan sentirse aún más suaves.
  static const double radiusXl = 28;

  /// Altura mínima táctil recomendada (Material + iOS HIG): cualquier
  /// elemento tocable (botón, ítem de lista, chip) no debe ser menor
  /// a esto, para que el dedo lo alcance cómodo en pantallas de
  /// ~6.1-6.7" como el Pixel 8/8 Pro.
  static const double minTouchTarget = 44;
}
