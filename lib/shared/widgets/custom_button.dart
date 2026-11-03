import 'package:flutter/material.dart';
import 'package:royal_airlines/core/animations/app_motion.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';

/// Variante visual de [CustomButton]. `primary` es el CTA principal con
/// gradiente de marca; `secondary` es una acción de menor jerarquía
/// (cancelar, volver) con contorno sutil y fondo transparente, para no
/// competir visualmente con el botón principal de la pantalla.
enum CustomButtonVariant { primary, secondary }

/// Botón principal con gradiente de marca y brillo dorado en el borde
/// — mucho más llamativo que un color plano. El "glow" (sombra de
/// color) se intensifica ligeramente al presionar, dando sensación de
/// respuesta táctil premium.
class CustomButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final CustomButtonVariant variant;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = CustomButtonVariant.primary,
    this.icon,
  });

  /// Acción secundaria (contorno, sin relleno) — misma altura y radio
  /// que el CTA principal para que ambos se alineen en pantalla.
  const CustomButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : variant = CustomButtonVariant.secondary;

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (!_isEnabled) return;
    setState(() => _isPressed = value);
  }

  bool get _isSecondary => widget.variant == CustomButtonVariant.secondary;

  @override
  Widget build(BuildContext context) {
    final labelColor = _isSecondary
        ? (_isEnabled ? AppColors.primary : AppColors.textTertiary)
        : AppColors.textOnPrimary;

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _isEnabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: double.infinity,
            constraints:
                const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
            height: 54,
            decoration: BoxDecoration(
              gradient: _isSecondary
                  ? null
                  : _isEnabled
                      ? const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppColors.primaryDark,
                            AppColors.primary,
                            AppColors.primaryLight
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.4),
                            AppColors.primary.withValues(alpha: 0.4),
                          ],
                        ),
              color: _isSecondary
                  ? (_isPressed ? AppColors.surfaceVariant : AppColors.surface)
                  : null,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: _isSecondary
                    ? AppColors.border
                    : _isEnabled
                        ? AppColors.gold
                            .withValues(alpha: _isPressed ? 0.9 : 0.55)
                        : Colors.transparent,
                width: _isSecondary ? 1.4 : 1.3,
              ),
              boxShadow: !_isEnabled
                  ? null
                  : _isSecondary
                      ? AppShadows.card
                      : [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: _isPressed ? 0.4 : 0.28),
                            blurRadius: _isPressed ? 10 : 18,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: AppColors.gold
                                .withValues(alpha: _isPressed ? 0.28 : 0.15),
                            blurRadius: 14,
                            spreadRadius: -2,
                          ),
                        ],
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              switchInCurve: AppMotion.standard,
              switchOutCurve: AppMotion.standard,
              child: widget.isLoading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(
                          _isSecondary ? AppColors.primary : AppColors.gold,
                        ),
                      ),
                    )
                  : Row(
                      key: const ValueKey('label'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 18, color: labelColor),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
