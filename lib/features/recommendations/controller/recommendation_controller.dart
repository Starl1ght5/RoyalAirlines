import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:royal_airlines/features/recommendations/repository/recommendation_engine.dart';
import 'package:royal_airlines/features/recommendations/repository/recommendation_mapper.dart';
import 'package:royal_airlines/models/recommendation_model.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';
import 'package:royal_airlines/services/recommendation_service.dart';

enum RecommendationStatus { idle, empty, success }

/// RecommendationController
/// ------------------------
/// Gestor de estado del motor de recomendaciones (Etapa C). Toma las
/// preferencias declaradas del usuario (Etapa A) y su historial de
/// ciudades visitadas, y expone el ranking ya cortado a los N mejores
/// para la UI.
///
/// Dos caminos, mismo resultado para la UI:
/// - [loadRemote] (con sesión): la lista precalculada de
///   `GET /recommendations` del backend, mapeada con
///   [RecommendationMapper]. Si el servicio no está inyectado, la
///   llamada falla (offline/401) o el backend devuelve una lista
///   vacía, CAE AL MOTOR LOCAL sin avisar: la sección nunca se rompe.
/// - [rebuild] (sin sesión ni servicio): el motor local determinista
///   [RecommendationEngine]. Es también el camino de los tests, que
///   construyen el controller sin servicio.
///
/// Al guardar preferencias el backend borra la lista del usuario y
/// recalcula en caliente en background, así que el primer [loadRemote]
/// posterior casi siempre recibe estrategia `popular` (`__popular__`).
/// Para no quedarse con ese respaldo, [loadRemote] agenda reintentos
/// ([popularRetryDelays]) mientras la respuesta siga siendo `popular`
/// o `fallback`.
///
/// Es INDEPENDIENTE de [TravelerProfileController] (arquetipo) y de
/// [TravelerPreferencesController] (editor de preferencias): recibe
/// snapshots por parámetro y recalcula vía [rebuild]/[loadRemote], en
/// vez de acoplarse a su ciclo de vida. Así los tests no necesitan
/// providers.
class RecommendationController extends ChangeNotifier {
  RecommendationController({
    RecommendationEngine? engine,
    RecommendationService? service,
    int maxRecommendations = 4,
    List<Duration> popularRetryDelays = const [
      Duration(seconds: 3),
      Duration(seconds: 5),
    ],
  })  : _engine = engine ?? const RecommendationEngine(),
        _service = service,
        _maxRecommendations = maxRecommendations,
        _popularRetryDelays = popularRetryDelays;

  final RecommendationEngine _engine;

  /// `null` = solo motor local (tests y modo sin backend).
  final RecommendationService? _service;

  final int _maxRecommendations;

  RecommendationStatus _status = RecommendationStatus.idle;
  List<RecommendationResult> _recommendations = const [];
  String? _recommendationId;
  String? _strategy;
  bool _isLoading = false;

  /// Token de la última carga: si el usuario cambia de sesión (o
  /// guarda preferencias) mientras una petición está en vuelo, la
  /// respuesta vieja se DESCARTA en vez de pisar datos frescos.
  int _loadToken = 0;

  /// Esperas entre reintentos de [loadRemote] cuando la respuesta es
  /// `popular`/`fallback` (el backend aún estaba recalculando tras
  /// guardar preferencias). Cada entrada es la espera ANTES del
  /// siguiente intento: [3s, 5s] → intentos a los +3 s y +8 s.
  final List<Duration> _popularRetryDelays;

  /// Reintento popular agendado; se cancela si llega una carga nueva
  /// ([loadRemote]), el ranking local manda ([rebuild]) o se destruye
  /// el controlador.
  Timer? _retryTimer;

  /// Reintentos populares ya consumidos en la carga actual (tope:
  /// [_popularRetryDelays.length]).
  int _popularAttempts = 0;

  RecommendationStatus get status => _status;
  List<RecommendationResult> get recommendations => _recommendations;

  /// Id de la LISTA que se está mostrando (`recommendationID` del
  /// backend), o `null` cuando el ranking viene del motor local. La UI
  /// lo reenvía en eventos y reservas para medir conversión.
  String? get recommendationId => _recommendationId;

  /// Estrategia que generó la lista remota (`content`, `preferences`,
  /// `popular`, `fallback`); `null` en modo local. La UI la usa para
  /// aclarar cuándo el usuario ve el respaldo de populares.
  String? get strategy => _strategy;

  bool get isLoading => _isLoading;

  /// Recalcula el ranking con el motor LOCAL, de forma síncrona. Es el
  /// respaldo sin red (y el camino que usan los tests).
  ///
  /// Sin intereses declarados no hay con qué casar el catálogo →
  /// estado `empty` (la UI muestra el CTA).
  void rebuild({
    required TravelerPreferencesModel preferences,
    List<String> visitedCities = const [],
  }) {
    // Un ranking local nuevo cancela los reintentos remotos pen-
    // dientes: para esta carga ya no interesa la lista del backend.
    _retryTimer?.cancel();
    _retryTimer = null;
    _popularAttempts = 0;

    if (!preferences.hasPreferences) {
      _status = RecommendationStatus.empty;
      _recommendations = const [];
      _recommendationId = null;
      _strategy = null;
      notifyListeners();
      return;
    }

    final results = _engine.recommend(
      preferences: preferences,
      visitedCities: visitedCities,
    );

    _recommendations =
        results.take(_maxRecommendations).toList(growable: false);
    _recommendationId = null;
    _strategy = null;
    _status = RecommendationStatus.success;
    notifyListeners();
  }

  /// Carga la lista del backend (`GET /recommendations`) y la mapea a
  /// [RecommendationResult]. Cualquier fallo —sin servicio, sin red,
  /// 401, lista vacía— cae silenciosamente al motor local: el backend
  /// es la fuente preferente, no un requisito.
  ///
  /// Si la respuesta llega como `popular`/`fallback` (el backend aún
  /// estaba recalculando tras un guardado de preferencias), agenda
  /// reintentos con [popularRetryDelays] hasta que llegue la lista
  /// personalizada o se agote el tope.
  Future<void> loadRemote({
    required TravelerPreferencesModel preferences,
    List<String> visitedCities = const [],
  }) {
    // Carga con intención nueva (cambio de pestaña, sesión o guardado
    // de preferencias): los reintentos de la carga anterior no aplican.
    _retryTimer?.cancel();
    _retryTimer = null;
    _popularAttempts = 0;
    return _fetch(preferences: preferences, visitedCities: visitedCities);
  }

  Future<void> _fetch({
    required TravelerPreferencesModel preferences,
    required List<String> visitedCities,
  }) async {
    final service = _service;
    if (service == null) {
      rebuild(preferences: preferences, visitedCities: visitedCities);
      return;
    }

    final token = ++_loadToken;
    _isLoading = true;
    notifyListeners();

    try {
      final list = await service.fetch();
      if (token != _loadToken) return;

      final mapped = list.items
          .map((item) => RecommendationMapper.map(
                item,
                preferences: preferences,
                visitedCities: visitedCities,
              ))
          .whereType<RecommendationResult>()
          .take(_maxRecommendations)
          .toList(growable: false);

      if (mapped.isEmpty) {
        // Lista vacía (catálogo sin destinos): mejor el motor local.
        rebuild(preferences: preferences, visitedCities: visitedCities);
      } else {
        _recommendations = mapped;
        _recommendationId = list.recommendationID;
        _strategy = list.strategy;
        _status = RecommendationStatus.success;
        _schedulePopularRetry(
          strategy: list.strategy,
          token: token,
          preferences: preferences,
          visitedCities: visitedCities,
        );
      }
    } catch (_) {
      // Sin red / 401 / respuesta inesperada: el motor local sigue
      // funcionando, no se muestra error al usuario.
      if (token != _loadToken) return;
      rebuild(preferences: preferences, visitedCities: visitedCities);
    } finally {
      if (token == _loadToken) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Agenda el siguiente intento de [_fetch] cuando la lista que llegó
  /// es de RESPALDO: al guardar preferencias Spring borra el documento
  /// y pide el recálculo en caliente en background (hasta 10 s), así
  /// que el primer `GET` posterior casi siempre devuelve `__popular__`
  /// sin que nadie lo notifique después.
  ///
  /// Sin señal propia real el tope de [_popularRetryDelays] deja esto
  /// en un par de `GET` extra por carga, nada más.
  void _schedulePopularRetry({
    required String? strategy,
    required int token,
    required TravelerPreferencesModel preferences,
    required List<String> visitedCities,
  }) {
    if (strategy != 'popular' && strategy != 'fallback') {
      _popularAttempts = 0;   // lista personalizada: se acabó la carrera
      return;
    }
    if (_popularAttempts >= _popularRetryDelays.length) return;

    final delay = _popularRetryDelays[_popularAttempts];
    _popularAttempts++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (token != _loadToken) return;   // una carga más nueva ya mandó
      _fetch(preferences: preferences, visitedCities: visitedCities);
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    super.dispose();
  }
}
