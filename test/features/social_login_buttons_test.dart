import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/features/auth/widgets/social_login_buttons.dart';
import 'package:royal_airlines/models/user_model.dart';
import 'package:royal_airlines/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prueba de UI de [SocialLoginButtons]: valida que los botones se
/// rendericen, que el éxito dispara la navegación, que un error del
/// backend se muestre junto a los botones (y no en el banner de login)
/// y que cancelar el diálogo no produzca ningún efecto visible.
void main() {
  final user = UserModel.fromJson({
    'id': 'usr_widget_1',
    'fullName': 'Pasajero Widget',
    'email': 'widget@test.com',
  });

  Future<void> pumpButtons(
    WidgetTester tester,
    AuthController controller, {
    required void Function() onSuccess,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SocialLoginButtons(onSuccess: onSuccess),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('muestra el divisor y los dos botones sociales', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AuthController(authService: _FakeAuthService());

    await pumpButtons(tester, controller, onSuccess: () {});

    expect(find.text('o continúa con'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con Apple'), findsOneWidget);
  });

  testWidgets(
      'Google con éxito navega con onSuccess y muestra spinner '
      'mientras carga', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final gate = Completer<UserModel>();
    final service = _FakeAuthService()..google = () => gate.future;
    final controller = AuthController(authService: service);
    var success = false;

    await pumpButtons(tester, controller, onSuccess: () => success = true);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();

    // Mientras el proveedor responde: spinner dentro del botón activo.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(success, isFalse);

    gate.complete(user);
    await tester.pump();
    await tester.pump();

    expect(success, isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'error del backend se muestra junto a los botones y NO '
      'navega', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeAuthService()
      ..google = () async => throw const AuthException('Token inválido');
    final controller = AuthController(authService: service);
    var success = false;

    await pumpButtons(tester, controller, onSuccess: () => success = true);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Token inválido'), findsOneWidget);
    expect(success, isFalse);
  });

  testWidgets('cancelar el diálogo de Apple no muestra error ni navega',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeAuthService()..apple = () async => null;
    final controller = AuthController(authService: service);
    var success = false;

    await pumpButtons(tester, controller, onSuccess: () => success = true);

    await tester.tap(find.text('Continuar con Apple'));
    await tester.pump();
    await tester.pump();

    expect(success, isFalse);
    expect(find.textContaining('Intenta'), findsNothing);
    expect(controller.socialErrorMessage, isNull);
  });
}

class _FakeAuthService extends AuthService {
  Future<UserModel?> Function()? google;
  Future<UserModel?> Function()? apple;

  @override
  Future<UserModel?> signInWithGoogle() => google!();

  @override
  Future<UserModel?> signInWithApple() => apple!();
}
