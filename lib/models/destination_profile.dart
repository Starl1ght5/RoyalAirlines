import 'package:royal_airlines/models/traveler_preferences_model.dart';

/// DestinationProfile
/// ------------------
/// Perfil turístico de un destino: a qué tipo de viaje apela (con un
/// peso 0-1 por cada [TravelInterest]), en qué meses brilla, cuánto
/// cuesta en promedio y si hoy se puede reservar desde la app.
///
/// Existe como modelo LOCAL (no viene del backend) porque los destinos
/// del catálogo actual solo traen código/ciudad/país/aeropuerto: las
/// categorías turísticas son un dato curado para el motor de
/// recomendaciones (Etapa C), no una entidad de la API.
class DestinationProfile {
  /// Código IATA, ej. "MAD" — se alinea con [AirportModel.code] para
  /// poder enlazar la recomendación con el buscador de vuelos.
  final String code;

  final String city;
  final String country;

  /// Peso de cada interés turístico del destino (0-1). Un destino de
  /// playa tendrá `playa: 0.95` y `nieve: 0.05`, por ejemplo. No es
  /// obligatorio que todas las claves de [TravelInterest] estén: las
  /// ausentes se tratan como 0.
  final Map<TravelInterest, double> interestWeights;

  /// Meses (1-12) en los que el destino es más recomendable
  /// (clima/temporada alta). Vacío = destino sin estacionalidad marcada.
  final List<int> bestMonths;

  /// Precio promedio de un tiquete a este destino, en COP. Se compara
  /// contra el presupuesto declarado por el usuario.
  final double averagePriceCop;

  /// `true` si el destino forma parte del catálogo de vuelos actual
  /// (se puede reservar hoy). `false` para destinos aspiracionales
  /// que el motor recomienda como inspiración aunque aún no exista
  /// ruta (ej. auroras en Noruega).
  final bool isBookable;

  const DestinationProfile({
    required this.code,
    required this.city,
    required this.country,
    required this.interestWeights,
    required this.bestMonths,
    required this.averagePriceCop,
    this.isBookable = true,
  });

  /// Peso del destino para un interés puntual (0 si no está mapeado).
  double weightFor(TravelInterest interest) => interestWeights[interest] ?? 0;

  /// Intereses con peso significativo (>= 0.4), ordenados de mayor a
  /// menor peso. Son los que la UI muestra como "etiquetas" del
  /// destino ("playa", "cultura"...).
  List<TravelInterest> get prominentInterests {
    final entries = interestWeights.entries
        .where((entry) => entry.value >= 0.4)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((entry) => entry.key).toList();
  }
}
