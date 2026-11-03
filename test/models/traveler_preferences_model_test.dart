import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/models/travel_class.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';

/// Pruebas del [TravelerPreferencesModel]: serialización, tolerancia a
/// datos corruptos, validaciones (datos INVÁLIDOS vs INCOMPLETOS) y
/// cálculo del porcentaje de completitud.
void main() {
  group('TravelerPreferencesModel - valores por defecto', () {
    test('empty no tiene preferencias y está al 0% de completitud', () {
      final prefs = TravelerPreferencesModel.empty();

      expect(prefs.hasPreferences, isFalse);
      expect(prefs.completionPercentage, 0);
      expect(prefs.interests, isEmpty);
      expect(prefs.preferredMonths, isEmpty);
      expect(prefs.style, isNull);
      expect(prefs.preferredClass, isNull);
    });
  });

  group('TravelerPreferencesModel - serialización', () {
    test('toJson/fromJson conserva todos los campos', () {
      const original = TravelerPreferencesModel(
        interests: [TravelInterest.naturaleza, TravelInterest.cultura],
        budgetMin: 800000,
        budgetMax: 2500000,
        preferredMonths: [6, 7, 12],
        style: TravelStyle.equilibrado,
        preferredClass: TravelClass.business,
      );

      final restored = TravelerPreferencesModel.fromJson(original.toJson());

      expect(restored.interests, original.interests);
      expect(restored.budgetMin, original.budgetMin);
      expect(restored.budgetMax, original.budgetMax);
      expect(restored.preferredMonths, original.preferredMonths);
      expect(restored.style, original.style);
      expect(restored.preferredClass, original.preferredClass);
    });

    test('fromJson tolera un mapa vacío sin lanzar', () {
      final prefs = TravelerPreferencesModel.fromJson(const {});

      expect(prefs.hasPreferences, isFalse);
      expect(prefs.validationError, isNotNull);
    });

    test('fromJson descarta intereses desconocidos y meses fuera de rango', () {
      final prefs = TravelerPreferencesModel.fromJson(const {
        'interests': ['naturaleza', 'inventado', 'playa'],
        'preferredMonths': [0, 6, 13, '7', 6],
        'budgetMin': 100,
        'budgetMax': 200,
        'style': 'no-existe',
        'preferredClass': 'clave-desconocida',
      });

      expect(
          prefs.interests, [TravelInterest.naturaleza, TravelInterest.playa]);
      expect(prefs.preferredMonths, [6, 7]);
      expect(prefs.style, isNull);
      expect(prefs.preferredClass, isNull);
    });

    test('fromJson con tipos numéricos inválidos usa 0 y no lanza', () {
      final prefs = TravelerPreferencesModel.fromJson(const {
        'budgetMin': 'no-numero',
        'budgetMax': null,
      });

      expect(prefs.budgetMin, 0);
      expect(prefs.budgetMax, 0);
    });
  });

  group('TravelerPreferencesModel - validación (datos inválidos)', () {
    test('sin intereses el modelo es inválido', () {
      const prefs = TravelerPreferencesModel(
        budgetMin: 100000,
        budgetMax: 500000,
        preferredMonths: [3],
      );

      expect(prefs.validationError, 'Selecciona al menos un tipo de viaje.');
    });

    test('presupuesto mínimo negativo es inválido', () {
      const prefs = TravelerPreferencesModel(
        interests: [TravelInterest.playa],
        budgetMin: -1,
        budgetMax: 500000,
      );

      expect(prefs.validationError,
          'El presupuesto mínimo no puede ser negativo.');
    });

    test('sin presupuesto máximo es inválido', () {
      const prefs = TravelerPreferencesModel(
        interests: [TravelInterest.playa],
        budgetMin: 0,
        budgetMax: 0,
      );

      expect(prefs.validationError, 'Indica tu presupuesto máximo por viaje.');
    });

    test('máximo menor que mínimo es inválido', () {
      const prefs = TravelerPreferencesModel(
        interests: [TravelInterest.playa],
        budgetMin: 900000,
        budgetMax: 100000,
      );

      expect(
        prefs.validationError,
        'El presupuesto máximo debe ser mayor o igual al mínimo.',
      );
    });

    test('un modelo válido no devuelve error', () {
      const prefs = TravelerPreferencesModel(
        interests: [TravelInterest.aventura],
        budgetMin: 0,
        budgetMax: 1500000,
        preferredMonths: [1, 12],
      );

      expect(prefs.validationError, isNull);
    });
  });

  group('TravelerPreferencesModel - completitud', () {
    test('completitud cuenta solo intereses, presupuesto y meses', () {
      const onlyInterests = TravelerPreferencesModel(
        interests: [TravelInterest.playa],
      );
      expect(onlyInterests.completionPercentage, 33);

      const interestsAndBudget = TravelerPreferencesModel(
        interests: [TravelInterest.playa],
        budgetMax: 2000000,
      );
      expect(interestsAndBudget.completionPercentage, 67);

      const full = TravelerPreferencesModel(
        interests: [TravelInterest.playa],
        budgetMax: 2000000,
        preferredMonths: [5],
      );
      expect(full.completionPercentage, 100);
    });

    test('estilo y clase opcionales NO alteran la completitud', () {
      const base = TravelerPreferencesModel(
        interests: [TravelInterest.playa],
        budgetMax: 2000000,
        preferredMonths: [5],
      );
      final withOptionals = base.copyWith(
        style: TravelStyle.premium,
        preferredClass: TravelClass.business,
      );

      expect(withOptionals.completionPercentage, base.completionPercentage);
    });
  });

  group('TravelerPreferencesModel - incompleto vs inválido', () {
    test('faltan meses/estilo/clase: válido pero con sugerencias', () {
      const prefs = TravelerPreferencesModel(
        interests: [TravelInterest.naturaleza],
        budgetMax: 3000000,
      );

      expect(prefs.validationError, isNull);
      expect(prefs.missingRecommendedInfo, hasLength(3));
      expect(prefs.hasPreferences, isTrue);
    });

    test('modelo completo no tiene sugerencias pendientes', () {
      const prefs = TravelerPreferencesModel(
        interests: [TravelInterest.naturaleza],
        budgetMax: 3000000,
        preferredMonths: [8],
        style: TravelStyle.comodo,
        preferredClass: TravelClass.premiumEconomy,
      );

      expect(prefs.missingRecommendedInfo, isEmpty);
    });
  });

  group('TravelerPreferencesModel - sameAs (igualdad profunda)', () {
    const base = TravelerPreferencesModel(
      interests: [TravelInterest.naturaleza, TravelInterest.playa],
      budgetMin: 500000,
      budgetMax: 2000000,
      preferredMonths: [1, 6],
      style: TravelStyle.equilibrado,
      preferredClass: TravelClass.economy,
    );

    test('el mismo contenido con otro ORDEN de listas es el mismo perfil', () {
      // El orden en que el usuario marcó intereses o meses no es un
      // cambio: guardar así NO debe disparar el PUT ni el refresh de
      // recomendaciones.
      const reordered = TravelerPreferencesModel(
        interests: [TravelInterest.playa, TravelInterest.naturaleza],
        budgetMin: 500000,
        budgetMax: 2000000,
        preferredMonths: [6, 1],
        style: TravelStyle.equilibrado,
        preferredClass: TravelClass.economy,
      );

      expect(base.sameAs(reordered), isTrue);
    });

    test('una lista con repetidos sigue siendo el mismo conjunto', () {
      const duplicated = TravelerPreferencesModel(
        interests: [
          TravelInterest.naturaleza,
          TravelInterest.playa,
          TravelInterest.naturaleza,
        ],
        budgetMin: 500000,
        budgetMax: 2000000,
        preferredMonths: [1, 6],
        style: TravelStyle.equilibrado,
        preferredClass: TravelClass.economy,
      );

      expect(base.sameAs(duplicated), isTrue);
    });

    test('cualquier campo distinto rompe la igualdad', () {
      TravelerPreferencesModel withBudgetMin(double v) =>
          TravelerPreferencesModel(
            interests: base.interests,
            budgetMin: v,
            budgetMax: base.budgetMax,
            preferredMonths: base.preferredMonths,
            style: base.style,
            preferredClass: base.preferredClass,
          );

      expect(base.sameAs(withBudgetMin(900000)), isFalse);
      expect(
        base.sameAs(const TravelerPreferencesModel(
          interests: [TravelInterest.naturaleza],
          budgetMin: 500000,
          budgetMax: 2000000,
          preferredMonths: [1, 6],
          style: TravelStyle.equilibrado,
          preferredClass: TravelClass.economy,
        )),
        isFalse,
      );
      expect(
        base.sameAs(const TravelerPreferencesModel(
          interests: [TravelInterest.naturaleza, TravelInterest.playa],
          budgetMin: 500000,
          budgetMax: 2000000,
          preferredMonths: [1, 7],
          style: TravelStyle.equilibrado,
          preferredClass: TravelClass.economy,
        )),
        isFalse,
      );
    });

    test('campo opcional lleno vs vacío NO es el mismo perfil', () {
      const sinExcluidos = TravelerPreferencesModel(
        interests: [TravelInterest.naturaleza],
        budgetMax: 1000000,
      );
      const conExcluidos = TravelerPreferencesModel(
        interests: [TravelInterest.naturaleza],
        budgetMax: 1000000,
        excludedLocationIds: ['CTG'],
      );

      expect(sinExcluidos.sameAs(conExcluidos), isFalse);
    });

    test('dos modelos vacíos sí son equivalentes', () {
      expect(
        TravelerPreferencesModel.empty()
            .sameAs(TravelerPreferencesModel.empty()),
        isTrue,
      );
    });
  });
}
