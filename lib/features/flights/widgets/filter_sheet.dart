import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/features/flights/controller/flight_controller.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// FilterSheet
/// -----------
/// Bottom sheet de ordenar/filtrar. Handle superior agregado (barra
/// gris) para consistencia visual con el resto de sheets de la app.
class FilterSheet extends StatefulWidget {
  final SortOption initialSort;
  final StopsFilter initialStops;

  const FilterSheet({
    super.key,
    required this.initialSort,
    required this.initialStops,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late SortOption _sort = widget.initialSort;
  late StopsFilter _stops = widget.initialStops;

  static const Map<SortOption, String> _sortLabels = {
    SortOption.priceAsc: 'Precio: menor a mayor',
    SortOption.priceDesc: 'Precio: mayor a menor',
    SortOption.duration: 'Duración más corta',
    SortOption.earliestDeparture: 'Salida más temprana',
  };

  static const Map<StopsFilter, String> _stopsLabels = {
    StopsFilter.all: 'Todos',
    StopsFilter.direct: 'Solo directos',
    StopsFilter.oneStop: 'Hasta 1 escala',
  };

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
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Ordenar y filtrar',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SubHeading('Ordenar por'),
          const SizedBox(height: AppSpacing.sm),
          ...SortOption.values.map(
            (option) => _RadioTile(
              label: _sortLabels[option]!,
              isSelected: _sort == option,
              onTap: () => setState(() => _sort = option),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SubHeading('Escalas'),
          const SizedBox(height: AppSpacing.sm),
          ...StopsFilter.values.map(
            (option) => _RadioTile(
              label: _stopsLabels[option]!,
              isSelected: _stops == option,
              onTap: () => setState(() => _stops = option),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          CustomButton(
            label: 'Aplicar filtros',
            onPressed: () => Navigator.of(context).pop((_sort, _stops)),
          ),
        ],
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  final String text;
  const _SubHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _RadioTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RadioTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 19,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
