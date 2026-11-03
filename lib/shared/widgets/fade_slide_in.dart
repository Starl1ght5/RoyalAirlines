import 'package:flutter/material.dart';
import 'package:royal_airlines/core/animations/app_motion.dart';

/// FadeSlideIn
/// -----------
/// Animación de entrada estándar (fade sutil) para tarjetas y elementos
/// de lista en toda la app. Centraliza el patrón que antes se repetía
/// manualmente en cada pantalla, permitiendo un `index` para lograr un
/// efecto "stagger" (escalonado) barato en CPU.
///
/// Uso típico dentro de un `ListView`/`Column`:
/// ```dart
/// FadeSlideIn(index: i, child: MyCard(...))
/// ```
///
/// NOTA: Se usa solo `Opacity` (sin slide) porque `Transform.translate` y
/// `SlideTransition` pueden causar errores de layout cuando se anidan
/// dentro de scrolls combinados con otros widgets que modifican
/// restricciones de tamaño.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = AppMotion.medium,
    this.offsetY = 18,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standard,
    );

    final delay = AppMotion.staggerDelay(widget.index);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}
