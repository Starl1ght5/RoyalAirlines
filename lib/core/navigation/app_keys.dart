import 'package:flutter/material.dart';

/// Llaves globales de la app. Permiten navegar y mostrar avisos desde fuera del
/// árbol de widgets (p. ej. al tocar una notificación push). Se registran en el
/// `MaterialApp` de `app.dart`.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
