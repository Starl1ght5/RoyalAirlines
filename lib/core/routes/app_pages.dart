import 'package:flutter/material.dart';
import 'package:royal_airlines/core/routes/app_routes.dart';
import 'package:royal_airlines/features/auth/screens/login_screen.dart';
import 'package:royal_airlines/features/auth/screens/register_screen.dart';
import 'package:royal_airlines/navigation/main_navigation.dart';

/// AppPages
/// --------
/// Traduce cada [AppRoutes] (el "nombre") a su pantalla real (el
/// "builder"). Separar esto de `app_routes.dart` permite que otros
/// archivos (como [LoginForm]) importen solo los nombres de ruta sin
/// arrastrar-importar todas las pantallas de la app (evita ciclos de
/// importación y acopla menos).
class AppPages {
  AppPages._();

  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.main: (_) => const MainNavigation(),
      };
}
