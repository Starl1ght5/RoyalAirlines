import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/features/favorites/controller/favorites_controller.dart';
import 'package:royal_airlines/services/favorites_service.dart';

// Reexporta el enum para que las tarjetas puedan declarar
// `FavoriteTarget.flight` importando solo este archivo.
export 'package:royal_airlines/services/favorites_service.dart'
    show FavoriteTarget;

/// FavoriteButton
/// --------------
/// Corazón de favorito reutilizable para tarjetas de destino, hojas de
/// recomendación y tarjetas de vuelo.
///
/// Identidad del favorito: el backend exige `Location.locationID` (id
/// de MongoDB) o `Flight.flightID`, NUNCA el código IATA. Por eso el
/// widget acepta [hint] (el id si la tarjeta ya lo conoce) y [code]
/// (el IATA), y resuelve el id real con el catálogo del
/// [FavoritesController].
///
/// El toggle es optimista (ver [FavoritesController.toggle]): el
/// corazón cambia al instante y, si el servidor responde con error
/// (404 id inexistente, 409 límite de 200, sin red...), se revierte y
/// se avisa con un SnackBar.
///
/// OJO: aquí NO se llama a `track()`. Los eventos `favorite_add` /
/// `favorite_remove` los emite el servidor.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    this.hint,
    this.code = '',
    this.targetType = FavoriteTarget.destination,
    this.size = 20,
    this.chip = false,
    this.inactiveColor,
    this.activeColor = AppColors.error,
    this.tooltip = 'Guardar en favoritos',
  });

  /// `Location.locationID` o `Flight.flightID` si la tarjeta ya lo
  /// tiene. Si es `null` se resuelve con [code] vía catálogo.
  final String? hint;

  /// Código IATA del destino (solo destinos): usado para resolver el
  /// `locationId` cuando no hay [hint].
  final String code;

  /// Tipo de favorito: destino (por defecto) o vuelo.
  final FavoriteTarget targetType;

  /// Tamaño del icono.
  final double size;

  /// Si es `true` dibuja el icono dentro de un círculo semitransparente
  /// (para tarjetas con foto de fondo); si es `false` solo el icono.
  final bool chip;

  /// Color del corazón inactivo. Por defecto `textSecondary`; en
  /// tarjetas con imagen/fondo oscuro se pasa blanco.
  final Color? inactiveColor;

  /// Color del corazón activo (relleno).
  final Color activeColor;

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FavoritesController>();
    final targetId = controller.resolveLocationId(code, hint: hint);

    // Sin id resuelto el corazón queda inactivo y NO hace nada: mejor
    // no ofrecer guardar algo que el backend rechazaría con 404.
    final favorite = targetId != null &&
        targetId.isNotEmpty &&
        controller.isFavorite(targetType, targetId);

    final icon = Icon(
      favorite ? Icons.favorite : Icons.favorite_border_rounded,
      size: size,
      color:
          favorite ? activeColor : (inactiveColor ?? AppColors.textSecondary),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: targetId == null || targetId.isEmpty
            ? null
            : () => _toggle(context, controller, targetId),
        child: tooltip.isEmpty
            ? _child(icon)
            : Tooltip(
                message: tooltip,
                child: _child(icon),
              ),
      ),
    );
  }

  Widget _child(Icon icon) {
    if (!chip) return icon;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        shape: BoxShape.circle,
      ),
      child: icon,
    );
  }

  Future<void> _toggle(
    BuildContext context,
    FavoritesController controller,
    String targetId,
  ) async {
    // Se captura ANTES del await: con el contexto desmontado,
    // `ScaffoldMessenger.of` lanzaría.
    final messenger = ScaffoldMessenger.of(context);
    final error = await controller.toggle(targetType, targetId);
    if (error == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text(error),
      backgroundColor: AppColors.error,
    ));
  }
}
