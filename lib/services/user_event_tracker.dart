import 'dart:async';
import 'dart:math';

import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';

/// Acumula eventos y los envía en lote (cada ~15 s o al llegar a 20), no uno
/// por clic. Se crea UNA sola vez: `Provider` en `lib/app.dart` (no es
/// ChangeNotifier, por eso NO va con ChangeNotifierProvider) con
/// `lazy: false` para que el timer corra aunque nadie escuche.
///
/// - destinationId = id de destino del backend (Location.locationID), flightId = Flight.flightID.
/// - Puerta de consentimiento: arranca `enabled = false` y solo se
///   enciende cuando `GET /users/me/consent` devuelve
///   `tracking=true` (ver `lib/app.dart`) o cuando el usuario activa
///   el toggle de Perfil. Sin eso, `POST /events` respondería 202 con
///   `accepted:0` y no se entrena nada.
/// - Si el servidor responde trackingEnabled=false (sin consentimiento), se
///   apaga solo y descarta el buffer. Llama a `enabled = true` si el usuario
///   acepta después.
/// - Sin red o con error 5xx/401 conserva el buffer y reintenta.
/// - Llamar flush() cuando la app pase a segundo plano
///   (WidgetsBindingObserver.didChangeAppLifecycleState -> paused);
///   `_AuthGate` en `lib/app.dart` ya lo hace.
class UserEventTracker {
  UserEventTracker({ApiClient? client}) : _client = client ?? ApiClient() {
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => flush());
  }

  static const _batchSize = 50;
  static const _flushAt = 20;
  static const _maxBuffer = 200;

  final ApiClient _client;
  final List<Map<String, dynamic>> _buffer = [];
  final Set<String> _seenImpressions = {};
  late final Timer _timer;
  final String _sessionId = _newId();

  /// Puerta de consentimiento. Arranca en `false`: solo empieza a
  /// acumular/enviar cuando `GET /users/me/consent` confirma
  /// `tracking=true` (o el usuario lo activa desde Perfil). El
  /// backend lo reforzaría igual, pero apagado desde el inicio se
  /// evita llenar el buffer con eventos que nunca se van a guardar.
  bool enabled = false;
  bool _flushing = false;

  void track(
    String type, {
    String? destinationId,
    String? flightId,
    String? recommendationId,
    int? position,
    String? context,
    Map<String, String>? payload,
  }) {
    if (!enabled) return;

    // Una impresión por elemento y sesión: sin esto cada rebuild/scroll
    // infla los datos. La clave combina lista + destino + vuelo: con
    // solo `recommendationId` (el id de la LISTA del backend), todas
    // las tarjetas compartirían clave y solo se registraría la
    // primera.
    if (type.endsWith('_impression')) {
      final key =
          '$type|${recommendationId ?? ''}|${destinationId ?? ''}|${flightId ?? ''}';
      if (!_seenImpressions.add(key)) return;
    }

    if (_buffer.length >= _maxBuffer) _buffer.removeAt(0);
    _buffer.add({
      'clientEventId': _newId(),
      'type': type,
      'ts': DateTime.now().toUtc().toIso8601String(),
      'sessionId': _sessionId,
      if (destinationId != null) 'destinationId': destinationId,
      if (flightId != null) 'flightId': flightId,
      if (recommendationId != null) 'recommendationId': recommendationId,
      if (position != null) 'position': position,
      if (context != null) 'context': context,
      if (payload != null && payload.isNotEmpty) 'payload': payload,
    });
    if (_buffer.length >= _flushAt) flush();
  }

  Future<void> flush() async {
    if (!enabled || _flushing || _buffer.isEmpty) return;
    _flushing = true;
    final batch = _buffer.take(_batchSize).toList();
    try {
      final response =
          await _client.post(ApiEndpoints.events, body: {'events': batch});
      _buffer.removeRange(0, batch.length);
      if (response['trackingEnabled'] == false) {
        enabled = false;
        _buffer.clear();
      }
    } on ApiException catch (e) {
      final code = e.statusCode;
      // 4xx (salvo 401/429): el lote es inválido, reintentar no sirve -> se descarta.
      // Sin código, 401, 429 o 5xx: se conserva para el próximo intento.
      if (code != null &&
          code >= 400 &&
          code < 500 &&
          code != 401 &&
          code != 429) {
        _buffer.removeRange(0, batch.length);
      }
    } finally {
      _flushing = false;
    }
  }

  void dispose() => _timer.cancel();

  static String _newId() {
    final r = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
        '${List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join()}';
  }
}
