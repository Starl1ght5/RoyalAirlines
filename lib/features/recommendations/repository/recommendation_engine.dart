import 'package:royal_airlines/features/recommendations/data/destination_catalog.dart';
import 'package:royal_airlines/models/destination_profile.dart';
import 'package:royal_airlines/models/recommendation_model.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';

/// RecommendationEngine
/// --------------------
/// Motor de recomendaciones (Etapa C): casar el perfil DECLARADO del
/// usuario (preferencias) y su historial contra el catálogo de
/// destinos, y devolver un ranking con un índice de afinidad 0-1.
///
/// Es un scoring DETERMINISTA y EXPLICABLE (sin ML pesado): cada
/// destino recibe 4 sub-scores que se combinan con pesos fijos:
///
/// | Componente    | Peso | Idea                                                    |
/// |---------------|------|---------------------------------------------------------|
/// | Intereses     | 40%  | ¿Los intereses del destino son los del usuario?          |
/// | Presupuesto   | 25%  | ¿El precio promedio cabe (o es inferior) a su rango?     |
/// | Estacionalidad| 20%  | ¿El destino brilla en meses que el usuario puede viajar? |
/// | Historial     | 15%  | ¿Repite categorías que ya visitó? (evita repetir perfil) |
///
/// La [RecommendationResult.favorableExperienceProbability] nace de la
/// afinidad ajustada por la SOLIDEZ del perfil: un perfil completo con
/// historial calibra mejor la predicción que uno recién llenado.
///
/// Del audio con el profesor: "combinar las variables para comparar y
/// predecir la probabilidad de que la experiencia sea favorable".
class RecommendationEngine {
  const RecommendationEngine();

  /// Pesos del scoring. Suman 1.0 y están documentados arriba.
  static const double interestWeight = 0.40;
  static const double budgetWeight = 0.25;
  static const double seasonalityWeight = 0.20;
  static const double historyWeight = 0.15;

  /// Valor base del radar para ejes sin dato: evita que el polígono
  /// del usuario colapse al centro exacto y permita comparar.
  static const double _radarFloor = 0.12;

  /// Evalúa TODO el catálogo contra el perfil y devuelve el ranking
  /// completo ordenado de mayor a menor afinidad.
  ///
  /// [visitedCities] son las ciudades del historial de reservas (las
  /// usa el componente de historial). [now] se inyecta para poder
  /// testear la estacionalidad con meses fijos.
  List<RecommendationResult> recommend({
    required TravelerPreferencesModel preferences,
    List<String> visitedCities = const [],
    List<DestinationProfile> catalog = DestinationCatalog.all,
    DateTime? now,
  }) {
    final currentDate = now ?? DateTime.now();
    final results = <RecommendationResult>[];

    for (final destination in catalog) {
      results.add(
        evaluate(
          destination: destination,
          preferences: preferences,
          visitedCities: visitedCities,
          currentMonth: currentDate.month,
        ),
      );
    }

    results.sort((a, b) => b.affinity.compareTo(a.affinity));
    return results;
  }

  /// Evalúa UN destino contra el perfil. Expuesta para tests y para
  /// que la UI pueda re-evaluar un destino puntual.
  RecommendationResult evaluate({
    required DestinationProfile destination,
    required TravelerPreferencesModel preferences,
    List<String> visitedCities = const [],
    required int currentMonth,
  }) {
    final interestScore = _interestScore(destination, preferences);
    final budgetScore = _budgetScore(destination, preferences);
    final seasonalityScore = _seasonalityScore(
      destination: destination,
      preferences: preferences,
      currentMonth: currentMonth,
    );
    final historyScore = _historyScore(destination, visitedCities);

    final affinity = interestScore * interestWeight +
        budgetScore * budgetWeight +
        seasonalityScore * seasonalityWeight +
        historyScore * historyWeight;

    final favorableProbability = favorableProbabilityFor(
      affinity: affinity,
      preferences: preferences,
      hasHistory: visitedCities.isNotEmpty,
    );

    return RecommendationResult(
      destination: destination,
      affinity: affinity.clamp(0.0, 1.0),
      interestScore: interestScore,
      budgetScore: budgetScore,
      seasonalityScore: seasonalityScore,
      historyScore: historyScore,
      favorableExperienceProbability: favorableProbability.clamp(0.0, 1.0),
      reasons: _reasons(
        destination: destination,
        preferences: preferences,
        visitedCities: visitedCities,
        budgetScore: budgetScore,
        seasonalityScore: seasonalityScore,
      ),
      userRadarValues: userRadarValues(preferences),
      destinationRadarValues: destinationRadarValues(destination),
    );
  }

  // ---------------------------------------------------------------------
  // Sub-scores
  // ---------------------------------------------------------------------

  /// Intereses: promedio del peso del destino PARA los intereses que el
  /// usuario marcó. Si el usuario marco "playa" y el destino es 95%
  /// playa, aporta 0.95; si marcó "nieve" y el destino no tiene nieve,
  /// aporta 0 y baja el promedio. Sin intereses declarados → 0.
  double _interestScore(
    DestinationProfile destination,
    TravelerPreferencesModel preferences,
  ) {
    final interests = preferences.interests;
    if (interests.isEmpty) return 0;

    var sum = 0.0;
    for (final interest in interests) {
      sum += destination.weightFor(interest);
    }
    return sum / interests.length;
  }

  /// Presupuesto: viajar barato NUNCA se penaliza — si el precio
  /// promedio del destino cabe en el rango declarado, el score es 1.0.
  /// Si excede el máximo, se penaliza linealmente: un destino 50% sobre
  /// el presupuesto queda en 0 (imposible), uno 25% sobre queda 0.5.
  double _budgetScore(
    DestinationProfile destination,
    TravelerPreferencesModel preferences,
  ) {
    if (preferences.budgetMax <= 0) return 0;

    final price = destination.averagePriceCop;
    if (price <= preferences.budgetMax) return 1.0;

    final overshootRatio =
        (price - preferences.budgetMax) / preferences.budgetMax;
    return (1 - overshootRatio * 2).clamp(0.0, 1.0);
  }

  /// Estacionalidad (la variable "de enero a junio / de diciembre a
  /// marzo" del audio):
  /// - Mes actual ideal Y el usuario puede viajar ahora → 1.0.
  /// - Sus meses disponibles no tocan NINGÚN mes ideal → casi 0.
  /// - Hay traslape pero no es el mes actual → parcial, proporcional.
  /// Sin meses declarados → neutral 0.6 (no penaliza ni premia).
  double _seasonalityScore({
    required DestinationProfile destination,
    required TravelerPreferencesModel preferences,
    required int currentMonth,
  }) {
    final preferred = preferences.preferredMonths.toSet();
    if (preferred.isEmpty) return 0.6;

    final best = destination.bestMonths.toSet();
    if (best.isEmpty) return 0.6;

    final isNowGood = best.contains(currentMonth);
    final canTravelNow = preferred.contains(currentMonth);

    if (isNowGood && canTravelNow) return 1.0;

    final overlap = best.intersection(preferred);
    if (overlap.isEmpty) return 0.1;

    final overlapRatio = overlap.length / best.length;
    return 0.5 + 0.4 * overlapRatio;
  }

  /// Historial: mapea las ciudades ya visitadas contra el catálogo y
  /// premia destinos que comparten categorías prominentes. Así quien
  /// ya voló a la playa recibe un ligero empujón hacia más playa, y
  /// hacia lo diferente un poco menos — pero NUNCA es excluyente: el
  /// componente pesa solo 15%. Sin historial → neutral 0.5.
  double _historyScore(
    DestinationProfile destination,
    List<String> visitedCities,
  ) {
    final visitedProfiles = visitedCities
        .map(DestinationCatalog.byCity)
        .whereType<DestinationProfile>()
        .toList();
    if (visitedProfiles.isEmpty) return 0.5;

    final prominent = destination.prominentInterests;
    if (prominent.isEmpty) return 0.5;

    var matches = 0;
    for (final interest in prominent) {
      final alreadyVisited =
          visitedProfiles.any((p) => p.weightFor(interest) >= 0.4);
      if (alreadyVisited) matches++;
    }
    return matches / prominent.length;
  }

  /// Probabilidad de experiencia favorable: la afinidad del match
  /// escalada por cuán completo y experimentado está el perfil.
  /// Perfiles con intereses+presupuesto+meses y al menos un viaje previo
  /// dan más confianza en la predicción.
  ///
  /// Es PÚBLICA porque también la usa el mapper de recomendaciones
  /// remotas (`RecommendationMapper`), que debe derivar la misma
  /// probabilidad a partir del `score` que manda el backend.
  double favorableProbabilityFor({
    required double affinity,
    required TravelerPreferencesModel preferences,
    required bool hasHistory,
  }) {
    final completion = preferences.completionPercentage / 100;
    final confidence = 0.6 * completion + 0.4 * (hasHistory ? 1.0 : 0.3);
    return affinity * (0.75 + 0.25 * confidence);
  }

  // ---------------------------------------------------------------------
  // Radar (usuario vs destino, 8 ejes en orden de TravelInterest.values)
  // ---------------------------------------------------------------------

  /// Radar del USUARIO (1.0 en los intereses declarados, piso bajo en
  /// el resto). Público: lo reutiliza [RecommendationMapper] para que
  /// el radar de una recomendación REMOTA dibuje los mismos ejes.
  List<double> userRadarValues(TravelerPreferencesModel preferences) {
    return TravelInterest.values
        .map((interest) =>
            preferences.interests.contains(interest) ? 1.0 : _radarFloor)
        .toList();
  }

  /// Radar del DESTINO (peso 0-1 por interés). Público: lo reutiliza
  /// [RecommendationMapper].
  List<double> destinationRadarValues(DestinationProfile destination) {
    return TravelInterest.values
        .map((interest) => destination.weightFor(interest))
        .toList();
  }

  // ---------------------------------------------------------------------
  // Razones explicables
  // ---------------------------------------------------------------------

  List<String> _reasons({
    required DestinationProfile destination,
    required TravelerPreferencesModel preferences,
    required List<String> visitedCities,
    required double budgetScore,
    required double seasonalityScore,
  }) {
    final reasons = <String>[];

    final matchedInterests = preferences.interests
        .where((interest) => destination.weightFor(interest) >= 0.6)
        .toList();
    if (matchedInterests.isNotEmpty) {
      final labels = matchedInterests
          .take(2)
          .map((interest) => interest.label)
          .join(' y ');
      reasons.add('Combina con tu interés en $labels');
    }

    if (budgetScore >= 0.999) {
      reasons.add('Encaja en tu presupuesto');
    } else if (budgetScore > 0) {
      reasons.add('Un poco sobre tu presupuesto');
    } else {
      reasons.add('Supera tu presupuesto por ahora');
    }

    if (seasonalityScore >= 0.999) {
      reasons.add('Es temporada ideal según tus meses');
    } else if (seasonalityScore >= 0.6) {
      reasons.add('Buena opción para tus meses disponibles');
    }

    final visitedProfiles = visitedCities
        .map(DestinationCatalog.byCity)
        .whereType<DestinationProfile>()
        .toList();
    final repeatsCategory = visitedProfiles.any((profile) => destination
        .prominentInterests
        .any((interest) => profile.weightFor(interest) >= 0.4));
    if (visitedProfiles.isNotEmpty && repeatsCategory) {
      reasons.add('Amplía lo que ya disfrutaste en viajes anteriores');
    }

    if (!destination.isBookable) {
      reasons.add('Destino inspiracional: ruta próximamente');
    }

    return reasons;
  }
}
