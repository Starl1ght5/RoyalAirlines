import 'package:royal_airlines/models/destination_profile.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';

/// RecommendationResult
/// --------------------
/// Resultado de evaluar UN destino contra el perfil del usuario. Es el
/// objeto que consume la UI (tarjeta de recomendación y bottom sheet
/// con el radar).
class RecommendationResult {
  final DestinationProfile destination;

  /// Score de afinidad 0-1: combinación ponderada de los sub-scores.
  final double affinity;

  /// Sub-scores individuales 0-1, expuestos para que el sheet pueda
  /// mostrar el desglose ("por qué te lo recomendamos").
  final double interestScore;
  final double budgetScore;
  final double seasonalityScore;
  final double historyScore;

  /// Probabilidad estimada de que la experiencia sea favorable (0-1).
  /// Derivada de la afinidad combinada con la solidez del perfil.
  final double favorableExperienceProbability;

  /// Frases cortas listas para mostrar como chips ("Combina con tu
  /// interés en Playa", "Ideal en diciembre").
  final List<String> reasons;

  /// Id REAL del destino en el backend (`Location.locationID`), solo
  /// cuando la recomendación viene de `GET /recommendations`. El motor
  /// local no lo conoce → `null` (los corazones resuelven el id por
  /// IATA contra el catálogo como respaldo).
  final String? locationId;

  /// Intensidad del usuario y del destino, EJE POR EJE, en el orden
  /// fijo de [TravelInterest.values] — así el radar siempre dibuja los
  /// mismos 8 ejes en el mismo orden para cualquier combinación.
  final List<double> userRadarValues;
  final List<double> destinationRadarValues;

  const RecommendationResult({
    required this.destination,
    required this.affinity,
    required this.interestScore,
    required this.budgetScore,
    required this.seasonalityScore,
    required this.historyScore,
    required this.favorableExperienceProbability,
    required this.reasons,
    this.locationId,
    required this.userRadarValues,
    required this.destinationRadarValues,
  });

  int get affinityPercent => (affinity * 100).round();

  int get favorablePercent => (favorableExperienceProbability * 100).round();
}
