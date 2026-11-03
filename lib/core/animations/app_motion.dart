import 'package:flutter/material.dart';

/// AppMotion
/// ---------
/// Fuente única de duraciones y curvas de animación de la app. Evita
/// que cada widget invente su propio timing (150ms aquí, 300ms allá),
/// lo que hace que la app se sienta inconsistente. Todo lo animado
/// (entradas de pantalla, taps, transiciones) referencia esta clase.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 500);

  /// Curva estándar para casi todo: entra rápido, frena suave.
  static const Curve standard = Curves.easeOutCubic;

  /// Curva con un pequeño "rebote" al final, para elementos que
  /// quieres que se sientan más vivos (logos, botones al confirmar).
  static const Curve emphasized = Curves.easeOutBack;

  /// Retraso entre elementos de una animación escalonada (stagger),
  /// ej. los campos de un formulario apareciendo uno tras otro.
  static const Duration staggerStep = Duration(milliseconds: 60);

  /// Retraso acumulado para el elemento `index` de una lista con
  /// animación escalonada, con un tope para que listas largas no
  /// tarden demasiado en terminar de aparecer.
  static Duration staggerDelay(int index, {int maxSteps = 8}) {
    final clampedIndex = index > maxSteps ? maxSteps : index;
    return staggerStep * clampedIndex;
  }
}
