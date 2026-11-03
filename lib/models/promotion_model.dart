/// PromotionModel
/// ---------------
/// Modelo de promoción para el slider de Home.
///
/// [origin], [destination] y [departureDate] son la ruta y la fecha con
/// las que se arma la búsqueda al tocar la tarjeta: el backend las
/// toma del vuelo más barato de la ruta, de modo que la búsqueda
/// siempre aterriza en un día con vuelos reales. Son opcionales porque
/// un backend anterior no las envía — en ese caso el tap cae a la
/// fecha elegida en el buscador.
class PromotionModel {
  final String title;
  final String subtitle;
  final String discountLabel;

  /// Código IATA de origen/destino de la ruta, ej. `"BOG"` / `"CTG"`.
  final String? origin;
  final String? destination;

  /// Fecha de salida (yyyy-MM-dd) del vuelo ancla de la promoción.
  final DateTime? departureDate;

  const PromotionModel({
    required this.title,
    required this.subtitle,
    required this.discountLabel,
    this.origin,
    this.destination,
    this.departureDate,
  });
}
