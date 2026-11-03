import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/shared/widgets/section_title.dart';

class TravelExtrasSelector extends StatelessWidget {
  final bool hasTravelInsurance;
  final bool hasPriorityBoarding;
  final ValueChanged<bool> onTravelInsuranceChanged;
  final ValueChanged<bool> onPriorityBoardingChanged;

  const TravelExtrasSelector({
    super.key,
    required this.hasTravelInsurance,
    required this.hasPriorityBoarding,
    required this.onTravelInsuranceChanged,
    required this.onPriorityBoardingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Extras de viaje'),
        const SizedBox(height: AppSpacing.md),
        _ExtraCard(
          title: 'Seguro de viaje',
          subtitle: 'Cobertura por inconvenientes y cambios de vuelo',
          price: 25000,
          enabled: hasTravelInsurance,
          onChanged: onTravelInsuranceChanged,
          icon: Icons.shield_rounded,
        ),
        const SizedBox(height: AppSpacing.sm),
        _ExtraCard(
          title: 'Embarque prioritario',
          subtitle: 'Zona express y prioridad en la fila',
          price: 18000,
          enabled: hasPriorityBoarding,
          onChanged: onPriorityBoardingChanged,
          icon: Icons.priority_high_rounded,
        ),
      ],
    );
  }
}

class _ExtraCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double price;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const _ExtraCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.enabled,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled
              ? AppColors.gold.withValues(alpha: 0.45)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: enabled ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${CurrencyFormatter.cop(price)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Switch.adaptive(
                value: enabled,
                activeThumbColor: AppColors.gold,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.28),
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
