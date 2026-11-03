import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:royal_airlines/core/config/app_config.dart';
import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';
import 'package:royal_airlines/core/network/jwt_claims.dart';
import 'package:royal_airlines/models/user_model.dart';
import 'package:royal_airlines/services/session_storage.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Excepción específica de autenticación, para que el controller pueda
/// distinguir "credenciales inválidas" de un error inesperado.
class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;

  /// Código HTTP de la respuesta, cuando el error vino del backend
  /// (por ejemplo 401 para credenciales inválidas o token expirado).
  /// Permite al controller decidir si debe cerrar sesión o solo mostrar
  /// el mensaje.
  final int? statusCode;

  @override
  String toString() => message;
}

/// AuthService
/// -----------
/// Única responsable de "hablar" con el backend de autenticación
/// (Spring Boot en `localhost:8080`). No hay datos de usuarios ni
/// contraseñas en el frontend: todo vive en MongoDB detrás del backend,
/// y aquí solo se hacen peticiones HTTP y se parsean las respuestas.
class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  final SessionStorage _sessionStorage = SessionStorage();

  Future<UserModel> login(
      {required String email, required String password, String? fullName}) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        body: {'email': email.trim(), 'password': password},
      );
      // Primero validar/parsear la respuesta; el token solo se guarda
      // si la sesión es válida (evita tokens huérfanos).
      final token = _tokenFromResponse(response);
      if (token == null) {
        throw const AuthException('La respuesta no contiene un token válido');
      }
      final user = _userFromResponse(
        response,
        fallbackEmail: email.trim(),
        fallbackFullName: fullName,
      );
      await _sessionStorage.saveToken(token);
      return user;
    } on ApiException catch (e) {
      // Errores 4xx/5xx del backend (credenciales inválidas, cuenta
      // bloqueada, caída del servidor) se traducen al único tipo que
      // el controller sabe mostrar en la UI.
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      // Este backend responde 201 con el cuerpo VACÍO: no devuelve
      // token ni usuario. Por eso, tras registrar, se hace login para
      // obtener la sesión. `fullName` se envía igual (el backend lo
      // ignora por ahora, pero no rompe) para no perder el nombre si
      // empieza a aceptarlo.
      await _apiClient.post(
        ApiEndpoints.register,
        body: {
          'fullName': fullName.trim(),
          'email': email.trim(),
          'password': password,
        },
      );
      return await login(
        email: email,
        password: password,
        fullName: fullName.trim(),
      );
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  /// Perfil actual de la cuenta autenticada (`GET /users/me`).
  Future<UserModel> getProfile() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.profile);
      final user = _userFromResponse(response);
      if (user.id.isEmpty && user.email.isEmpty) {
        throw const AuthException('La respuesta de autenticación no es válida');
      }
      return user;
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  /// Actualiza nombre/correo del usuario autenticado
  /// (`PUT /users/me`).
  ///
  /// El backend responde con el perfil actualizado y un token NUEVO:
  /// el JWT usa el correo como sujeto, así que al cambiarlo el token
  /// anterior deja de valer. Se guarda aquí mismo para que la sesión
  /// siga viva sin pedir login otra vez.
  Future<UserModel> updateProfile({
    required String fullName,
    required String email,
  }) async {
    try {
      final response = await _apiClient.put(
        ApiEndpoints.profile,
        body: {
          'fullName': fullName.trim(),
          'email': email.trim(),
        },
      );
      final token = _tokenFromResponse(response);
      if (token != null) {
        await _sessionStorage.saveToken(token);
      }
      return _userFromResponse(response);
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  /// Cambia la contraseña del usuario autenticado
  /// (`POST /auth/change-password`).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.changePassword,
        body: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  /// Pide al backend enviar instrucciones de recuperación a [email]
  /// (`POST /auth/forgot-password`). El backend siempre responde con
  /// éxito aunque el correo no exista (práctica de seguridad estándar
  /// para no filtrar qué correos están registrados).
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _apiClient.post(
        ApiEndpoints.forgotPassword,
        body: {'email': email.trim()},
      );
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  /// Restablece la contraseña con el código recibido por correo
  /// (`POST /auth/reset-password`).
  ///
  /// El código es de un solo uso: si el backend lo acepta, la contraseña
  /// cambia y el código deja de servir.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.resetPassword,
        body: {
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword,
        },
      );
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  Future<void> logout() async {
    await _sessionStorage.clear();
  }

  /// Login con Google (`google_sign_in` → `POST /auth/google`).
  ///
  /// Devuelve `null` si el usuario CANCELÓ el diálogo de Google (no es
  /// un error, la UI no debe mostrar nada). En cualquier otro fallo lanza
  /// [AuthException].
  Future<UserModel?> signInWithGoogle() async {
    try {
      final google = GoogleSignIn.instance;
      // initialize() debe llamarse UNA sola vez antes de authenticate().
      if (!_googleInitialized) {
        await google.initialize(
          serverClientId: AppConfig.googleWebClientId.isEmpty
              ? null
              : AppConfig.googleWebClientId,
        );
        _googleInitialized = true;
      }
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'Google no devolvió un token de identidad válido',
        );
      }
      // Google ya entrega el nombre: se pasa para que el usuario no
      // quede con `fullName` vacío cuando el backend responde solo
      // `{token}` (sin objeto de usuario).
      final displayName = account.displayName?.trim();
      return completeSocialLogin(
        endpoint: ApiEndpoints.authGoogle,
        identityToken: idToken,
        fullName:
            (displayName == null || displayName.isEmpty) ? null : displayName,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthException(_googleErrorMessage(e.code));
    } on MissingPluginException {
      // Plataformas sin plugin (por ejemplo Windows desktop): el botón
      // existe en la UI, pero el flujo solo corre en Android/iOS/Web.
      throw const AuthException(
        'Google Sign-In no está disponible en esta plataforma. '
        'Inicia sesión con tu correo y contraseña.',
      );
    } on PlatformException {
      // Google rechaza el init cuando falta el Client ID (firma SHA-1
      // mal configurada o sin --dart-define=GOOGLE_WEB_CLIENT_ID).
      // Mensaje claro en vez del "developer error" críptico nativo.
      throw const AuthException(
        'Google Sign-In no está configurado en esta app. '
        'Revisa el Client ID de Google Cloud.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'No se pudo conectar con Google. Intenta de nuevo.',
      );
    }
  }

  /// Login con Apple (`sign_in_with_apple` → `POST /auth/apple`).
  ///
  /// Devuelve `null` si el usuario canceló. En Android/iOS el flujo
  /// corre en una pestaña/ventana del navegador de Apple.
  Future<UserModel?> signInWithApple() async {
    // En Android el plugin exige WebAuthenticationOptions (Services ID
    // + redirectUri del portal de Apple Developer). Sin ellos el plugin
    // lanza un error críptico, así que se valida ANTES con un mensaje
    // claro. `!kIsWeb &&` evita evaluar Platform (de dart:io) en web.
    if (_isAndroid &&
        (AppConfig.appleServicesId.isEmpty ||
            AppConfig.appleRedirectUri.isEmpty)) {
      throw const AuthException(
        'Apple Sign-In no está configurado en esta app. '
        'Revisa el Services ID y el redirect URI de Apple Developer.',
      );
    }

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: _isAndroid
            ? WebAuthenticationOptions(
                clientId: AppConfig.appleServicesId,
                redirectUri: Uri.parse(AppConfig.appleRedirectUri),
              )
            : null,
      );
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw const AuthException(
          'Apple no devolvió un token de identidad válido',
        );
      }
      // Apple solo envía el nombre en la PRIMERA autorización; después
      // devuelve null y la app conserva el nombre guardado en el backend.
      final fullName = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().join(' ').trim();
      return completeSocialLogin(
        endpoint: ApiEndpoints.authApple,
        identityToken: identityToken,
        fullName: fullName.isEmpty ? null : fullName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw AuthException(_appleErrorMessage(e.code));
    } on SignInWithAppleNotSupportedException {
      throw const AuthException(
        'Apple Sign-In no está disponible en esta plataforma.',
      );
    } on MissingPluginException {
      throw const AuthException(
        'Apple Sign-In no está disponible en esta plataforma. '
        'Inicia sesión con tu correo y contraseña.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'No se pudo conectar con Apple. Intenta de nuevo.',
      );
    }
  }

  /// Completa un login social enviando el JWT del proveedor al backend
  /// (`POST /auth/google` o `POST /auth/apple`) y guarda la sesión con
  /// la misma mecánica que [login]. El backend — no el frontend — es el
  /// que verifica el token con las llaves públicas del proveedor.
  ///
  /// Público para tests (permite validar el contrato HTTP sin ejecutar
  /// el diálogo nativo de Google/Apple).
  Future<UserModel> completeSocialLogin({
    required String endpoint,
    required String identityToken,
    String? fullName,
  }) async {
    try {
      final response = await _apiClient.post(
        endpoint,
        body: {
          'identityToken': identityToken,
          if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
        },
      );
      final user = _userFromResponse(response, fallbackFullName: fullName);
      await _saveTokenFromResponse(response);
      return user;
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  bool _googleInitialized = false;

  /// true solo en el APK/empaquetado Android (evita evaluar `Platform`
  /// de dart:io en web, donde lanzaría UnsupportedError).
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  String _googleErrorMessage(GoogleSignInExceptionCode code) {
    switch (code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Sign-In no está configurado en esta app. '
            'Revisa el Client ID de Google Cloud.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'No se pudo mostrar el diálogo de Google.';
      default:
        return 'No se pudo iniciar sesión con Google. Intenta de nuevo.';
    }
  }

  String _appleErrorMessage(AuthorizationErrorCode code) {
    switch (code) {
      case AuthorizationErrorCode.failed:
        return 'Apple no pudo completar el inicio de sesión.';
      case AuthorizationErrorCode.notHandled:
      case AuthorizationErrorCode.unknown:
      default:
        return 'No se pudo iniciar sesión con Apple. Intenta de nuevo.';
    }
  }

  Future<void> _saveTokenFromResponse(Map<String, dynamic> response) async {
    final token = _tokenFromResponse(response);
    if (token == null) {
      throw const AuthException('La respuesta no contiene un token válido');
    }
    await _sessionStorage.saveToken(token);
  }

  /// Saca el token de la respuesta de autenticación.
  ///
  /// Acepta las dos formas que conviven:
  ///  - `{token: "..."}`: el backend real responde así, pelado.
  ///  - `{data: {token: "..."}}`: la envoltura del contrato anterior.
  String? _tokenFromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final token = data['token'];
      if (token is String && token.isNotEmpty) return token;
    }
    final token = response['token'];
    if (token is String && token.isNotEmpty) return token;
    return null;
  }

  /// Arma el [UserModel] a partir de la respuesta.
  ///
  /// Tolera varias formas porque el backend cambió:
  ///  - `{data: {token, user}}`: contrato anterior de la app.
  ///  - `{token, user}`: envoltura plana.
  ///  - `{token}` SOLO: el backend real NO devuelve el usuario, así que
  ///    se reconstruye con los claims del JWT (correo e id) y, si hace
  ///    falta, con los datos que la persona ya escribió en el
  ///    formulario.
  UserModel _userFromResponse(
    Map<String, dynamic> response, {
    String? fallbackEmail,
    String? fallbackFullName,
  }) {
    final data = response['data'];
    final scopes = <Map<String, dynamic>>[
      if (data is Map<String, dynamic>) data,
      response,
    ];

    for (final scope in scopes) {
      final nested = scope['user'];
      final source = nested is Map<String, dynamic> ? nested : scope;
      if (source['id'] != null || source['email'] != null) {
        return UserModel(
          id: _readString(source['id']) ?? '',
          fullName: _readString(source['fullName']) ?? '',
          email: _readString(source['email']) ?? '',
          avatarUrl: _readString(source['avatarUrl']),
        );
      }
    }

    // Sin usuario en la respuesta: se reconstruye desde el JWT, que
    // trae el correo (sub) y el id del usuario.
    final claims = JwtClaims.tryParse(_tokenFromResponse(response));
    return UserModel(
      id: claims?.userId ?? '',
      fullName: fallbackFullName ?? '',
      email: fallbackEmail ?? claims?.subject ?? '',
    );
  }
}

/// Lee un valor del JSON como texto, tolerando que no sea un String.
String? _readString(Object? value) {
  if (value is String) return value;
  if (value == null) return null;
  return value.toString();
}
