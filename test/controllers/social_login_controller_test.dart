import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/models/user_model.dart';
import 'package:royal_airlines/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pruebas del login social (Google/Apple).
///
/// El diálogo nativo NO se ejecuta en tests, así que se cubren las dos
/// mitades por separado:
/// 1. [AuthController] con un AuthService falso (éxito, cancelación,
///    error y estados de carga).
/// 2. [AuthService.completeSocialLogin] con [MockClient]: el contrato
///    HTTP real de `POST /auth/google` y `POST /auth/apple`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    SharedPreferences.setMockInitialValues({});
    secureStorageValues.clear();
  });

  final socialUser = UserModel.fromJson({
    'id': 'usr_social_1',
    'fullName': 'Pasajero Social',
    'email': 'pasajero@gmail.com',
  });

  group('AuthController - login social', () {
    test('Google: éxito deja autenticado y sin error social', () async {
      final service = _FakeAuthService()..google = () async => socialUser;
      final controller = AuthController(authService: service);

      await controller.loginWithGoogle();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.currentUser?.email, 'pasajero@gmail.com');
      expect(controller.socialErrorMessage, isNull);
      expect(controller.isSocialLoading, isFalse);
    });

    test('Google: cancelar el diálogo no muestra error ni cambia estado',
        () async {
      final service = _FakeAuthService()..google = () async => null;
      final controller = AuthController(authService: service);

      await controller.loginWithGoogle();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.socialErrorMessage, isNull);
      expect(controller.status, AuthStatus.idle);
    });

    test(
        'Google: un error del backend va a socialErrorMessage y NO al '
        'status (evita el banner con errorMessage nulo)', () async {
      final service = _FakeAuthService()
        ..google =
            () async => throw const AuthException('Token de Google inválido');
      final controller = AuthController(authService: service);

      await controller.loginWithGoogle();

      expect(controller.socialErrorMessage, 'Token de Google inválido');
      expect(controller.isAuthenticated, isFalse);
      expect(controller.status, AuthStatus.idle);
      expect(controller.isSocialLoading, isFalse);
    });

    test('Apple: éxito deja autenticado igual que Google', () async {
      final service = _FakeAuthService()..apple = () async => socialUser;
      final controller = AuthController(authService: service);

      await controller.loginWithApple();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.socialErrorMessage, isNull);
    });

    test('la bandera de carga está activa mientras el proveedor responde',
        () async {
      late AuthController controller;
      var loadingDuringSignIn = false;
      final service = _FakeAuthService()
        ..google = () async {
          loadingDuringSignIn = controller.isSocialLoading;
          return socialUser;
        };
      controller = AuthController(authService: service);

      await controller.loginWithGoogle();

      expect(loadingDuringSignIn, isTrue);
      expect(controller.isSocialLoading, isFalse);
    });

    test('un segundo intento mientras carga se ignora', () async {
      var calls = 0;
      final gate = Completer<UserModel?>();
      final service = _FakeAuthService()
        ..google = () {
          calls++;
          return gate.future;
        };
      final controller = AuthController(authService: service);

      final first = controller.loginWithGoogle();
      final second = controller.loginWithGoogle();
      gate.complete(socialUser);
      await Future.wait([first, second]);

      expect(calls, 1);
      expect(controller.isAuthenticated, isTrue);
    });
  });

  group('AuthService.completeSocialLogin - contrato HTTP', () {
    AuthService buildService(MockClient client) => AuthService(
          apiClient: ApiClient(
            baseUrl: 'http://localhost:8080/v1',
            client: client,
          ),
        );

    http.Response successResponse() => http.Response(
          jsonEncode({
            'success': true,
            'message': 'Login exitoso',
            'data': {
              'token': 'token-social-123',
              'user': {
                'id': 'usr_social_1',
                'fullName': 'Pasajero Social',
                'email': 'pasajero@gmail.com',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

    test('POST /auth/google envía identityToken y guarda el token', () async {
      http.Request? captured;
      final service = buildService(MockClient((request) async {
        captured = request;
        return successResponse();
      }));

      final user = await service.completeSocialLogin(
        endpoint: '/auth/google',
        identityToken: 'jwt.de.google',
      );

      expect(captured!.method, 'POST');
      expect(captured!.url.path, endsWith('/auth/google'));
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['identityToken'], 'jwt.de.google');
      expect(body.containsKey('fullName'), isFalse);
      expect(user.email, 'pasajero@gmail.com');
      expect(secureStorageValues['session_access_token'], 'token-social-123');
    });

    test('POST /auth/apple incluye fullName cuando el proveedor lo da',
        () async {
      http.Request? captured;
      final service = buildService(MockClient((request) async {
        captured = request;
        return successResponse();
      }));

      await service.completeSocialLogin(
        endpoint: '/auth/apple',
        identityToken: 'jwt.de.apple',
        fullName: 'Ada Lovelace',
      );

      expect(captured!.url.path, endsWith('/auth/apple'));
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['identityToken'], 'jwt.de.apple');
      expect(body['fullName'], 'Ada Lovelace');
    });

    test(
        'un token rechazado por el backend se vuelve AuthException con '
        'statusCode', () async {
      final service = buildService(MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Token de google inválido',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      }));

      await expectLater(
        service.completeSocialLogin(
          endpoint: '/auth/google',
          identityToken: 'jwt.falsificado',
        ),
        throwsA(
          isA<AuthException>()
              .having((e) => e.message, 'message', 'Token de google inválido')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });
}

/// AuthService con los diálogos nativos reemplazados por funciones
/// controladas por el test (éxito, `null` de cancelación o error).
class _FakeAuthService extends AuthService {
  Future<UserModel?> Function()? google;
  Future<UserModel?> Function()? apple;

  @override
  Future<UserModel?> signInWithGoogle() => google!();

  @override
  Future<UserModel?> signInWithApple() => apple!();
}
