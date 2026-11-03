import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/jwt_claims.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pruebas de [AuthController] contra un backend simulado con
/// [MockClient] de `package:http/testing.dart`.
///
/// El mock reproduce el contrato REAL del backend Spring Boot:
///  - `POST /users/login` → `{"token": "<jwt>"}` (sin envoltorio `data`
///    y sin objeto de usuario).
///  - `POST /users/register` → 201 con el cuerpo vacío; el token se
///    pide con un login después.
///  - `GET /users/me` → perfil de la cuenta; `PUT /users/me` →
///    actualización. El backend renueva el `token` porque el JWT usa el
///    correo como sujeto.
///  - Los errores usan Problem Details RFC 7807 (`detail`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_secure_storage usa un MethodChannel nativo que no existe
  // en el entorno de test; se simula en memoria para que
  // SessionStorage pueda guardar/leer el token durante los tests.
  final secureStorageValues = <String, String>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'write':
        final args = call.arguments as Map;
        secureStorageValues[args['key'] as String] = args['value'] as String;
        return null;
      case 'read':
        final args = call.arguments as Map;
        return secureStorageValues[args['key'] as String];
      case 'delete':
        final args = call.arguments as Map;
        secureStorageValues.remove(args['key'] as String);
        return null;
      case 'deleteAll':
        secureStorageValues.clear();
        return null;
      case 'readAll':
        return secureStorageValues;
      case 'containsKey':
        final args = call.arguments as Map;
        return secureStorageValues.containsKey(args['key'] as String);
      default:
        return null;
    }
  });

  setUp(() {
    // Cada test arranca con SharedPreferences y secure storage
    // vacíos, para que una sesión guardada en un test no contamine a
    // los demás.
    SharedPreferences.setMockInitialValues({});
    secureStorageValues.clear();
  });

  const demoEmail = 'demo@royalairlines.com';
  const demoPassword = 'Demo2026!';

  /// JWT de ejemplo con la misma forma que emite el backend:
  /// `sub` = correo, `id` = id del usuario, `exp` = vencimiento.
  ///
  /// La FIRMA es inventada: la app nunca la verifica (el backend es la
  /// autoridad), solo lee el payload.
  String fakeJwt({String email = demoEmail, bool expired = false}) {
    String segment(Map<String, dynamic> data) => base64Url
        .encode(utf8.encode(jsonEncode(data)))
        .replaceAll('=', '');

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = segment({'alg': 'HS256', 'typ': 'JWT'});
    final payload = segment({
      'sub': email,
      'id': 'usr_001',
      'iat': now,
      'exp': expired ? now - 60 : now + 600,
    });
    return '$header.$payload.firma-de-ejemplo';
  }

  /// Respuesta de login real: `{"token": "..."}` y nada más.
  http.Response loginResponse({String email = demoEmail}) => http.Response(
        jsonEncode({'token': fakeJwt(email: email)}),
        200,
        headers: {'content-type': 'application/json'},
      );

  /// Error real del backend: Problem Details RFC 7807.
  http.Response problemResponse(int status, String detail) => http.Response(
        jsonEncode({
          'type': 'about:blank',
          'title': 'Error',
          'status': status,
          'detail': detail,
          'instance': '/api/v1/users/login',
        }),
        status,
        headers: {'content-type': 'application/json'},
      );

  /// Backend simulado con el contrato real del backend Spring Boot.
  MockClient backendClient() => MockClient((request) async {
        final path = request.url.path;

        if (request.method == 'POST' && path.endsWith('/users/login')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['password'] == demoPassword) {
            return loginResponse(email: body['email'] as String);
          }
          return problemResponse(401, 'Credenciales invalidas');
        }

        if (request.method == 'POST' && path.endsWith('/users/register')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if ((body['email'] as String).startsWith('repetido')) {
            return problemResponse(409, 'El email ya esta registrado');
          }
          // El backend real responde 201 con el cuerpo vacío: el token
          // se obtiene con un login posterior.
          return http.Response('', 201);
        }

        // Perfil de la cuenta autenticada: `GET` lo consulta y `PUT` lo
        // actualiza. Ambas exigen el token.
        if (path.endsWith('/users/me')) {
          final auth = request.headers['Authorization'] ??
              request.headers['authorization'];
          if (auth == null || !auth.startsWith('Bearer ')) {
            return problemResponse(401, 'Token requerido');
          }

          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'id': 'usr_001',
                'fullName': 'Alejandro Torres',
                'email': demoEmail,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.method == 'PUT') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['email'] == 'ocupado@test.com') {
              return problemResponse(409, 'El email ya esta registrado');
            }
            // El backend renueva el token: el JWT usa el correo como
            // sujeto, así que un cambio de correo invalida el anterior.
            return http.Response(
              jsonEncode({
                'id': 'usr_001',
                'fullName': body['fullName'],
                'email': body['email'],
                'token': fakeJwt(email: body['email'] as String),
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }

        // Cambio de contraseña (requiere token) y recuperación (pública).
        if (request.method == 'POST' && path.endsWith('/auth/change-password')) {
          final auth = request.headers['Authorization'] ??
              request.headers['authorization'];
          if (auth == null || !auth.startsWith('Bearer ')) {
            return problemResponse(401, 'Token requerido');
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['currentPassword'] != demoPassword) {
            return problemResponse(400, 'La contrasena actual no es correcta');
          }
          return http.Response(
            jsonEncode({'success': true, 'message': 'Contrasena actualizada'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'POST' && path.endsWith('/auth/forgot-password')) {
          // Siempre 200, exista o no el correo, para no filtrar cuentas.
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Si el correo existe, recibiras instrucciones',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'POST' && path.endsWith('/auth/reset-password')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['code'] != '123456') {
            return problemResponse(400, 'El codigo es invalido o ha expirado');
          }
          return http.Response(
            jsonEncode({'success': true, 'message': 'Contrasena actualizada'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return problemResponse(404, 'No encontrado');
      });

  AuthController buildController() => AuthController(
        authService: AuthService(
          apiClient: ApiClient(
            baseUrl: 'http://localhost:8080/api/v1',
            client: backendClient(),
          ),
        ),
      );

  group('AuthController - login', () {
    test('login con credenciales válidas deja status success', () async {
      final controller = buildController();
      await controller.login(email: demoEmail, password: demoPassword);

      expect(controller.status, AuthStatus.success);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.currentUser?.email, demoEmail);
    });

    test('el usuario se reconstruye con los claims del JWT', () async {
      // El backend no devuelve el usuario, solo el token: el id sale
      // del claim `id` del JWT.
      final controller = buildController();
      await controller.login(email: demoEmail, password: demoPassword);

      expect(controller.currentUser?.id, 'usr_001');
    });

    test('login con credenciales inválidas deja status error', () async {
      final controller = buildController();
      await controller.login(
        email: demoEmail,
        password: 'contraseña-incorrecta',
      );

      expect(controller.status, AuthStatus.error);
      // El mensaje sale del `detail` del Problem Details del backend.
      expect(controller.errorMessage, 'Credenciales invalidas');
      expect(controller.isAuthenticated, isFalse);
    });
  });

  group('AuthController - registro', () {
    test('un usuario nuevo se registra correctamente', () async {
      final controller = buildController();
      await controller.register(
        fullName: 'Pasajero Nuevo',
        email: 'nuevo@test.com',
        password: demoPassword,
      );

      expect(controller.registerStatus, AuthStatus.success);
      expect(controller.currentUser?.email, 'nuevo@test.com');
    });

    test('registrar un correo ya tomado deja el error del backend',
        () async {
      final controller = buildController();
      await controller.register(
        fullName: 'Segundo',
        email: 'repetido@test.com',
        password: demoPassword,
      );

      expect(controller.registerStatus, AuthStatus.error);
      expect(controller.registerErrorMessage, 'El email ya esta registrado');
    });
  });

  group('AuthController - sesión', () {
    test('logout limpia el usuario actual y el status', () async {
      final controller = buildController();
      await controller.login(email: demoEmail, password: demoPassword);
      expect(controller.isAuthenticated, isTrue);

      await controller.logout();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.currentUser, isNull);
      expect(controller.status, AuthStatus.idle);
    });

    test('tryRestoreSession recupera la sesión guardada tras login',
        () async {
      final controller = buildController();
      await controller.login(email: demoEmail, password: demoPassword);

      // Simula "reabrir la app": un controller nuevo debe recuperar
      // la sesión guardada y refrescar el perfil con `GET /users/me`.
      final restoredController = buildController();
      expect(restoredController.isAuthenticated, isFalse);
      await restoredController.tryRestoreSession();

      expect(restoredController.isAuthenticated, isTrue);
      expect(restoredController.currentUser?.email, demoEmail);
    });

    test('tryRestoreSession no recupera una sesión ya expirada', () async {
      final controller = buildController();
      await controller.login(email: demoEmail, password: demoPassword);
      expect(controller.isAuthenticated, isTrue);

      // Simula que la sesión se guardó hace más tiempo del permitido
      // (SessionStorage.sessionDuration), como si el usuario hubiera
      // dejado la app instalada sin abrirla por semanas.
      final prefs = await SharedPreferences.getInstance();
      final longAgo = DateTime.now().subtract(const Duration(days: 30));
      await prefs.setString(
        'session_login_at',
        longAgo.toIso8601String(),
      );

      final restoredController = buildController();
      await restoredController.tryRestoreSession();

      expect(restoredController.isAuthenticated, isFalse);
      expect(restoredController.currentUser, isNull);
    });

    test('tryRestoreSession conserva la sesión local si el backend está caído',
        () async {
      final controller = AuthController(
        authService: AuthService(
          apiClient: ApiClient(
            baseUrl: 'http://localhost:8080/api/v1',
            // El backend no responde: simula caída total del servidor.
            client: MockClient(
              (_) async => throw http.ClientException('sin conexión'),
            ),
          ),
        ),
      );
      await controller.login(email: demoEmail, password: demoPassword);
      // El login también falla con el backend caído...
      expect(controller.isAuthenticated, isFalse);

      // ...pero si ya había una sesión guardada de antes, reabrir la
      // app no debe echar al usuario por una falla del servidor.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_user_id', 'usr_001');
      await prefs.setString('session_user_fullName', 'Alejandro Torres');
      await prefs.setString('session_user_email', demoEmail);
      await prefs.setString(
        'session_login_at',
        DateTime.now().toIso8601String(),
      );

      final restoredController = AuthController(
        authService: AuthService(
          apiClient: ApiClient(
            baseUrl: 'http://localhost:8080/api/v1',
            client: MockClient(
              (_) async => throw http.ClientException('sin conexión'),
            ),
          ),
        ),
      );
      await restoredController.tryRestoreSession();

      expect(restoredController.isAuthenticated, isTrue);
      expect(restoredController.currentUser?.email, demoEmail);
    });
  });

  group('AuthController - perfil', () {
    test('updateProfile guarda el perfil y el token renovado', () async {
      final controller = buildController();
      await controller.login(email: demoEmail, password: demoPassword);

      await controller.updateProfile(
        fullName: '  Alejandro Torres  ',
        email: 'nuevo@royalairlines.com',
      );

      expect(controller.profileStatus, ProfileUpdateStatus.success);
      expect(controller.currentUser?.fullName, 'Alejandro Torres');
      expect(controller.currentUser?.email, 'nuevo@royalairlines.com');

      // El backend renueva el token al cambiar el correo (el JWT usa el
      // correo como sujeto): debe quedar guardado para no perder la sesión.
      final savedToken = secureStorageValues['session_access_token'];
      expect(savedToken, isNotNull);
      expect(
        JwtClaims.tryParse(savedToken)?.subject,
        'nuevo@royalairlines.com',
      );
    });

    test('updateProfile con un correo tomado conserva el error del backend',
        () async {
      final controller = buildController();
      await controller.login(email: demoEmail, password: demoPassword);

      Object? error;
      try {
        await controller.updateProfile(
          fullName: 'Alejandro Torres',
          email: 'ocupado@test.com',
        );
      } catch (e) {
        error = e;
      }

      expect(error, isA<AuthException>());
      expect(controller.profileStatus, ProfileUpdateStatus.error);
      expect(controller.profileErrorMessage, 'El email ya esta registrado');
      // El perfil anterior no se pisa si el backend rechaza el cambio.
      expect(controller.currentUser?.email, demoEmail);
    });
  });

  group('AuthController - contraseña', () {
    test('changePassword con la contraseña actual correcta deja success',
        () async {
      final controller = buildController();
      await controller.login(email: demoEmail, password: demoPassword);

      await controller.changePassword(
        currentPassword: demoPassword,
        newPassword: 'NuevaClave2026!',
      );

      expect(controller.profileStatus, ProfileUpdateStatus.success);
      expect(controller.profileErrorMessage, isNull);
    });

    test('changePassword con la contraseña actual incorrecta conserva el error',
        () async {
      final controller = buildController();
      await controller.login(email: demoEmail, password: demoPassword);

      Object? error;
      try {
        await controller.changePassword(
          currentPassword: 'incorrecta',
          newPassword: 'NuevaClave2026!',
        );
      } catch (e) {
        error = e;
      }

      expect(error, isA<AuthException>());
      expect(controller.profileStatus, ProfileUpdateStatus.error);
      expect(
        controller.profileErrorMessage,
        'La contrasena actual no es correcta',
      );
    });

    test('requestPasswordReset no falla aunque el correo no exista', () async {
      final controller = buildController();

      // El backend responde 200 siempre; la UI muestra un mensaje neutro.
      await controller.requestPasswordReset(email: 'nadie@test.com');
    });

    test('resetPassword con un código válido deja success', () async {
      final controller = buildController();

      await controller.resetPassword(
        email: demoEmail,
        code: '123456',
        newPassword: 'NuevaClave2026!',
      );

      expect(controller.profileStatus, ProfileUpdateStatus.success);
      expect(controller.profileErrorMessage, isNull);
    });

    test('resetPassword con un código inválido conserva el error', () async {
      final controller = buildController();

      Object? error;
      try {
        await controller.resetPassword(
          email: demoEmail,
          code: '000000',
          newPassword: 'NuevaClave2026!',
        );
      } catch (e) {
        error = e;
      }

      expect(error, isA<AuthException>());
      expect(controller.profileStatus, ProfileUpdateStatus.error);
      expect(controller.profileErrorMessage, 'El codigo es invalido o ha expirado');
    });
  });
}
