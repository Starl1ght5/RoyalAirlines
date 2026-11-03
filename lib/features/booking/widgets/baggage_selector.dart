import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/booking/widgets/baggage_option.dart';
import 'package:royal_airlines/shared/widgets/section_title.dart';

class BaggageSelector extends StatelessWidget {
  final BaggageOption selected;
  final ValueChanged<BaggageOption> onChanged;

  const BaggageSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Equipaje'),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Selecciona la franquicia ideal para tu viaje.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: BaggageOption.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final option = BaggageOption.values[index];
              return SizedBox(
                width: 176,
                child: _BaggageOptionCard(
                  option: option,
                  isSelected: option == selected,
                  onTap: () => onChanged(option),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BaggageOptionCard extends StatelessWidget {
  final BaggageOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _BaggageOptionCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  String get _description {
    switch (option) {
      case BaggageOption.included:
        return 'Perfecto para escapadas ligeras.';
      case BaggageOption.extra10kg:
        return 'Más flexibilidad para viajes cortos.';
      case BaggageOption.extra20kg:
        return 'Espacio extra para estadías largas.';
    }
  }

  IconData get _icon {
    switch (option) {
      case BaggageOption.included:
        return Icons.work_outline_rounded;
      case BaggageOption.extra10kg:
        return Icons.luggage_rounded;
      case BaggageOption.extra20kg:
        return Icons.luggage_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 200,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.glassGradient : null,
            color: isSelected ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isSelected ? AppColors.gold : AppColors.border,
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? [...AppShadows.card, ...AppShadows.goldGlow]
                : AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.goldGradient : null,
                      color: isSelected
                          ? null
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(
                      _icon,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.gold.withValues(alpha: 0.18)
                              : AppColors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          option.price == 0 ? 'Incluido' : 'Upgrade',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                option.price == 0
                    ? 'Sin costo adicional'
                    : '+${CurrencyFormatter.cop(option.price)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
