import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/services/push_notification_service.dart';

/// Doble en memoria de Firebase Messaging.
class FakePushGateway implements PushGateway {
  bool initializeFails = false;
  bool permissionGranted = false;
  bool askedPermission = false;
  bool tokenDeleted = false;
  String? token = 'tok:123-abc';
  final refresh = StreamController<String>.broadcast();

  @override
  Future<void> initialize() async {
    if (initializeFails) throw StateError('sin google-services.json');
  }

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async {
    askedPermission = true;
    return permissionGranted;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> deleteToken() async => tokenDeleted = true;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // SessionStorage (flutter_secure_storage) no tiene canal nativo en tests.
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => null);

  late FakePushGateway gateway;
  late List<http.Request> requests;
  late PushNotificationService service;

  setUp(() {
    gateway = FakePushGateway();
    requests = [];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('', 204);
    });
    service = PushNotificationService(
      client: ApiClient(baseUrl: 'http://test/api/v1', client: client),
      gateway: gateway,
      supported: true,
    );
  });

  test('sin permiso no registra nada ni toca la red', () async {
    expect(await service.registerIfPermitted(), isFalse);
    expect(requests, isEmpty);
    expect(gateway.askedPermission, isFalse);
  });

  test('con permiso concedido registra el token con PUT', () async {
    gateway.permissionGranted = true;

    expect(await service.registerIfPermitted(), isTrue);

    expect(requests, hasLength(1));
    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/api/v1/users/me/devices');
    expect(jsonDecode(requests.single.body),
        {'token': 'tok:123-abc', 'platform': 'android'});
  });

  test('requestPermissionAndRegister pide el permiso y respeta el rechazo', () async {
    expect(await service.requestPermissionAndRegister(), isFalse);
    expect(gateway.askedPermission, isTrue);
    expect(requests, isEmpty);
  });

  test('no repite el PUT si el token ya fue aceptado', () async {
    gateway.permissionGranted = true;

    await service.registerIfPermitted();
    await service.registerIfPermitted();

    expect(requests, hasLength(1));
  });

  test('si Firebase no está configurado todo es no-op y no lanza', () async {
    gateway.initializeFails = true;
    gateway.permissionGranted = true;

    expect(await service.registerIfPermitted(), isFalse);
    expect(service.isAvailable, isFalse);
    await service.unregister(); // no debe lanzar
    expect(requests, isEmpty);
  });

  test('plataforma no soportada: no inicializa ni registra', () async {
    final unsupported = PushNotificationService(
      client: ApiClient(baseUrl: 'http://test/api/v1', client: MockClient((_) async => http.Response('', 204))),
      gateway: gateway,
      supported: false,
    );
    gateway.permissionGranted = true;

    expect(await unsupported.registerIfPermitted(), isFalse);
    expect(unsupported.isAvailable, isFalse);
  });

  test('unregister da de baja el token con DELETE y lo borra del dispositivo', () async {
    gateway.permissionGranted = true;
    gateway.token = 'a:b/c';
    await service.registerIfPermitted();
    requests.clear();

    await service.unregister();

    expect(requests, hasLength(1));
    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.toString(), 'http://test/api/v1/users/me/devices/a%3Ab%2Fc');
    expect(gateway.tokenDeleted, isTrue);
  });

  test('unregister sin haber registrado nada no hace nada', () async {
    await service.unregister();

    expect(requests, isEmpty);
    expect(gateway.tokenDeleted, isFalse);
  });

  test('un token rotado se reenvía solo mientras hay sesión que quiere push', () async {
    gateway.permissionGranted = true;
    await service.registerIfPermitted();
    requests.clear();

    gateway.refresh.add('nuevo-token');
    await pumpEventQueue();
    expect(requests, hasLength(1));
    expect(jsonDecode(requests.single.body)['token'], 'nuevo-token');

    await service.unregister();
    requests.clear();
    gateway.refresh.add('otro-token');
    await pumpEventQueue();
    expect(requests, isEmpty);
  });

  test('si el backend falla el registro devuelve false y se puede reintentar', () async {
    var fail = true;
    final flaky = PushNotificationService(
      client: ApiClient(
        baseUrl: 'http://test/api/v1',
        client: MockClient((request) async =>
            fail ? http.Response('{"detail":"caído"}', 503) : http.Response('', 204)),
      ),
      gateway: gateway,
      supported: true,
    );
    gateway.permissionGranted = true;

    expect(await flaky.registerIfPermitted(), isFalse);
    fail = false;
    expect(await flaky.registerIfPermitted(), isTrue);
  });
}
