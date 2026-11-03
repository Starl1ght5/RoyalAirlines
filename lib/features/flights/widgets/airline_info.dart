import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';

/// AirlineInfo
/// -----------
/// Bloque visual de marca para la aerolínea dentro de tarjetas premium.
class AirlineInfo extends StatelessWidget {
  final String airline;
  final String flightNumber;

  const AirlineInfo({
    super.key,
    required this.airline,
    required this.flightNumber,
  });

  static String _airlineInitials(String airline) {
    final words = airline
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'RA';
    if (words.length == 1) {
      final word = words.first.toUpperCase();
      return word.length >= 2 ? word.substring(0, 2) : word;
    }

    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _airlineInitials(airline);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.glassOverlay,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.34),
            ),
            boxShadow: AppShadows.goldGlow,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.textOnPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                airline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.14),
                  ),
                ),
                child: Text(
                  flightNumber,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
