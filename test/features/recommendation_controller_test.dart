import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/features/recommendations/controller/recommendation_controller.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';
import 'package:royal_airlines/services/recommendation_service.dart';

void main() {
  group('RecommendationController', () {
    test('sin preferencias → estado empty', () {
      final controller = RecommendationController();
      controller.rebuild(preferences: TravelerPreferencesModel.empty());

      expect(controller.status, RecommendationStatus.empty);
      expect(controller.recommendations, isEmpty);
      controller.dispose();
    });

    test('con preferencias → ranking con hasta N recomendaciones', () {
      final controller = RecommendationController(maxRecommendations: 3);
      controller.rebuild(
        preferences: const TravelerPreferencesModel(
          interests: [TravelInterest.playa],
          budgetMin: 200000,
          budgetMax: 6000000,
          preferredMonths: [1, 2, 12],
        ),
        visitedCities: ['Cartagena'],
      );

      expect(controller.status, RecommendationStatus.success);
      expect(controller.recommendations.length, 3);
      controller.dispose();
    });

    test('recalcula al volver a llamar rebuild', () {
      final controller = RecommendationController(maxRecommendations: 2);
      controller.rebuild(preferences: TravelerPreferencesModel.empty());
      expect(controller.status, RecommendationStatus.empty);

      controller.rebuild(
        preferences: const TravelerPreferencesModel(
          interests: [TravelInterest.cultura],
          budgetMin: 0,
          budgetMax: 10000000,
          preferredMonths: [5],
        ),
      );
      expect(controller.status, RecommendationStatus.success);
      expect(controller.recommendations.length, 2);
      controller.dispose();
    });

    test('notifica a los listeners en cada rebuild', () {
      final controller = RecommendationController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.rebuild(
        preferences: const TravelerPreferencesModel(
          interests: [TravelInterest.aventura],
          budgetMin: 0,
          budgetMax: 3000000,
        ),
      );
      expect(notifications, 1);
      controller.dispose();
    });
  });

  group('RecommendationController - lista del backend', () {
    const preferences = TravelerPreferencesModel(
      interests: [TravelInterest.playa],
      budgetMin: 0,
      budgetMax: 6000000,
      preferredMonths: [1, 2],
    );

    RecommendationList buildList() => RecommendationList(
          strategy: 'preferences',
          modelVersion: 'v3',
          recommendationID: 'list-42',
          generatedAt: DateTime(2026, 10, 28, 3, 30),
          items: [
            for (final entry in const [
              ('65f3-mad', 'MAD', 'Madrid'),
              ('65f3-ctg', 'CTG', 'Cartagena'),
              ('65f3-vce', 'VCE', 'Venecia'),
            ])
              RecommendationListItem.fromJson({
                'locationID': entry.$1,
                'iataCode': entry.$2,
                'cityName': entry.$3,
                'score': 0.8,
                'components': {'affinity': 0.9},
                'reasons': ['TAG_MATCH'],
              }),
          ],
        );

    test('loadRemote con lista del backend la mapea y expone el id', () async {
      final controller = RecommendationController(
        maxRecommendations: 2,
        service: _FakeRecommendationService(list: buildList()),
      );

      await controller.loadRemote(preferences: preferences);

      expect(controller.status, RecommendationStatus.success);
      expect(controller.recommendations, hasLength(2));
      expect(controller.recommendationId, 'list-42');
      expect(controller.strategy, 'preferences');
      expect(controller.isLoading, isFalse);
      // El id real del destino viaja en cada resultado (favoritos y
      // eventos lo usan).
      expect(controller.recommendations.first.locationId, '65f3-mad');
      controller.dispose();
    });

    test('loadRemote sin servicio cae al motor local', () async {
      final controller = RecommendationController(maxRecommendations: 3);

      await controller.loadRemote(preferences: preferences);

      expect(controller.status, RecommendationStatus.success);
      expect(controller.recommendations, hasLength(3));
      expect(controller.recommendationId, isNull);
      expect(controller.strategy, isNull);
      controller.dispose();
    });

    test('loadRemote con error de red cae al motor local sin romperse',
        () async {
      final controller = RecommendationController(
        maxRecommendations: 3,
        service: _FakeRecommendationService(
          error: Exception('sin conexión'),
        ),
      );

      await controller.loadRemote(preferences: preferences);

      expect(controller.status, RecommendationStatus.success);
      expect(controller.recommendations, isNotEmpty);
      expect(controller.recommendationId, isNull);
      expect(controller.isLoading, isFalse);
      controller.dispose();
    });

    test('loadRemote con lista vacía cae al motor local', () async {
      final controller = RecommendationController(
        maxRecommendations: 3,
        service: _FakeRecommendationService(
          list: const RecommendationList(
            strategy: 'fallback',
            modelVersion: 'fallback-v1',
            recommendationID: 'list-vacia',
            generatedAt: null,
            items: [],
          ),
        ),
      );

      await controller.loadRemote(preferences: preferences);

      expect(controller.status, RecommendationStatus.success);
      expect(controller.recommendations, isNotEmpty);
      expect(controller.recommendationId, isNull);
      controller.dispose();
    });
  });
}

/// Servicio falso para testear el camino remoto sin red.
class _FakeRecommendationService extends RecommendationService {
  _FakeRecommendationService({this.list, this.error});

  final RecommendationList? list;
  final Object? error;

  @override
  Future<RecommendationList> fetch() async {
    final failure = error;
    if (failure != null) throw failure;
    return list!;
  }
}
