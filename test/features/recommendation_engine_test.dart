import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/features/recommendations/data/destination_catalog.dart';
import 'package:royal_airlines/features/recommendations/repository/recommendation_engine.dart';
import 'package:royal_airlines/models/destination_profile.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';

void main() {
  const engine = RecommendationEngine();

  // Perfil playa + presupuesto holgado, disponible todo el año.
  const beachLover = TravelerPreferencesModel(
    interests: [TravelInterest.playa, TravelInterest.gastronomia],
    budgetMin: 200000,
    budgetMax: 5000000,
    preferredMonths: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  );

  // Perfil nieve/auroras con presupuesto muy ajustado.
  const snowLover = TravelerPreferencesModel(
    interests: [TravelInterest.nieve],
    budgetMin: 0,
    budgetMax: 1000000,
    preferredMonths: [12, 1, 2],
  );

  group('DestinationCatalog', () {
    test('byCode encuentra destinos del catálogo', () {
      expect(DestinationCatalog.byCode('CTG'), isNotNull);
      expect(DestinationCatalog.byCode('OSL'), isNotNull);
      expect(DestinationCatalog.byCode('XXX'), isNull);
    });

    test('byCity es tolerante a mayúsculas y acentos', () {
      expect(DestinationCatalog.byCity('cartagena')?.code, 'CTG');
      expect(DestinationCatalog.byCity('Marruecos'), isNull); // es país
      expect(DestinationCatalog.byCity('Marrakech')?.code, 'RAK');
      expect(DestinationCatalog.byCity('san andrés'), isNull);
    });
  });

  group('RecommendationEngine.interestScore', () {
    test('destino que matchea los intereses gana contra uno que no', () {
      // En julio (invierno caribeño): CTG es playa pura.
      final results = engine.recommend(
        preferences: beachLover,
        now: DateTime(2026, 7),
      );

      final cartagena = results.firstWhere((r) => r.destination.code == 'CTG');
      final oslo = results.firstWhere((r) => r.destination.code == 'OSL');

      expect(cartagena.interestScore, greaterThan(oslo.interestScore));
      expect(cartagena.affinity, greaterThan(oslo.affinity));
    });

    test('ranking ordena de mayor a menor afinidad', () {
      final results = engine.recommend(
        preferences: beachLover,
        now: DateTime(2026, 7),
      );
      for (var i = 0; i < results.length - 1; i++) {
        expect(
            results[i].affinity, greaterThanOrEqualTo(results[i + 1].affinity));
      }
    });
  });

  group('RecommendationEngine.budgetScore', () {
    test('destino dentro del presupuesto recibe 1.0', () {
      final result = engine.evaluate(
        destination: DestinationCatalog.byCode('CTG')!,
        preferences: beachLover,
        currentMonth: 7,
      );
      expect(result.budgetScore, 1.0);
    });

    test('destino 50% sobre el presupuesto queda en 0', () {
      const poorPrefs = TravelerPreferencesModel(
        interests: [TravelInterest.playa],
        budgetMin: 0,
        budgetMax: 2000000,
        preferredMonths: [],
      );
      // OSL cuesta 7.1M ≈ 255% sobre 2M → score 0.
      final result = engine.evaluate(
        destination: DestinationCatalog.byCode('OSL')!,
        preferences: poorPrefs,
        currentMonth: 1,
      );
      expect(result.budgetScore, 0.0);
      expect(result.affinity, lessThan(0.5));
    });

    test('viajar barato no se penaliza (precio bajo el mínimo)', () {
      final result = engine.evaluate(
        destination: DestinationCatalog.byCode('BOG')!,
        preferences: beachLover,
        currentMonth: 7,
      );
      expect(result.budgetScore, 1.0);
    });
  });

  group('RecommendationEngine.seasonalityScore', () {
    const winterOnly = TravelerPreferencesModel(
      interests: [TravelInterest.nieve],
      budgetMin: 0,
      budgetMax: 8000000,
      preferredMonths: [12, 1, 2],
    );

    test('mes actual ideal + disponible = 1.0', () {
      final result = engine.evaluate(
        destination: DestinationCatalog.byCode('OSL')!, // mejores meses: 11-3
        preferences: winterOnly,
        currentMonth: 1,
      );
      expect(result.seasonalityScore, 1.0);
    });

    test('sin traslape entre meses ideales y disponibles = casi 0', () {
      const julyOnly = TravelerPreferencesModel(
        interests: [TravelInterest.nieve],
        budgetMin: 0,
        budgetMax: 8000000,
        preferredMonths: [7],
      );
      final result = engine.evaluate(
        destination: DestinationCatalog.byCode('OSL')!, // no brilla en julio
        preferences: julyOnly,
        currentMonth: 7,
      );
      expect(result.seasonalityScore, lessThan(0.2));
    });

    test('traslape parcial queda entre 0.5 y 0.9', () {
      const prefs = TravelerPreferencesModel(
        interests: [TravelInterest.nieve],
        budgetMin: 0,
        budgetMax: 8000000,
        preferredMonths: [1, 7], // 1 de 5 meses ideales de OSL
      );
      final result = engine.evaluate(
        destination: DestinationCatalog.byCode('OSL')!,
        preferences: prefs,
        currentMonth: 7,
      );
      expect(result.seasonalityScore, greaterThan(0.5));
      expect(result.seasonalityScore, lessThan(0.9));
    });
  });

  group('RecommendationEngine.favorableExperienceProbability', () {
    test('es coherente con la afinidad y queda en [0,1]', () {
      final results = engine.recommend(
        preferences: beachLover,
        now: DateTime(2026, 7),
      );
      for (final result in results) {
        expect(result.favorableExperienceProbability, inInclusiveRange(0, 1));
        // Nunca supera la afinidad (la probabilidad se "descuenta"
        // por la solidez del perfil, no se infla).
        expect(
          result.favorableExperienceProbability,
          lessThanOrEqualTo(result.affinity + 0.0001),
        );
      }
    });

    test('perfil completo + historial da más probabilidad que perfil vacío',
        () {
      final withHistory = engine.evaluate(
        destination: DestinationCatalog.byCode('CTG')!,
        preferences: beachLover,
        visitedCities: ['Madrid', 'Bogotá'],
        currentMonth: 1,
      );
      final withoutHistory = engine.evaluate(
        destination: DestinationCatalog.byCode('CTG')!,
        preferences: beachLover,
        currentMonth: 1,
      );
      expect(
        withHistory.favorableExperienceProbability,
        greaterThan(withoutHistory.favorableExperienceProbability),
      );
    });
  });

  group('RecommendationEngine.historyScore', () {
    test('historial de playa empuja hacia más playa, no hacia nieve', () {
      final beachHistory = ['Cartagena', 'Miami'];
      final ctg = engine.evaluate(
        destination: DestinationCatalog.byCode('CTG')!,
        preferences: beachLover,
        visitedCities: beachHistory,
        currentMonth: 1,
      );
      final osloFromBeach = engine.evaluate(
        destination: DestinationCatalog.byCode('OSL')!,
        preferences: beachLover,
        visitedCities: beachHistory,
        currentMonth: 1,
      );
      expect(ctg.historyScore, greaterThan(osloFromBeach.historyScore));
    });

    test('sin historial el componente es neutral (0.5)', () {
      final result = engine.evaluate(
        destination: DestinationCatalog.byCode('MAD')!,
        preferences: beachLover,
        currentMonth: 7,
      );
      expect(result.historyScore, 0.5);
    });
  });

  group('RecommendationEngine.radar', () {
    test('los ejes siguen el orden de TravelInterest.values', () {
      final result = engine.evaluate(
        destination: DestinationCatalog.byCode('OSL')!,
        preferences: snowLover,
        currentMonth: 1,
      );
      expect(result.userRadarValues.length, TravelInterest.values.length);
      expect(
          result.destinationRadarValues.length, TravelInterest.values.length);

      // "nieve" está en el índice correcto (TravelInterest.nieve.index).
      final nieveIndex = TravelInterest.nieve.index;
      expect(result.userRadarValues[nieveIndex], 1.0);
      expect(
        result.destinationRadarValues[nieveIndex],
        DestinationCatalog.byCode('OSL')!.weightFor(TravelInterest.nieve),
      );
    });
  });

  group('RecommendationEngine.reasons', () {
    test('destino caro dentro de presupuesto lo menciona', () {
      final madResult = engine.evaluate(
        destination: DestinationCatalog.byCode('MAD')!,
        preferences: beachLover, // presupuesto hasta 5M, Madrid 4.2M
        currentMonth: 5,
      );
      expect(
        madResult.reasons.any((r) => r.contains('presupuesto')),
        isTrue,
      );
    });

    test('destino aspiracional agrega la nota de ruta próxima', () {
      final veniceResult = engine.evaluate(
        destination: DestinationCatalog.byCode('VCE')!,
        preferences: const TravelerPreferencesModel(
          interests: [TravelInterest.cultura],
          budgetMin: 0,
          budgetMax: 8000000,
          preferredMonths: [4],
        ),
        currentMonth: 4,
      );
      expect(
        veniceResult.reasons.any((r) => r.contains('próximamente')),
        isTrue,
      );
    });
  });

  group('RecommendationEngine.evaluate - datos del destino', () {
    test('los scores individuales quedan en [0,1]', () {
      final result = engine.evaluate(
        destination: const DestinationProfile(
          code: 'TEST',
          city: 'Test',
          country: 'Testland',
          interestWeights: {TravelInterest.aventura: 0.8},
          bestMonths: [6],
          averagePriceCop: 100000,
        ),
        preferences: beachLover,
        currentMonth: 6,
      );
      expect(result.interestScore, inInclusiveRange(0, 1));
      expect(result.budgetScore, inInclusiveRange(0, 1));
      expect(result.seasonalityScore, inInclusiveRange(0, 1));
      expect(result.historyScore, inInclusiveRange(0, 1));
      expect(result.affinity, inInclusiveRange(0, 1));
    });
  });
}
