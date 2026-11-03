import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/features/favorites/controller/favorites_controller.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/services/favorites_service.dart';
import 'package:royal_airlines/shared/widgets/fade_slide_in.dart';

/// SavedScreen
/// -----------
/// Pantalla "Guardados" (Perfil → Tus viajes): lista los favoritos del
/// usuario con `GET /favorites` y permite quitar cualquiera con
/// `DELETE /favorites/{targetType}/{targetId}` desde el mismo icono.
///
/// La lista vive en el [FavoritesController] global (mismo estado que
/// los corazones del resto de la app): al entrar se refresca y, si el
/// usuario quita algo aquí, los corazones de Home/resultados se
/// actualizan solos.
///
/// El catálogo `GET /locations/` (cargado en segundo plano por el
/// controller) es el que traduce `targetId` → ciudad/país; mientras
/// no llegue, la fila muestra el id crudo sin romperse.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  Future<void> _remove(
    BuildContext context,
    FavoritesController controller,
    FavoriteItem item,
  ) async {
    // Se captura ANTES del await (contexto desmontado = crash).
    final messenger = ScaffoldMessenger.of(context);
    final error = await controller.toggle(item.targetType, item.targetId);
    if (error == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text(error),
      backgroundColor: AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FavoritesController>();

    // Refresco al entrar: por más que la sesión ya lo haya cargado,
    // otra pantalla pudo haber cambiado favoritos en el interín.
    if (controller.status == FavoritesStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) controller.load();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Guardados')),
      body: SafeArea(
        top: false,
        child: _buildBody(context, controller),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FavoritesController controller) {
    if (controller.isLoading && controller.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.4,
        ),
      );
    }

    if (controller.status == FavoritesStatus.error &&
        controller.items.isEmpty) {
      return _ErrorState(
        message: controller.errorMessage ??
            'No se pudieron cargar tus favoritos. Intenta de nuevo.',
        onRetry: controller.load,
      );
    }

    if (controller.items.isEmpty) {
      return const _EmptyState();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.lg,
          AppSpacing.screenPadding,
          AppSpacing.xxxl,
        ),
        itemCount: controller.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final item = controller.items[index];
          return FadeSlideIn(
            index: index,
            child: _SavedTile(
              item: item,
              airport: item.targetType == FavoriteTarget.destination
                  ? controller.airportFor(item.targetId)
                  : null,
              onRemove: () => _remove(context, controller, item),
            ),
          );
        },
      ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({
    required this.item,
    required this.airport,
    required this.onRemove,
  });

  final FavoriteItem item;
  final AirportModel? airport;
  final VoidCallback onRemove;

  bool get _isFlight => item.targetType == FavoriteTarget.flight;

  String get _title {
    if (_isFlight) return 'Vuelo guardado';
    return airport?.shortLabel ?? 'Destino guardado';
  }

  String get _subtitle {
    if (_isFlight) return 'Referencia ${item.targetId}';
    final airport = this.airport;
    if (airport == null) return 'Referencia ${item.targetId}';
    return '${airport.country} · ${airport.code}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isFlight
                      ? Icons.airplanemode_active_rounded
                      : Icons.favorite_rounded,
                  size: 21,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: 'Quitar de guardados',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.favorite_rounded,
                  size: 21,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 34,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Aún no guardas nada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Toca el corazón de un destino o vuelo y aparecerá aquí para encontrarlo rápido.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 38,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
