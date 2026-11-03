import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/features/recommendations/repository/recommendation_mapper.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';
import 'package:royal_airlines/services/recommendation_service.dart';

void main() {
  group('RecommendationMapper', () {
    const preferences = TravelerPreferencesModel(
      interests: [TravelInterest.playa],
      budgetMin: 0,
      budgetMax: 6000000,
      preferredMonths: [1, 2],
    );

    test('item del catálogo usa el perfil curado y conserva el id real', () {
      final item = RecommendationListItem.fromJson(const {
        'locationID': '65f3abc123',
        'iataCode': 'MAD',
        'cityName': 'Madrid',
        'score': 0.87,
        'components': {
          'affinity': 0.9,
          'budget': 0.4,
          'season': 0.7,
          'fit': 0.55,
        },
        'matchedTags': ['Cultura'],
        'reasons': ['TAG_MATCH', 'IN_SEASON'],
      });

      final result = RecommendationMapper.map(item, preferences: preferences);

      expect(result, isNotNull);
      expect(result!.destination.city, 'Madrid');
      expect(result.destination.country, 'España');
      expect(result.locationId, '65f3abc123');
      expect(result.affinity, 0.87);
      expect(result.interestScore, 0.9);
      expect(result.budgetScore, 0.4);
      expect(result.seasonalityScore, 0.7);
      expect(result.historyScore, 0.55);
      expect(
        result.reasons,
        ['Combina con tus intereses', 'Es temporada ideal'],
      );
      expect(result.userRadarValues, hasLength(TravelInterest.values.length));
      expect(
        result.destinationRadarValues,
        hasLength(TravelInterest.values.length),
      );
    });

    test('destino fuera del catálogo arma perfil sintético con las etiquetas',
        () {
      final item = RecommendationListItem.fromJson(const {
        'locationID': 'lim-1',
        'iataCode': 'LIM',
        'cityName': 'Lima',
        'score': 1.4,
        'matchedTags': ['Playa', 'Nieve'],
        'reasons': <String>[],
      });

      final result = RecommendationMapper.map(item, preferences: preferences);

      expect(result, isNotNull);
      expect(result!.destination.code, 'LIM');
      expect(result.destination.city, 'Lima');
      // El score del backend se recorta al rango 0-1.
      expect(result.affinity, 1.0);
      // "Nieve" matchea el interés "Nieve y auroras".
      expect(result.destination.weightFor(TravelInterest.playa), 0.7);
      expect(result.destination.weightFor(TravelInterest.nieve), 0.7);
      // Sin códigos de razón, las etiquetas dan una razón genérica.
      expect(result.reasons, ['Combina con tus intereses']);
    });

    test('sin códigos de razón conocidos se humanizan', () {
      final item = RecommendationListItem.fromJson(const {
        'iataCode': 'MAD',
        'cityName': 'Madrid',
        'score': 0.5,
        'reasons': ['NEW_CODE'],
      });

      final result = RecommendationMapper.map(item, preferences: preferences);
      expect(result!.reasons, ['New code']);
    });

    test('componentes ausentes quedan neutrales (0.5)', () {
      final item = RecommendationListItem.fromJson(const {
        'iataCode': 'MAD',
        'cityName': 'Madrid',
        'score': 0.5,
      });

      final result = RecommendationMapper.map(item, preferences: preferences);
      expect(result!.interestScore, 0.5);
      expect(result.budgetScore, 0.5);
      expect(result.seasonalityScore, 0.5);
      expect(result.historyScore, 0.5);
    });

    test('item sin IATA ni ciudad no produce resultado', () {
      final item = RecommendationListItem.fromJson(const {
        'locationID': 'sin-identidad',
        'score': 0.5,
      });

      expect(RecommendationMapper.map(item, preferences: preferences), isNull);
    });
  });
}
