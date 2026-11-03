import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:royal_airlines/features/flights/offer_deep_link.dart';
import 'package:royal_airlines/services/user_event_tracker.dart';

/// Datos de una notificación de oferta, tal como los manda el backend en el
/// bloque `data` de FCM (`OfferNotificationService.data`).
class OfferPushPayload {
  const OfferPushPayload({
    required this.origin,
    required this.destination,
    this.flightId,
    this.departureDate,
  });

  /// Códigos IATA, p. ej. "BOG" y "CTG".
  final String origin;
  final String destination;
  final String? flightId;
  final DateTime? departureDate;

  /// `null` si el mensaje no es una oferta o le faltan datos para buscar vuelos.
  static OfferPushPayload? tryParse(Map<String, String> data) {
    if (data['type'] != 'offer') return null;
    final origin = data['origin']?.trim().toUpperCase();
    final destination = data['destination']?.trim().toUpperCase();
    if (origin == null || origin.isEmpty || destination == null || destination.isEmpty) {
      return null;
    }
    final flightId = data['flightId']?.trim();
    return OfferPushPayload(
      origin: origin,
      destination: destination,
      flightId: (flightId == null || flightId.isEmpty) ? null : flightId,
      departureDate: DateTime.tryParse(data['departureDate'] ?? ''),
    );
  }
}

/// Mensaje push ya desacoplado de Firebase.
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});
  final String? title;
  final String? body;
  final Map<String, String> data;
}

/// Origen de los mensajes: Firebase en la app, un doble en las pruebas.
abstract class PushMessageSource {
  /// Mensajes que llegan con la app ABIERTA (primer plano).
  Stream<PushMessage> get onMessage;

  /// El usuario tocó una notificación con la app en SEGUNDO PLANO.
  Stream<PushMessage> get onOpened;

  /// La notificación que abrió la app estando CERRADA, si hubo una.
  Future<PushMessage?> getInitial();
}

class FirebasePushMessageSource implements PushMessageSource {
  @override
  Stream<PushMessage> get onMessage => FirebaseMessaging.onMessage.map(_map);

  @override
  Stream<PushMessage> get onOpened => FirebaseMessaging.onMessageOpenedApp.map(_map);

  @override
  Future<PushMessage?> getInitial() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : _map(message);
  }

  static PushMessage _map(RemoteMessage message) => PushMessage(
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data.map((key, value) => MapEntry(key, value.toString())),
      );
}

/// PushMessageHandler
/// ------------------
/// Decide qué hacer con cada notificación según el estado de la app:
///
/// - **Primer plano:** FCM no muestra nada solo; se enseña un aviso dentro de la
///   app con el botón "VER".
/// - **Segundo plano:** el sistema ya mostró la notificación; al tocarla se abre
///   la búsqueda de esa ruta y fecha.
/// - **App cerrada:** igual, pero la sesión todavía se está restaurando. El
///   destino queda PENDIENTE y se abre cuando [onSession] avisa que ya hay
///   sesión (sin sesión no hay a dónde navegar: la pantalla sería el login).
///
/// La navegación real vive en `offer_deep_link.dart`; aquí solo está la decisión,
/// por eso se prueba sin Firebase ni pantallas.
class PushMessageHandler {
  PushMessageHandler({
    required PushMessageSource source,
    required Future<void> Function(OfferPushPayload) openOffer,
    required void Function(PushMessage, OfferPushPayload, VoidCallback) showBanner,
  })  : _source = source,
        _openOffer = openOffer,
        _showBanner = showBanner;

  /// Instancia de la app, conectada a Firebase y a la navegación real.
  static final PushMessageHandler instance = PushMessageHandler(
    source: FirebasePushMessageSource(),
    openOffer: openOfferSearch,
    showBanner: showOfferBanner,
  );

  final PushMessageSource _source;
  final Future<void> Function(OfferPushPayload) _openOffer;
  final void Function(PushMessage, OfferPushPayload, VoidCallback) _showBanner;
  final List<StreamSubscription<PushMessage>> _subscriptions = [];

  /// Lo fija `_AuthGate` para registrar `offer_click` al abrir una oferta. Con
  /// el tracker apagado (sin consentimiento) no guarda nada.
  UserEventTracker? tracker;

  bool _sessionActive = false;
  OfferPushPayload? _pending;
  bool _started = false;

  /// Empieza a escuchar. Llamar UNA vez, solo si Firebase quedó inicializado
  /// (los streams de `firebase_messaging` fallan sin él).
  void init() {
    if (_started) return;
    _started = true;
    _subscriptions
      ..add(_source.onMessage.listen(_handleForeground))
      ..add(_source.onOpened.listen(_handleOpened));
    _source.getInitial().then((message) {
      if (message != null) _handleOpened(message);
    }).catchError((Object error) {
      debugPrint('Push: no se pudo leer el mensaje inicial ($error)');
    });
  }

  /// `_AuthGate` lo llama en cada cambio de sesión.
  /// - [authenticated]: hay usuario con sesión; abre lo que estuviera pendiente.
  /// - [restoring]: la sesión guardada aún se está validando; no se descarta nada.
  void onSession({required bool authenticated, required bool restoring}) {
    _sessionActive = authenticated;
    if (authenticated) {
      _openPending();
    } else if (!restoring) {
      _pending = null; // sin sesión una notificación vieja no debe abrirse luego
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _started = false;
  }

  // ------------------------------------------------------------------

  void _handleForeground(PushMessage message) {
    final payload = OfferPushPayload.tryParse(message.data);
    if (payload == null || !_sessionActive) return;
    _showBanner(message, payload, () => _open(payload));
  }

  void _handleOpened(PushMessage message) {
    final payload = OfferPushPayload.tryParse(message.data);
    if (payload == null) return;
    _pending = payload;
    _openPending();
  }

  void _openPending() {
    final payload = _pending;
    if (payload == null || !_sessionActive) return;
    _pending = null;
    _open(payload);
  }

  void _open(OfferPushPayload payload) {
    tracker?.track(
      'offer_click',
      context: 'push',
      destinationId: payload.destination,
      flightId: payload.flightId,
      payload: {
        'origin': payload.origin,
        'destination': payload.destination,
        if (payload.departureDate != null)
          'departureDate': payload.departureDate!.toIso8601String().split('T').first,
        'source': 'push',
      },
    );
    _openOffer(payload).catchError((Object error) {
      debugPrint('Push: no se pudo abrir la oferta ($error)');
    });
  }
}
