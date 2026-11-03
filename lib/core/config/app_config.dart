/// AppConfig
/// ---------
/// Centraliza la configuración del entorno para evitar duplicar URLs,
/// claves o banderas entre servicios y widgets. Mantener aquí el valor
/// base permite pasar a un backend real sin tocar cada servicio por separado.
library;

import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'Royal Airlines';

  /// URL base del backend Java (Spring Boot). La app SIEMPRE consume la
  /// API real: no existe modo mock.
  ///
  /// OJO con el prefijo `/api`: el backend real sirve sus rutas bajo
  /// `http://<host>:8080/api/v1/...`, NO bajo `http://<host>:8080/v1/...`.
  /// Por eso el valor por defecto YA incluye `/api` y [baseUrl] solo le
  /// agrega la versión.
  ///
  /// El host por defecto se elige según la plataforma ([_defaultApiBaseUrl]):
  /// `localhost` allí donde Flutter corre en la misma máquina que Spring
  /// Boot (Windows/Linux/macOS/web) y `10.0.2.2` en Android, que es el
  /// alias que usa el emulador para llegar al PC que lo contiene. Así,
  /// `flutter run` para el emulador funciona sin banderas adicionales.
  ///
  /// En un **teléfono físico** `10.0.2.2` no existe (eso solo vive dentro
  /// del emulador), así que hay que sobreescribir la URL sin tocar código:
  ///
  /// ```powershell
  /// # Emulador o dispositivo con `adb reverse tcp:8080 tcp:8080`:
  /// flutter run --dart-define=API_BASE_URL=http://localhost:8080/api
  ///
  /// # Teléfono físico en la misma red WiFi (IP local del PC):
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080/api
  /// # o, más simple, usando env.json en la raíz:
  /// flutter run --dart-define-from-file=env.json
  /// ```
  ///
  /// Si `API_BASE_URL` viene definido, SIEMPRE gana sobre el valor
  /// calculado por plataforma.
  static const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Host por defecto según la plataforma corriendo la app. iOS Simulator,
  /// escritorio y web comparten la red del host, así que `localhost` les
  /// funciona tal cual; solo Android necesita el alias `10.0.2.2`.
  static String get _defaultApiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api';
    }
    return 'http://localhost:8080/api';
  }

  /// URL base efectiva: la inyectada en tiempo de compilación o, si no
  /// hay ninguna, la calculada por plataforma.
  static String get apiBaseUrl =>
      _envApiBaseUrl.isNotEmpty ? _envApiBaseUrl : _defaultApiBaseUrl;

  /// Versión de la API.
  static const String apiVersion = 'v1';

  /// Client ID de tipo "Web" de Google Cloud Console, usado como
  /// `serverClientId` de Google Sign-In para que el `idToken` emitido
  /// tenga como audiencia al backend (es lo que Spring Boot verifica).
  ///
  /// Se inyecta en tiempo de compilación para no dejar credenciales en el
  /// código:
  ///
  /// ```powershell
  /// flutter build apk --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
  /// ```
  ///
  /// Si está vacío, Google Sign-In busca el recurso `default_web_client_id`
  /// (aparece automáticamente al agregar `google-services.json`).
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Services ID de Apple (tipo "web") + URI de retorno registrados en el
  /// portal de Apple Developer. Son OBLIGATORIOS en Android: el flujo
  /// de Apple corre en Chrome Custom Tab y Apple redirige de vuelta a la
  /// app con ese `redirectUri`.
  ///
  /// ```powershell
  /// flutter build apk `
  ///   --dart-define=APPLE_SERVICES_ID=com.ejemplo.royalairlines `
  ///   --dart-define=APPLE_REDIRECT_URI=https://tu-backend.com/auth/apple/redirect
  /// ```
  ///
  /// Sin estos valores el botón de Apple muestra un mensaje claro en
  /// vez de fallar con un error críptico del plugin.
  static const String appleServicesId = String.fromEnvironment(
    'APPLE_SERVICES_ID',
  );
  static const String appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
  );

  /// Base URL completa para las llamadas HTTP. Se deja como una sola
  /// fuente de verdad para que backend y frontend compartan el mismo
  /// contrato de rutas.
  ///
  /// Con los valores por defecto queda `http://localhost:8080/api/v1`,
  /// que es exactamente donde vive el backend real.
  static String get baseUrl => '$apiBaseUrl/$apiVersion';
}
