import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart';
import 'package:royal_airlines/features/home/widgets/selector_field.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// PassengerSelector
/// -----------------
/// Selector que abre un bottom sheet con contadores de
/// adultos/niños/infantes. Espaciados ajustados a [AppSpacing].
class PassengerSelector extends StatelessWidget {
  final PassengerCount value;
  final ValueChanged<PassengerCount> onChanged;

  const PassengerSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  void _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<PassengerCount>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PassengerSheet(initialValue: value),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return SelectorField(
      icon: Icons.people_outline_rounded,
      label: 'Pasajeros',
      value: value.summary,
      onTap: () => _openSheet(context),
    );
  }
}

class _PassengerSheet extends StatefulWidget {
  final PassengerCount initialValue;
  const _PassengerSheet({required this.initialValue});

  @override
  State<_PassengerSheet> createState() => _PassengerSheetState();
}

class _PassengerSheetState extends State<_PassengerSheet> {
  late PassengerCount _count = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        14,
        AppSpacing.xxl,
        MediaQuery.of(context).padding.bottom + AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Pasajeros',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _CounterRow(
            label: 'Adultos',
            subtitle: '12 años o más',
            count: _count.adults,
            minValue: 1,
            onChanged: (v) =>
                setState(() => _count = _count.copyWith(adults: v)),
          ),
          _CounterRow(
            label: 'Niños',
            subtitle: '2 a 11 años',
            count: _count.children,
            onChanged: (v) =>
                setState(() => _count = _count.copyWith(children: v)),
          ),
          _CounterRow(
            label: 'Infantes',
            subtitle: 'Menores de 2 años',
            count: _count.infants,
            onChanged: (v) =>
                setState(() => _count = _count.copyWith(infants: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          CustomButton(
            label: 'Aplicar',
            onPressed: () => Navigator.of(context).pop(_count),
          ),
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final int count;
  final int minValue;
  final ValueChanged<int> onChanged;

  const _CounterRow({
    required this.label,
    required this.subtitle,
    required this.count,
    required this.onChanged,
    this.minValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                onPressed: count > minValue ? () => onChanged(count - 1) : null,
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                onPressed: count < 9 ? () => onChanged(count + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _StepButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    return Material(
      color: isEnabled
          ? AppColors.surfaceVariant
          : AppColors.surfaceVariant.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppSpacing.sm + 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.sm + 1),
        onTap: onPressed,
        child: SizedBox(
          width: 31,
          height: 31,
          child: Icon(
            icon,
            size: 15,
            color: isEnabled ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
