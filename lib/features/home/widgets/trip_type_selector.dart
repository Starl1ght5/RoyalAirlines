import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart';

/// TripTypeSelector
/// ----------------
/// Control segmentado "Ida y vuelta" / "Solo ida". Widget puramente
/// controlado: no maneja su propio estado, refleja [selected] y
/// notifica cambios vía [onChanged] — el estado real vive en
/// [HomeController].
class TripTypeSelector extends StatelessWidget {
  final TripType selected;
  final ValueChanged<TripType> onChanged;

  const TripTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: 'Ida y vuelta',
            isSelected: selected == TripType.roundTrip,
            onTap: () => onChanged(TripType.roundTrip),
          ),
          _SegmentButton(
            label: 'Solo ida',
            isSelected: selected == TripType.oneWay,
            onTap: () => onChanged(TripType.oneWay),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.sm + 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
