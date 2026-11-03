import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';

/// Acceso a Firebase Messaging aislado detrás de una interfaz: así
/// [PushNotificationService] se prueba con un doble en memoria, sin
/// plugins nativos.
abstract class PushGateway {
  /// Inicializa Firebase (lee `google-services.json`). Lanza si falta la
  /// configuración nativa.
  Future<void> initialize();

  /// `true` si el usuario ya concedió el permiso de notificaciones.
  Future<bool> hasPermission();

  /// Pide el permiso al sistema (diálogo en Android 13+; en versiones
  /// anteriores se concede solo). `true` si quedó concedido.
  Future<bool> requestPermission();

  Future<String?> getToken();
  Future<void> deleteToken();

  /// Emite cuando FCM rota el token (reinstalación, restauración, etc.).
  Stream<String> get onTokenRefresh;
}

class FirebasePushGateway implements PushGateway {
  // Se resuelve perezosamente: construir el gateway no toca Firebase, solo
  // usarlo después de [initialize].
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  @override
  Future<bool> hasPermission() async =>
      _isGranted(await _messaging.getNotificationSettings());

  @override
  Future<bool> requestPermission() async =>
      _isGranted(await _messaging.requestPermission());

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  static bool _isGranted(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

/// PushNotificationService
/// -----------------------
/// Registra el dispositivo en el backend para recibir las ofertas por push.
///
/// - Hoy solo Android (iOS exige cuenta de Apple Developer de pago): en otras
///   plataformas todos los métodos son no-op y devuelven `false`.
/// - NUNCA lanza hacia afuera: sin `google-services.json`, sin red o con el
///   permiso denegado la app sigue funcionando igual, simplemente sin push.
/// - Guarda el último token enviado para no repetir el `PUT` y para poder
///   darlo de baja al cerrar sesión.
///
/// Flujo esperado:
///  1. [init] una vez al arrancar la app (`main.dart`).
///  2. Tras iniciar sesión con las alertas activadas: [registerIfPermitted]
///     (no muestra diálogos) o [requestPermissionAndRegister] (puede mostrar
///     el diálogo del sistema; llamarlo en un momento con contexto, no al abrir).
///  3. Al cerrar sesión o apagar las alertas: [unregister]
///     (`AuthController.logout` ya lo llama).
class PushNotificationService {
  PushNotificationService({
    ApiClient? client,
    PushGateway? gateway,
    bool? supported,
  })  : _client = client ?? ApiClient(),
        _gateway = gateway ?? FirebasePushGateway(),
        _supported = supported ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// Instancia compartida de la app.
  static final PushNotificationService instance = PushNotificationService();

  final ApiClient _client;
  final PushGateway _gateway;
  final bool _supported;

  Future<void>? _initFuture;
  bool _available = false;
  StreamSubscription<String>? _refreshSubscription;

  /// Último token que el backend aceptó. `null` = nada registrado.
  String? _registeredToken;

  /// `true` mientras haya una sesión que quiere push: solo entonces un
  /// cambio de token se reenvía al backend.
  bool _wantsPush = false;

  /// `true` si Firebase quedó inicializado y se puede pedir token.
  bool get isAvailable => _available;

  /// `true` si esta plataforma recibe push (hoy solo Android).
  bool get isSupported => _supported;

  /// `true` si el usuario ya concedió el permiso de notificaciones del
  /// sistema. Nunca muestra diálogos ni lanza: sin Firebase devuelve `false`.
  Future<bool> hasPermission() async {
    if (!await _ready()) return false;
    try {
      return await _gateway.hasPermission();
    } catch (error) {
      debugPrint('Push: no se pudo leer el permiso ($error)');
      return false;
    }
  }

  /// Inicializa Firebase una sola vez. Seguro de llamar varias veces.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    if (!_supported) return;
    try {
      await _gateway.initialize();
      _available = true;
      _refreshSubscription = _gateway.onTokenRefresh.listen(
        (token) {
          if (_wantsPush) _register(token);
        },
        onError: (Object error) => debugPrint('Push: error en onTokenRefresh: $error'),
      );
    } catch (error) {
      // Falta google-services.json o Firebase mal configurado.
      debugPrint('Push: Firebase no disponible, notificaciones desactivadas ($error)');
    }
  }

  /// Pide el permiso de notificaciones al sistema y, si lo conceden, registra
  /// el token en el backend. Devuelve `true` si el dispositivo quedó registrado.
  Future<bool> requestPermissionAndRegister() async {
    if (!await _ready()) return false;
    try {
      if (!await _gateway.requestPermission()) return false;
    } catch (error) {
      debugPrint('Push: no se pudo pedir el permiso ($error)');
      return false;
    }
    return _fetchAndRegister();
  }

  /// Registra el token SOLO si el permiso ya estaba concedido; nunca muestra
  /// el diálogo. Para llamarlo al iniciar sesión o abrir la app.
  Future<bool> registerIfPermitted() async {
    if (!await _ready()) return false;
    try {
      if (!await _gateway.hasPermission()) return false;
    } catch (error) {
      debugPrint('Push: no se pudo leer el permiso ($error)');
      return false;
    }
    return _fetchAndRegister();
  }

  /// Da de baja este dispositivo del usuario actual (`DELETE` en el backend)
  /// y borra el token local para que el próximo inicio de sesión reciba uno
  /// nuevo. Debe llamarse ANTES de borrar la sesión: el `DELETE` necesita el
  /// JWT. Si nunca hubo registro ni Firebase, no hace nada.
  Future<void> unregister() async {
    _wantsPush = false;
    final token = _registeredToken ?? (_available ? await _safeGetToken() : null);
    _registeredToken = null;
    if (token == null) return;

    try {
      await _client.delete('${ApiEndpoints.userDevices}/${Uri.encodeComponent(token)}');
    } catch (error) {
      debugPrint('Push: no se pudo dar de baja el dispositivo ($error)');
    }
    try {
      await _gateway.deleteToken();
    } catch (error) {
      debugPrint('Push: no se pudo borrar el token local ($error)');
    }
  }

  /// Libera el listener de rotación de token.
  Future<void> dispose() async => _refreshSubscription?.cancel();

  // ------------------------------------------------------------------

  Future<bool> _ready() async {
    await init();
    return _available;
  }

  Future<bool> _fetchAndRegister() async {
    _wantsPush = true;
    final token = await _safeGetToken();
    if (token == null || token.isEmpty) return false;
    return _register(token);
  }

  Future<String?> _safeGetToken() async {
    try {
      return await _gateway.getToken();
    } catch (error) {
      debugPrint('Push: no se pudo obtener el token ($error)');
      return null;
    }
  }

  /// `PUT /users/me/devices`. Idempotente en el backend; aquí además se evita
  /// repetirlo si el token ya fue aceptado.
  Future<bool> _register(String token) async {
    if (token == _registeredToken) return true;
    try {
      await _client.put(ApiEndpoints.userDevices, body: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      _registeredToken = token;
      return true;
    } catch (error) {
      // Sin sesión (401), sin red o backend caído: se reintenta en la próxima
      // llamada a registerIfPermitted o cuando FCM rote el token.
      debugPrint('Push: no se pudo registrar el dispositivo ($error)');
      return false;
    }
  }
}
