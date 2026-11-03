import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/favorites/widgets/favorite_button.dart';
import 'package:royal_airlines/models/recommendation_model.dart';

/// RecommendationCard
/// ------------------
/// Tarjeta de UN destino recomendado dentro de la sección "Recomendado
/// para ti". Muestra el índice de afinidad como número grande (el
/// "tanto porcentaje" del audio), las etiquetas del destino y las
/// razones explicables del match. Al tocarla abre el bottom sheet con
/// el desglose completo y el radar.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.result,
    required this.onTap,
  });

  final RecommendationResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final destination = result.destination;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              destination.city,
                              overflow: TextOverflow.ellipsis,
                              style: theme.titleLarge?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ) ??
                                  const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (!destination.isBookable) const _SoonBadge(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destination.country,
                        style: theme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ) ??
                            const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // El id REAL (`Location.locationID`) viene en el
                // resultado cuando la lista es del backend; el motor
                // local no lo conoce y el corazón resuelve el id por
                // `code` contra el catálogo del FavoritesController.
                FavoriteButton(
                  hint: result.locationId,
                  code: destination.code,
                  tooltip: 'Guardar destino',
                ),
                const SizedBox(width: AppSpacing.xs),
                _AffinityBadge(percent: result.affinityPercent),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final interest in destination.prominentInterests.take(3))
                  _InterestTag(label: interest.label),
              ],
            ),
            // Precio solo si el perfil lo conoce: los destinos que
            // vienen del backend sin catálogo curado no tienen
            // precio promedio y "COP 0" sería mentira.
            if (destination.averagePriceCop > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 15,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Desde ${CurrencyFormatter.cop(destination.averagePriceCop)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            if (result.reasons.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final reason in result.reasons.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Ver análisis completo',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.primary.withValues(alpha: 0.9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AffinityBadge extends StatelessWidget {
  const _AffinityBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = switch (percent) {
      >= 70 => AppColors.success,
      >= 45 => AppColors.info,
      _ => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const Text(
            'afinidad',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestTag extends StatelessWidget {
  const _InterestTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: const Text(
        'Próximamente',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.warning,
        ),
      ),
    );
  }
}
