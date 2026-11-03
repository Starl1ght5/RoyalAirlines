import 'package:royal_airlines/features/recommendations/data/destination_catalog.dart';
import 'package:royal_airlines/features/recommendations/repository/recommendation_engine.dart';
import 'package:royal_airlines/models/destination_profile.dart';
import 'package:royal_airlines/models/recommendation_model.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';
import 'package:royal_airlines/services/recommendation_service.dart';

/// RecommendationMapper
/// --------------------
/// Traduce un item de `GET /recommendations` (recomendador Python) al
/// [RecommendationResult] que ya consume la UI (tarjeta, sheet y
/// radar), de modo que la pantalla "Recomendado para ti" funciona IGUAL
/// venga del motor local o del backend.
///
/// Decisiones de mapeo:
/// - **Perfil**: primero el catálogo curado por IATA (trae país, pesos,
///   meses y precio); si no, por ciudad; y si tampoco, un perfil
///   sintético con las `matchedTags` como pesos de interés.
/// - **Sub-scores**: `affinity` → interés, `budget` → presupuesto,
///   `season` → estacionalidad y `fit` → historial (el más cercano al
///   "repite categorías ya visitadas" del motor local). Faltantes →
///   neutral 0.5, igual que el motor sin dato.
/// - **Razones**: códigos cortos del backend (`POPULAR`, `TAG_MATCH`…)
///   traducidos a frases en español listas para los chips.
/// - **Afinidad**: el `score` del backend manda; la probabilidad
///   favorable se deriva con la MISMA fórmula confianza del motor
///   local ([RecommendationEngine.favorableProbabilityFor]).
class RecommendationMapper {
  RecommendationMapper._();

  /// Peso que recibe un destino cuya etiqueta (`matchedTags`) coincide
  /// con un interés del usuario: suficiente para quedar en
  /// `prominentInterests` (>= 0.4) y aparecer como chip en la tarjeta.
  static const double _matchedTagWeight = 0.7;

  /// Devuelve `null` cuando el item no trae ni IATA ni ciudad: sin
  /// identidad no hay tarjeta que armar, y el controller lo descarta.
  static RecommendationResult? map(
    RecommendationListItem item, {
    required TravelerPreferencesModel preferences,
    List<String> visitedCities = const [],
  }) {
    final destination = _profileFor(item);
    if (destination == null) return null;

    const engine = RecommendationEngine();
    final affinity = _unit(item.score);

    return RecommendationResult(
      destination: destination,
      affinity: affinity,
      interestScore: _component(item, 'affinity'),
      budgetScore: _component(item, 'budget'),
      seasonalityScore: _component(item, 'season'),
      historyScore: _component(item, 'fit'),
      favorableExperienceProbability: engine
          .favorableProbabilityFor(
            affinity: affinity,
            preferences: preferences,
            hasHistory: visitedCities.isNotEmpty,
          )
          .clamp(0.0, 1.0),
      reasons: _reasons(item),
      locationId: item.locationID.isEmpty ? null : item.locationID.trim(),
      userRadarValues: engine.userRadarValues(preferences),
      destinationRadarValues: engine.destinationRadarValues(destination),
    );
  }

  // ---------------------------------------------------------------------
  // Perfil del destino
  // ---------------------------------------------------------------------

  static DestinationProfile? _profileFor(RecommendationListItem item) {
    final code = item.iataCode.trim();
    final city = item.cityName.trim();

    final byCode = code.isEmpty ? null : DestinationCatalog.byCode(code);
    if (byCode != null) return byCode;

    final byCity = city.isEmpty ? null : DestinationCatalog.byCity(city);
    if (byCity != null) return byCity;

    if (code.isEmpty && city.isEmpty) return null;

    // Destino fuera del catálogo curado (el backend lista todas las
    // `Location`): perfil sintético con lo que el DTO sí trae. País y
    // precio quedan vacíos/0 — la UI oculta esas filas cuando no hay
    // dato en vez de mostrar "COP 0".
    return DestinationProfile(
      code: code.isEmpty ? city : code,
      city: city.isEmpty ? code : city,
      country: '',
      interestWeights: _weightsFromTags(item.matchedTags),
      bestMonths: const [],
      averagePriceCop: 0,
    );
  }

  /// Las `matchedTags` del backend son etiquetas en español ("Playa",
  /// "Gastronomía", "Nieve"): se traducen a [TravelInterest] para que
  /// el radar y los chips del destino funcionen igual que con el
  /// catálogo curado.
  static Map<TravelInterest, double> _weightsFromTags(List<String> tags) {
    final weights = <TravelInterest, double>{};
    for (final tag in tags) {
      final interest = _interestForTag(tag);
      if (interest != null) weights[interest] = _matchedTagWeight;
    }
    return weights;
  }

  static TravelInterest? _interestForTag(String tag) {
    final normalized = _normalize(tag);
    if (normalized.isEmpty) return null;

    for (final interest in TravelInterest.values) {
      if (_normalize(interest.label) == normalized ||
          interest.name == normalized) {
        return interest;
      }
    }
    // Etiquetas más cortas que la del interés ("nieve" → "Nieve y
    // auroras"): match por prefijo.
    for (final interest in TravelInterest.values) {
      if (_normalize(interest.label).startsWith(normalized)) {
        return interest;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Sub-scores y razones
  // ---------------------------------------------------------------------

  /// Componente del desglose del backend; 0.5 (neutral) si el item no
  /// lo trae — igual que el motor local cuando no hay dato.
  static double _component(RecommendationListItem item, String key) {
    final value = item.components[key];
    return value == null ? 0.5 : _unit(value);
  }

  static double _unit(num value) => value.clamp(0.0, 1.0).toDouble();

  /// Códigos de razón del recomendador Python (y del respaldo Java)
  /// traducidos a las frases en español que la UI muestra como chips.
  static const Map<String, String> _reasonLabels = {
    'POPULAR': 'Destino popular entre viajeros',
    'TAG_MATCH': 'Combina con tus intereses',
    'IN_SEASON': 'Es temporada ideal',
    'COMPANION_FIT': 'Encaja con tu compañía de viaje',
    'PRICE_FITS': 'Encaja en tu presupuesto',
    'OFFER': 'Oferta vigente',
    'FEATURED': 'Destino destacado',
  };

  static List<String> _reasons(RecommendationListItem item) {
    final reasons = <String>[];
    for (final raw in item.reasons) {
      final code = raw.trim().toUpperCase();
      if (code.isEmpty) continue;
      final label = _reasonLabels[code] ?? _humanize(code);
      if (!reasons.contains(label)) reasons.add(label);
    }

    // Sin códigos de razón pero con etiquetas coincidentes (pasaría si
    // el backend simplifica la respuesta): al menos una razón genérica.
    if (reasons.isEmpty && item.matchedTags.isNotEmpty) {
      reasons.add('Combina con tus intereses');
    }
    return reasons;
  }

  /// Código desconocido → texto legible ("NEW_CODE" → "New code").
  static String _humanize(String code) {
    final lowered = code.toLowerCase().replaceAll('_', ' ');
    if (lowered.isEmpty) return code;
    return '${lowered[0].toUpperCase()}${lowered.substring(1)}';
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .trim();
  }
}
