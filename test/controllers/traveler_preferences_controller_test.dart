import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/features/traveler_profile/controller/traveler_preferences_controller.dart';
import 'package:royal_airlines/features/traveler_profile/repository/traveler_preferences_storage.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';
import 'package:royal_airlines/services/traveler_preferences_remote_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pruebas de [TravelerPreferencesController] y [TravelerPreferencesStorage]
/// en modo local (SharedPreferences en memoria), validando persistencia
/// por usuario, aislamiento entre cuentas y tolerancia a datos corruptos.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Cada test arranca con preferencias vacías en disco.
    SharedPreferences.setMockInitialValues({});
  });

  TravelerPreferencesModel validPreferences() => const TravelerPreferencesModel(
        interests: [TravelInterest.naturaleza, TravelInterest.cultura],
        budgetMin: 800000,
        budgetMax: 2500000,
        preferredMonths: [6, 7],
        style: TravelStyle.equilibrado,
      );

  group('TravelerPreferencesController - carga inicial', () {
    test('un usuario sin datos guardados arranca vacío', () async {
      final controller = TravelerPreferencesController(userId: 'usr_001');
      await Future.delayed(Duration.zero);

      expect(controller.isActive, isTrue);
      expect(controller.hasPreferences, isFalse);
      expect(controller.completionPercentage, 0);
      expect(controller.status, TravelerPreferencesStatus.success);
    });

    test('sin userId el controller queda inactivo (invitado)', () {
      final controller = TravelerPreferencesController(userId: '');

      expect(controller.isActive, isFalse);
      expect(controller.hasPreferences, isFalse);
    });
  });

  group('TravelerPreferencesController - guardado', () {
    test('guardar preferencias válidas las persiste y las expone', () async {
      final controller = TravelerPreferencesController(userId: 'usr_001');
      await Future.delayed(Duration.zero);

      final saved = await controller.save(validPreferences());

      expect(saved, isTrue);
      expect(controller.status, TravelerPreferencesStatus.success);
      expect(controller.hasPreferences, isTrue);
      expect(controller.preferences.interests,
          containsAll([TravelInterest.naturaleza, TravelInterest.cultura]));
    });

    test('guardar un modelo inválido NO persiste ni limpia el error', () async {
      final controller = TravelerPreferencesController(userId: 'usr_001');
      await Future.delayed(Duration.zero);

      const invalid = TravelerPreferencesModel(
        interests: [],
        budgetMin: 0,
        budgetMax: 100000,
      );
      final saved = await controller.save(invalid);

      expect(saved, isFalse);
      expect(controller.status, TravelerPreferencesStatus.error);
      expect(controller.errorMessage, isNotNull);
      expect(controller.hasPreferences, isFalse);

      // Nada inválido llegó al disco.
      final reloaded = await TravelerPreferencesStorage().load('usr_001');
      expect(reloaded.hasPreferences, isFalse);
    });

    test('guardar con presupuesto invertido es rechazado', () async {
      final controller = TravelerPreferencesController(userId: 'usr_001');
      await Future.delayed(Duration.zero);

      const inverted = TravelerPreferencesModel(
        interests: [TravelInterest.playa],
        budgetMin: 900000,
        budgetMax: 100000,
      );
      final saved = await controller.save(inverted);

      expect(saved, isFalse);
      expect(controller.errorMessage,
          'El presupuesto máximo debe ser mayor o igual al mínimo.');
    });
  });

  group('TravelerPreferencesController - persistencia por usuario', () {
    test('un controller nuevo recarga lo guardado por el anterior', () async {
      final first = TravelerPreferencesController(userId: 'usr_001');
      await Future.delayed(Duration.zero);
      await first.save(validPreferences());

      // Simula reabrir la app.
      final restored = TravelerPreferencesController(userId: 'usr_001');
      await Future.delayed(Duration.zero);

      expect(restored.hasPreferences, isTrue);
      expect(restored.preferences.budgetMax, 2500000);
      expect(restored.preferences.preferredMonths, [6, 7]);
    });

    test('las preferencias de una cuenta no se ven en otra', () async {
      final accountA = TravelerPreferencesController(userId: 'usr_A');
      await Future.delayed(Duration.zero);
      await accountA.save(validPreferences());

      final accountB = TravelerPreferencesController(userId: 'usr_B');
      await Future.delayed(Duration.zero);

      expect(accountA.hasPreferences, isTrue);
      expect(accountB.hasPreferences, isFalse);
      expect(accountB.preferences.interests, isEmpty);
    });

    test('el storage lee solo la clave del usuario solicitado', () async {
      final storage = TravelerPreferencesStorage();
      await storage.save('usr_A', validPreferences());

      final fromA = await storage.load('usr_A');
      final fromB = await storage.load('usr_B');

      expect(fromA.hasPreferences, isTrue);
      expect(fromB.hasPreferences, isFalse);
    });
  });

  group('TravelerPreferencesStorage - tolerancia a datos corruptos', () {
    test('JSON corrupto devuelve preferencias vacías sin lanzar', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('traveler_prefs_usr_001', 'esto-no-es-json{{{');

      final loaded = await TravelerPreferencesStorage().load('usr_001');

      expect(loaded.hasPreferences, isFalse);
      expect(loaded.completionPercentage, 0);
    });

    test('JSON con estructura no-objeto devuelve preferencias vacías',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('traveler_prefs_usr_001', '[1,2,3]');

      final loaded = await TravelerPreferencesStorage().load('usr_001');

      expect(loaded.hasPreferences, isFalse);
    });

    test('datos parcialmente válidos se recuperan descartando lo inválido',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'traveler_prefs_usr_001',
        '{"interests":["playa","zzz"],"preferredMonths":[99,8],'
            '"budgetMax":1500000}',
      );

      final loaded = await TravelerPreferencesStorage().load('usr_001');

      expect(loaded.interests, [TravelInterest.playa]);
      expect(loaded.preferredMonths, [8]);
      expect(loaded.budgetMax, 1500000);
    });
  });

  group('TravelerPreferencesController - guardado con detección de cambios',
      () {
    // Deja terminar el PUT que corre en segundo plano (unawaited).
    Future<void> waitForPush(TravelerPreferencesController c) async {
      for (var i = 0; i < 100 && c.isPushInFlight; i++) {
        await Future.delayed(Duration.zero);
      }
    }

    test('guardar sin cambios NO repite el PUT ni mueve la revisión',
        () async {
      final remote = _FakeRemote();
      final controller = TravelerPreferencesController(
        userId: 'usr_001',
        remote: remote,
      );
      await Future.delayed(Duration.zero);

      // Primer guardado: hay cambios (vacío -> perfil) y sí hay PUT.
      await controller.save(validPreferences());
      await waitForPush(controller);
      expect(remote.pushed, hasLength(1));
      expect(controller.revision, 1);

      // Segundo guardado con el MISMO contenido (otro orden en las
      // listas): devuelve true pero no vuelve a llamar al servidor.
      const reordered = TravelerPreferencesModel(
        interests: [TravelInterest.cultura, TravelInterest.naturaleza],
        budgetMin: 800000,
        budgetMax: 2500000,
        preferredMonths: [7, 6],
        style: TravelStyle.equilibrado,
      );
      final savedAgain = await controller.save(reordered);
      await waitForPush(controller);

      expect(savedAgain, isTrue);
      expect(remote.pushed, hasLength(1)); // sin PUT nuevo
      expect(controller.revision, 1); // sin señal de refresh
    });

    test('guardar con cambios sube la revisión recién al confirmar el PUT',
        () async {
      final remote = _FakeRemote();
      final controller = TravelerPreferencesController(
        userId: 'usr_001',
        remote: remote,
      );
      await Future.delayed(Duration.zero);
      await controller.save(validPreferences());
      await waitForPush(controller);

      // Congela el PUT para ver el estado DURANTE el envío.
      final gate = Completer<void>();
      remote.pushGate = gate;
      const changed = TravelerPreferencesModel(
        interests: [TravelInterest.playa],
        budgetMin: 800000,
        budgetMax: 2500000,
      );
      final pending = controller.save(changed);

      await pending;
      expect(controller.isPushInFlight, isTrue);
      expect(controller.revision, 1); // aún sin confirmar el servidor

      gate.complete();
      await waitForPush(controller);

      expect(remote.pushed, hasLength(2));
      expect(remote.pushed.last.interests, [TravelInterest.playa]);
      expect(controller.revision, 2);
    });

    test('un PUT fallido NO sube la revisión y deja el push pendiente',
        () async {
      final remote = _FakeRemote()..failPush = true;
      final controller = TravelerPreferencesController(
        userId: 'usr_001',
        remote: remote,
      );
      await Future.delayed(Duration.zero);

      await controller.save(validPreferences());
      await waitForPush(controller);

      expect(remote.pushed, isEmpty);
      expect(controller.revision, 0); // el servidor nunca confirmó
      // Lo local quedó guardado y el flag pide reintentar.
      expect(controller.hasPreferences, isTrue);
      expect(
        await TravelerPreferencesStorage().hasPendingPush('usr_001'),
        isTrue,
      );

      // Vuelve la red: guardar de nuevo (aunque el contenido sea igual,
      // hay un push pendiente) reintenta el PUT y recién ahí sube la
      // revisión.
      remote.failPush = false;
      final retried = await controller.save(validPreferences());
      await waitForPush(controller);

      expect(retried, isTrue);
      expect(remote.pushed, hasLength(1));
      expect(controller.revision, 1);
      expect(
        await TravelerPreferencesStorage().hasPendingPush('usr_001'),
        isFalse,
      );
    });

    test('adoptar del servidor solo cuando el perfil cambió', () async {
      const fromOtherDevice = TravelerPreferencesModel(
        interests: [TravelInterest.ciudad],
        budgetMin: 1000000,
        budgetMax: 3000000,
      );

      // El servidor trae un perfil DISTINTO al local (vacío): se adopta
      // y la revisión sube (señal para refrescar recomendaciones).
      final remote = _FakeRemote()..served = fromOtherDevice;
      final controller = TravelerPreferencesController(
        userId: 'usr_001',
        remote: remote,
      );
      await Future.delayed(Duration.zero);

      expect(controller.preferences.sameAs(fromOtherDevice), isTrue);
      expect(controller.revision, 1);

      // El servidor trae el MISMO perfil en otro orden: no se adopta ni
      // se mueve la revisión.
      final storage = TravelerPreferencesStorage();
      await storage.save('usr_002', validPreferences());
      final sameRemote = _FakeRemote()
        ..served = const TravelerPreferencesModel(
          interests: [TravelInterest.cultura, TravelInterest.naturaleza],
          budgetMin: 800000,
          budgetMax: 2500000,
          preferredMonths: [7, 6],
          style: TravelStyle.equilibrado,
        );
      final sameController = TravelerPreferencesController(
        userId: 'usr_002',
        storage: storage,
        remote: sameRemote,
      );
      await Future.delayed(Duration.zero);

      expect(sameController.revision, 0);
      expect(sameRemote.pushed, isEmpty);
    });
  });
}

/// Doble de [TravelerPreferencesRemoteService] controlado por el test:
/// registra los PUT, puede fallarlos o retenerlos con un gate, y sirve
/// el perfil que el test declare en [served].
class _FakeRemote extends TravelerPreferencesRemoteService {
  /// Preferencias que el "servidor" devuelve en fetch (null = sin datos).
  TravelerPreferencesModel? served;

  bool failPush = false;

  /// Si existe, el PUT se retiene hasta completarlo (para observar el
  /// estado mientras el envío está en vuelo).
  Completer<void>? pushGate;

  final List<TravelerPreferencesModel> pushed = [];

  @override
  Future<TravelerPreferencesModel?> fetch() async => served;

  @override
  Future<void> push(TravelerPreferencesModel prefs) async {
    final gate = pushGate;
    if (gate != null) await gate.future;
    if (failPush) throw Exception('sin red');
    pushed.add(prefs);
    served = prefs; // el servidor quedó con lo último que llegó
  }
}
