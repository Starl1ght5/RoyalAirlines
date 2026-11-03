import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:royal_airlines/features/traveler_profile/repository/traveler_preferences_storage.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';
import 'package:royal_airlines/services/traveler_preferences_remote_service.dart';

enum TravelerPreferencesStatus { idle, loading, success, error }

/// TravelerPreferencesController
/// -----------------------------
/// Gestor de estado de las preferencias DECLARADAS por el usuario
/// (intereses, presupuesto, meses, estilo, clase y los campos de la
/// Etapa B: compañía, duración, flexibilidad, aeropuerto base, vuelos
/// directos y destinos excluidos). Vive junto a la feature de perfil
/// de viajero, pero es deliberadamente SEPARADO de
/// [TravelerProfileController]: ese calcula el arquetipo a partir del
/// historial (input derivado, solo lectura), mientras que este
/// administra datos que el usuario edita y que se persisten por
/// usuario en [TravelerPreferencesStorage].
///
/// Se registra como provider scoped dentro de la pestaña "Para ti"
/// (no en `app.dart`), siguiendo el mismo patrón que
/// [TravelerProfileController]. El [userId] viene de
/// `AuthController.currentUser.id`: así una cuenta jamás carga las
/// preferencias de otra.
///
/// Sincronización con el backend (`GET`/`PUT /users/me/preferences`):
///
/// 1. `_load()`: caché local → enseguida se notifica (la UI nunca
///    espera a la red) y DESPUÉS se sincroniza con el servidor:
///    - si hay un push pendiente (el `PUT` anterior falló), se
///      reintenta ANTES de leer, para que el servidor no pise con lo
///      viejo lo que el usuario acaba de guardar;
///    - si el servidor tiene preferencias, GANA lo remoto y se guarda
///      también como caché local;
///    - si el servidor no tiene nada y lo local sí, se sube una vez
///      (migración de datos creados antes de conectar el backend).
/// 2. `save()`: valida → escribe LOCAL (la verdad de la UI es local y
///    el guardado NO depende de la red) → el `PUT` corre en segundo
///    plano; si falla queda marcado el flag de "push pendiente" para
///    reintentarlo en el próximo arranque.
///
/// El [remote] es OPCIONAL y por defecto `null`: sin él el controller
/// es 100% local (así los tests de esta clase no hacen HTTP). La app
/// real lo inyecta al crear el provider en `TravelerProfileScreen`.
class TravelerPreferencesController extends ChangeNotifier {
  TravelerPreferencesController({
    required String userId,
    TravelerPreferencesStorage? storage,
    TravelerPreferencesRemoteService? remote,
  })  : _userId = userId,
        _storage = storage ?? TravelerPreferencesStorage(),
        _remote = remote {
    // Sin usuario (invitado o sesión no restaurada): el controller
    // queda vacío y la UI no muestra la sección de preferencias.
    if (_userId.isNotEmpty) {
      _load();
    }
  }

  final String _userId;
  final TravelerPreferencesStorage _storage;
  final TravelerPreferencesRemoteService? _remote;

  TravelerPreferencesStatus _status = TravelerPreferencesStatus.idle;
  String? _errorMessage;
  TravelerPreferencesModel _preferences = TravelerPreferencesModel.empty();

  /// Revisión de las preferencias que el SERVIDOR ya tiene confirmadas.
  /// Cambia solo cuando de verdad se modificó algo (y el PUT correspondiente
  /// terminó bien, o el servidor mandó datos distintos al adoptarlos). La
  /// sección de recomendaciones la usa como señal para pedir la lista fresca:
  /// un "guardar" sin cambios no la mueve, así que no se refresca nada.
  int _revision = 0;

  /// `true` mientras corre al menos un PUT de preferencias. En esa ventana
  /// el backend aún no tiene el perfil nuevo (puede estar recalculando las
  /// recomendaciones), así que pedir la lista remota ahora daría una
  /// versión vieja. Se lleva como contador para tolerar dos guardados
  /// seguidos sin solaparse.
  int _pushesInFlight = 0;

  TravelerPreferencesStatus get status => _status;
  String? get errorMessage => _errorMessage;
  TravelerPreferencesModel get preferences => _preferences;
  int get revision => _revision;
  bool get isPushInFlight => _pushesInFlight > 0;

  bool get isLoading => _status == TravelerPreferencesStatus.loading;
  bool get hasPreferences => _preferences.hasPreferences;
  bool get isActive => _userId.isNotEmpty;
  int get completionPercentage => _preferences.completionPercentage;

  /// `true` cuando el controller está conectado a Spring (en la app
  /// real siempre; en tests locales, false).
  bool get isSyncedRemotely => _remote != null;

  Future<void> _load() async {
    _status = TravelerPreferencesStatus.loading;
    notifyListeners();

    _preferences = await _storage.load(_userId);
    _status = TravelerPreferencesStatus.success;
    notifyListeners();

    await _syncWithRemote();
  }

  /// Patrón caché → remoto → push migratorio. Nunca marca `error`:
  /// sin red la pantalla debe seguir mostrando lo local, no un fallo.
  Future<void> _syncWithRemote() async {
    final remote = _remote;
    if (remote == null) return;

    try {
      if (await _storage.hasPendingPush(_userId)) {
        // El usuario guardó algo que no llegó: primero SUBIR lo local,
        // nunca descargar y pisar.
        if (_preferences.hasPreferences) {
          await remote.push(_preferences);
          await _storage.setPendingPush(_userId, false);
          // El servidor ya confirmó ese perfil: es una revisión nueva.
          _revision++;
          notifyListeners();
        }
        return;
      }

      final remotePreferences = await remote.fetch();
      if (remotePreferences == null) {
        // El servidor aún no tiene nada: migración única de lo que ya
        // existía en el teléfono. Si falla, se reintenta en el próximo
        // arranque (fetch seguirá devolviendo null).
        if (_preferences.hasPreferences) {
          await remote.push(_preferences);
        }
        return;
      }

      // El servidor manda (se editó en otro dispositivo o es la fuente
      // de verdad): solo se adopta si el perfil cambió de verdad; una
      // respuesta idéntica no debe provocar refresh de recomendaciones.
      if (remotePreferences.sameAs(_preferences)) return;
      _preferences = remotePreferences;
      await _storage.save(_userId, remotePreferences);
      _revision++;
      notifyListeners();
    } catch (_) {
      // Offline o backend caído: se conserva el estado local tal cual.
    }
  }

  /// Guarda las preferencias si son VÁLIDAS. Devuelve `true` si el perfil
  /// quedó persistido (o si ya estaba, ver abajo). Un modelo inválido deja
  /// el estado en `error` con el mensaje correspondiente y NO escribe en
  /// disco (los datos inválidos nunca llegan al storage).
  ///
  /// Guardar sin CAMBIOS reales no dispara nada: ni storage ni el
  /// `PUT /users/me/preferences`, porque ese PUT invalida y recalcula las
  /// recomendaciones del usuario en el backend. La excepción es tener un
  /// push pendiente sin confirmar (un guardado anterior que no llegó): en
  /// ese caso se reintenta, porque el servidor aún no tiene ese perfil.
  Future<bool> save(TravelerPreferencesModel candidate) async {
    if (!isActive) return false;

    final validationError = candidate.validationError;
    if (validationError != null) {
      _status = TravelerPreferencesStatus.error;
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }

    if (candidate.sameAs(_preferences) && !await _hasPendingPush()) {
      // Nada que guardar: el perfil local YA es este. Ni storage ni PUT.
      _status = TravelerPreferencesStatus.success;
      _errorMessage = null;
      notifyListeners();
      return true;
    }

    _status = TravelerPreferencesStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _storage.save(_userId, candidate);
      _preferences = candidate;
      _status = TravelerPreferencesStatus.success;
      _errorMessage = null;
    } catch (_) {
      _status = TravelerPreferencesStatus.error;
      _errorMessage =
          'No se pudieron guardar tus preferencias. Intenta de nuevo.';
    }
    notifyListeners();

    if (_status == TravelerPreferencesStatus.success) {
      unawaited(_pushRemotely(candidate));
    }
    return _status == TravelerPreferencesStatus.success;
  }

  /// Lee el flag de "push pendiente" con tolerancia a fallos: si el
  /// storage no responde, se asume pendiente (más seguro subir de más).
  Future<bool> _hasPendingPush() async {
    try {
      return await _storage.hasPendingPush(_userId);
    } catch (_) {
      return true;
    }
  }

  /// Sube lo guardado al servidor SIN bloquear la UI. El flag de
  /// "push pendiente" se enciende ANTES del `PUT` y se apaga cuando
  /// el servidor responde bien: así, si la app se mata a mitad del
  /// envío, el próximo arranque sabe que aún falta subirlo.
  ///
  /// El contador de pushes en vuelo también se sube ANTES del primer
  /// `await` (esto es síncrono) para que la sección de recomendaciones
  /// no pida la lista a media invalidación. Y cuando el servidor
  /// confirma, la revisión se incrementa: recién ahí hay datos nuevos
  /// que valga la pena refrescar.
  Future<void> _pushRemotely(TravelerPreferencesModel candidate) async {
    final remote = _remote;
    if (remote == null) return;

    _pushesInFlight++;
    try {
      await _storage.setPendingPush(_userId, true);
    } catch (_) {
      _pushesInFlight--;
      return;
    }

    try {
      await remote.push(candidate);
      await _storage.setPendingPush(_userId, false);
      _revision++;
    } catch (_) {
      // Fallo de red o validación del servidor: lo local ya quedó
      // guardado y el flag sigue encendido para el próximo arranque.
    } finally {
      _pushesInFlight--;
      notifyListeners();
    }
  }

  void resetStatus() {
    _status = TravelerPreferencesStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
