import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/flights/widgets/fare_details_sheet.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/travel_class.dart';
import 'package:royal_airlines/shared/widgets/fade_slide_in.dart';
import 'package:royal_airlines/shared/widgets/section_title.dart';

class FareSelector extends StatelessWidget {
  final FlightModel flight;
  final FareModel selected;
  final ValueChanged<FareModel> onChanged;

  const FareSelector({
    super.key,
    required this.flight,
    required this.selected,
    required this.onChanged,
  });

  Future<void> _openSheet(BuildContext context) async {
    final fare = await FareDetailsSheet.show(context, flight);
    if (fare != null) onChanged(fare);
  }

  @override
  Widget build(BuildContext context) {
    final visibleBenefits = selected.benefits.take(3).toList();
    final hiddenBenefits = selected.benefits.length - visibleBenefits.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Tarifa'),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Revisa beneficios, equipaje y flexibilidad antes de continuar.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              onTap: () => _openSheet(context),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  boxShadow: [...AppShadows.floating, ...AppShadows.goldGlow],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: const Icon(
                            Icons.airplane_ticket_rounded,
                            color: AppColors.primaryDark,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected.tierName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textOnPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                selected.travelClass.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textOnPrimary
                                      .withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.textOnPrimary.withValues(alpha: 0.14),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            selected.checkedBagKg > 0
                                ? 'Bodega ${selected.checkedBagKg}kg'
                                : 'Sin equipaje de bodega',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      CurrencyFormatter.cop(selected.price),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        ...visibleBenefits.map(
                          (benefit) => _BenefitChip(label: benefit),
                        ),
                        if (hiddenBenefits > 0)
                          _BenefitChip(label: '+$hiddenBenefits más'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Toca para comparar beneficios y cambiar de tarifa.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textOnPrimary
                                  .withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.textOnPrimary.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Cambiar',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold,
                                ),
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.gold,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String label;

  const _BenefitChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
