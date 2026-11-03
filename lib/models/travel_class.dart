/// TravelClass
/// -----------
/// Clase de viaje. Vive en `models/` (no dentro de `features/home/`)
/// porque tanto el buscador de Home como la selección de tarifa en
/// Flights (y más adelante Booking) necesitan el mismo enum — antes
/// vivía en `home_controller.dart`, se movió aquí al volverse
/// compartido entre dos features (DRY).
enum TravelClass { economy, premiumEconomy, business }

/// Etiquetas legibles de [TravelClass], para no repetir un `switch`
/// de texto en cada widget que las muestre.
extension TravelClassLabel on TravelClass {
  String get label {
    switch (this) {
      case TravelClass.economy:
        return 'Económica';
      case TravelClass.premiumEconomy:
        return 'Económica Premium';
      case TravelClass.business:
        return 'Business';
    }
  }

  /// Etiqueta corta, usada en espacios reducidos como [FareCard].
  String get shortLabel {
    switch (this) {
      case TravelClass.economy:
        return 'Económica';
      case TravelClass.premiumEconomy:
        return 'Premium';
      case TravelClass.business:
        return 'Business';
    }
  }

  /// Nombre estable (no traducible) usado para persistir en disco/JSON.
  /// Nunca usar [label]/[shortLabel] para esto: cambiarían el texto
  /// visible rompería la serialización guardada de reservas viejas.
  String get storageKey => name;
}

/// Reconstruye un [TravelClass] desde el valor del backend o desde
/// [TravelClass.storageKey]. Tolera variantes como "Premium Economy",
/// "premium_economy" o "PREMIUM-ECONOMY" normalizando a minúsculas y
/// quitando separadores. Si el valor no coincide con ninguna (versión
/// vieja de la app), cae a [TravelClass.economy] en vez de lanzar.
TravelClass travelClassFromStorageKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');
  for (final value in TravelClass.values) {
    if (value.name.toLowerCase() == normalized) return value;
  }
  return TravelClass.economy;
}
