import 'package:flutter/material.dart';
import 'package:royal_airlines/core/animations/app_motion.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/models/seat_map_model.dart';
import 'package:royal_airlines/models/seat_pricing.dart';
import 'package:royal_airlines/shared/widgets/fade_slide_in.dart';

Color _fillFor(SeatCategory category) {
  switch (category) {
    case SeatCategory.preferente:
      return AppColors.goldLight.withValues(alpha: 0.5);
    case SeatCategory.estandarPlus:
      return AppColors.info.withValues(alpha: 0.16);
    case SeatCategory.estandar:
      return AppColors.surfaceVariant;
  }
}

Color _borderFor(SeatCategory category) {
  switch (category) {
    case SeatCategory.preferente:
      return AppColors.gold.withValues(alpha: 0.8);
    case SeatCategory.estandarPlus:
      return AppColors.info.withValues(alpha: 0.55);
    case SeatCategory.estandar:
      return AppColors.border;
  }
}

/// SeatSelector
/// -------------
/// Mapa de asientos de UN vuelo, pintado con los datos REALES de
/// [SeatMapModel] (`GET /flights/{flightId}/seats`): el backend manda
/// la distribución de la cabina, los precios por categoría en COP, las
/// filas con espacio extra y qué asientos ya están tomados (retenidos
/// o confirmados). No se genera ninguna ocupación localmente.
class SeatSelector extends StatelessWidget {
  final SeatMapModel seatMap;
  final List<String> selectedSeats;
  final int requiredSeatCount;
  final ValueChanged<String> onSeatTapped;

  const SeatSelector({
    super.key,
    required this.seatMap,
    required this.selectedSeats,
    required this.requiredSeatCount,
    required this.onSeatTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FadeSlideIn(
          child: _SelectionHeader(),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(
          index: 1,
          child: _LegendPanel(
            selectedCount: selectedSeats.length,
            requiredCount: requiredSeatCount,
            seatsLeft: seatMap.seatsLeft,
            categories: seatMap.categories,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FadeSlideIn(
          index: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.glassGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSpacing.radiusXl),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color:
                              AppColors.textOnPrimary.withValues(alpha: 0.14),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Icon(
                          Icons.flight_rounded,
                          size: 16,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Column(
                        children: [
                          Text(
                            'FRENTE DE LA CABINA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: AppColors.gold,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            'Toca para seleccionar o cambiar tu asiento',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _SeatGrid(
                  seatMap: seatMap,
                  selectedSeats: selectedSeats,
                  onSeatTapped: onSeatTapped,
                ),
              ],
            ),
          ),
        ),
        if (selectedSeats.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: 3,
            child: _SelectedSeatsSummary(
              seatCodes: selectedSeats,
              seatMap: seatMap,
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: const Icon(
            Icons.event_seat_rounded,
            color: AppColors.gold,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona tus asientos',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'La disponibilidad es la del vuelo en tiempo real y cada selección se refleja en el total.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendPanel extends StatelessWidget {
  final int selectedCount;
  final int requiredCount;
  final int seatsLeft;
  final List<SeatMapCategory> categories;

  const _LegendPanel({
    required this.selectedCount,
    required this.requiredCount,
    required this.seatsLeft,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final completed = selectedCount == requiredCount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: completed
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  '$selectedCount de $requiredCount seleccionados',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: completed ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                completed ? 'Listo para continuar' : 'Elige todos tus asientos',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$seatsLeft asientos libres en este vuelo',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _LegendStatusItem(
                icon: Icons.event_seat_outlined,
                color: AppColors.surfaceVariant,
                borderColor: AppColors.border,
                label: 'Disponible',
              ),
              _LegendStatusItem(
                icon: Icons.check_rounded,
                color: AppColors.gold,
                borderColor: AppColors.gold,
                label: 'Seleccionado',
              ),
              _LegendStatusItem(
                icon: Icons.close_rounded,
                color: AppColors.divider,
                borderColor: AppColors.border,
                label: 'Ocupado',
              ),
              _LegendStatusItem(
                icon: Icons.height_rounded,
                color: AppColors.info,
                borderColor: AppColors.info,
                label: 'Espacio extra',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: categories
                .map(
                  (category) => _CategoryChip(category: category),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SeatGrid extends StatelessWidget {
  final SeatMapModel seatMap;
  final List<String> selectedSeats;
  final ValueChanged<String> onSeatTapped;

  const _SeatGrid({
    required this.seatMap,
    required this.selectedSeats,
    required this.onSeatTapped,
  });

  Widget _cell(String code, {required bool isHeader}) {
    final aisle = code == 'D';
    return Padding(
      padding: EdgeInsets.only(left: aisle ? 24 : 6, right: 6),
      child: SizedBox(
        width: 32,
        child: isHeader
            ? Text(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTertiary,
                ),
              )
            : null,
      ),
    );
  }

  /// Etiqueta de zona que precede a una fila, según los rangos que
  /// manda el backend: cada categoría (menos la primera) abre su zona
  /// con un divisor.
  String? _zoneLabelForRow(int row) {
    for (var i = 1; i < seatMap.categories.length; i++) {
      if (seatMap.categories[i].containsRow(row)) {
        return seatMap.categories[i].category.label;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final columns = seatMap.columns;
    final taken = seatMap.takenSeats;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 26),
                ...columns.map((column) => _cell(column, isHeader: true)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...List.generate(seatMap.rows, (index) {
              final row = index + 1;
              final zoneLabel = _zoneLabelForRow(row);
              return Column(
                children: [
                  if (zoneLabel != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _ZoneDivider(label: zoneLabel),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 26,
                          child: Row(
                            children: [
                              Text(
                                '$row',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              if (seatMap.hasExtraLegroom(row))
                                const Tooltip(
                                  message: 'Espacio extra para las piernas',
                                  child: Icon(
                                    Icons.height_rounded,
                                    size: 11,
                                    color: AppColors.info,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ...columns.map((column) {
                          final code = '$row$column';
                          final aisle = column == 'D';
                          final category = seatMap.categoryForRow(row);
                          return Padding(
                            padding: EdgeInsets.only(
                              left: aisle ? 24 : 6,
                              right: 6,
                            ),
                            child: _SeatCell(
                              isOccupied: taken.contains(code),
                              isSelected: selectedSeats.contains(code),
                              category: category.category,
                              onTap: () => onSeatTapped(code),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SeatCell extends StatelessWidget {
  final bool isOccupied;
  final bool isSelected;
  final SeatCategory category;
  final VoidCallback onTap;

  const _SeatCell({
    required this.isOccupied,
    required this.isSelected,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOccupied ? null : onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: AnimatedScale(
          scale: 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.emphasized,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isSelected ? AppColors.goldGradient : null,
              color: isSelected
                  ? null
                  : (isOccupied ? AppColors.divider : _fillFor(category)),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: isSelected
                    ? AppColors.gold
                    : (isOccupied ? AppColors.border : _borderFor(category)),
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: isSelected ? [...AppShadows.goldGlow] : null,
            ),
            child: isSelected
                ? const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: AppColors.primaryDark,
                  )
                : isOccupied
                    ? const Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: AppColors.textTertiary,
                      )
                    : null,
          ),
        ),
      ),
    );
  }
}

class _SelectedSeatsSummary extends StatelessWidget {
  final List<String> seatCodes;
  final SeatMapModel seatMap;

  const _SelectedSeatsSummary({
    required this.seatCodes,
    required this.seatMap,
  });

  @override
  Widget build(BuildContext context) {
    final sortedCodes = [...seatCodes]..sort();
    final total = sortedCodes.fold<double>(
      0,
      (sum, code) => sum + seatMap.priceForSeat(code),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        boxShadow: [...AppShadows.card, ...AppShadows.goldGlow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Asientos seleccionados',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Puedes tocar cualquier asiento nuevamente para liberarlo.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: sortedCodes.map((code) {
              final seatCategory = seatMap.categoryForSeat(code);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${seatCategory.category.label} · ${CurrencyFormatter.cop(seatCategory.price)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cargo total por asientos',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ),
                Text(
                  CurrencyFormatter.cop(total),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendStatusItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color borderColor;
  final String label;

  const _LegendStatusItem({
    required this.icon,
    required this.color,
    required this.borderColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, size: 12, color: AppColors.primaryDark),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final SeatMapCategory category;

  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _fillFor(category.category),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _borderFor(category.category)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${category.category.label} · ${CurrencyFormatter.cop(category.price)}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneDivider extends StatelessWidget {
  final String label;

  const _ZoneDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    // OJO: este widget vive dentro de un SingleChildScrollView horizontal
    // (el mapa de asientos), así que el ancho disponible es infinito.
    // `Expanded`/`Flexible` requieren un ancho acotado y rompen el layout
    // (pantalla en blanco) en ese contexto — se usa un ancho fijo en vez
    // de expandir para que funcione dentro de scroll horizontal.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 60,
          child: Divider(color: AppColors.divider),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(
          width: 60,
          child: Divider(color: AppColors.divider),
        ),
      ],
    );
  }
}
