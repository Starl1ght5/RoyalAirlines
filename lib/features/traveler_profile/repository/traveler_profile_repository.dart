import 'package:royal_airlines/models/reservation_model.dart';
import 'package:royal_airlines/models/travel_class.dart';
import 'package:royal_airlines/models/traveler_profile_model.dart';

/// TravelerProfileRepository
/// -------------------------
/// Arma el [TravelerProfileModel] del usuario actual con un clasificador
/// de tipo "nearest-centroid" (una versión simplificada y transparente
/// de k-means) aplicado sobre SU PROPIO historial de reservas — no hay
/// llamada HTTP para esto, ya que el historial ya vive completo en
/// memoria dentro de `ReservationsStore` tras el login.
class TravelerProfileRepository {
  /// Clasifica el historial de reservas en uno de los arquetipos de
  /// [TravelerArchetype].
  ///
  /// Cómo funciona el clustering (nearest-centroid simplificado):
  /// 1. Se calculan 4 métricas del usuario: total de viajes, destinos
  ///    únicos, % de tarifas más baratas elegidas y % de tarifas
  ///    premium (Business/Primera) elegidas.
  /// 2. Cada [TravelerArchetype] tiene un "centroide" de referencia
  ///    (los valores típicos de ESE perfil) codificado en
  ///    [_archetypeCentroids].
  /// 3. Se mide la distancia euclidiana del usuario a cada centroide y
  ///    se elige el más cercano — el mismo principio que k-means, solo
  ///    que aquí los centroides ya vienen definidos en vez de
  ///    aprenderse iterativamente (más simple y 100% explicable para
  ///    una entrega académica).
  TravelerProfileModel classify(List<ReservationModel> reservations) {
    if (reservations.isEmpty) {
      return TravelerProfileModel.empty();
    }

    final totalTrips = reservations.length;
    final destinationCities =
        reservations.map((r) => r.flight.destination.city).toList();
    final uniqueDestinations = destinationCities.toSet().length;

    final totalSpent =
        reservations.fold<double>(0, (sum, r) => sum + r.totalPrice);
    final averageTicketPrice = totalSpent / totalTrips;

    final cheapestFareCount = reservations
        .where((r) => r.fare.price <= r.flight.cheapestFare.price)
        .length;
    final cheapestFareRatio = cheapestFareCount / totalTrips;

    final premiumCount = reservations
        .where((r) => r.fare.travelClass == TravelClass.business)
        .length;
    final premiumRatio = premiumCount / totalTrips;

    final mostVisitedCity = _mostFrequent(destinationCities);

    final archetype = _nearestArchetype(
      totalTrips: totalTrips,
      uniqueDestinations: uniqueDestinations,
      cheapestFareRatio: cheapestFareRatio,
      premiumRatio: premiumRatio,
    );

    return TravelerProfileModel(
      archetype: archetype,
      totalTrips: totalTrips,
      uniqueDestinations: uniqueDestinations,
      totalSpent: totalSpent,
      averageTicketPrice: averageTicketPrice,
      cheapestFareRatio: cheapestFareRatio,
      premiumRatio: premiumRatio,
      mostVisitedCity: mostVisitedCity,
    );
  }

  /// Centroide de referencia (valores típicos) de cada arquetipo, en el
  /// mismo orden de features que [_features]:
  /// `[totalTrips, uniqueDestinations, cheapestFareRatio, premiumRatio]`.
  /// `totalTrips`/`uniqueDestinations` se normalizan con un techo de 10
  /// viajes para que ninguna métrica domine la distancia solo por tener
  /// una escala numérica más grande.
  static const Map<TravelerArchetype, List<double>> _archetypeCentroids = {
    TravelerArchetype.dealHunter: [0.3, 0.3, 0.95, 0.0],
    TravelerArchetype.explorer: [0.4, 0.9, 0.4, 0.1],
    TravelerArchetype.frequentFlyer: [0.9, 0.5, 0.4, 0.2],
    TravelerArchetype.premiumTraveler: [0.3, 0.3, 0.1, 0.9],
  };

  List<double> _features({
    required int totalTrips,
    required int uniqueDestinations,
    required double cheapestFareRatio,
    required double premiumRatio,
  }) {
    const normalizationCap = 10;
    return [
      (totalTrips / normalizationCap).clamp(0.0, 1.0),
      (uniqueDestinations / normalizationCap).clamp(0.0, 1.0),
      cheapestFareRatio,
      premiumRatio,
    ];
  }

  TravelerArchetype _nearestArchetype({
    required int totalTrips,
    required int uniqueDestinations,
    required double cheapestFareRatio,
    required double premiumRatio,
  }) {
    final userVector = _features(
      totalTrips: totalTrips,
      uniqueDestinations: uniqueDestinations,
      cheapestFareRatio: cheapestFareRatio,
      premiumRatio: premiumRatio,
    );

    TravelerArchetype closest = TravelerArchetype.frequentFlyer;
    double closestDistance = double.infinity;

    for (final entry in _archetypeCentroids.entries) {
      final distance = _squaredDistance(userVector, entry.value);
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = entry.key;
      }
    }

    return closest;
  }

  /// Distancia euclidiana al cuadrado. No hace falta sacar raíz
  /// cuadrada: comparar los cuadrados basta para saber cuál centroide
  /// está más cerca.
  double _squaredDistance(List<double> a, List<double> b) {
    var sumSquares = 0.0;
    for (var i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sumSquares += diff * diff;
    }
    return sumSquares;
  }

  String? _mostFrequent(List<String> values) {
    if (values.isEmpty) return null;
    final counts = <String, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
