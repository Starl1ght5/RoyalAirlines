import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/models/recommendation_model.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';

/// RecommendationRadar
/// -------------------
/// Gráfico de radar (fl_chart) que compara al usuario contra UN
/// destino: 8 ejes, uno por cada [TravelInterest], con dos polígonos
/// superpuestos — el del perfil del usuario y el del destino. Es el
/// "radar de colores" del audio: ver de un vistazo en qué ejes se
/// solapan los dos perfiles (cuanto más cerca estén los vértices, más
/// probable que la experiencia guste).
class RecommendationRadar extends StatelessWidget {
  const RecommendationRadar({super.key, required this.result});

  final RecommendationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: RadarChart(
            RadarChartData(
              dataSets: [
                RadarDataSet(
                  dataEntries: result.userRadarValues
                      .map((value) => RadarEntry(value: value))
                      .toList(),
                  fillColor: AppColors.primary.withValues(alpha: 0.18),
                  borderColor: AppColors.primary,
                  borderWidth: 2,
                  entryRadius: 3,
                ),
                RadarDataSet(
                  dataEntries: result.destinationRadarValues
                      .map((value) => RadarEntry(value: value))
                      .toList(),
                  fillColor: AppColors.gold.withValues(alpha: 0.20),
                  borderColor: AppColors.gold,
                  borderWidth: 2,
                  entryRadius: 3,
                ),
              ],
              getTitle: (index, _) => RadarChartTitle(
                text: TravelInterest.values[index].label,
              ),
              titleTextStyle: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: theme.bodyMedium?.color ?? AppColors.textSecondary,
              ),
              tickCount: 4,
              ticksTextStyle: const TextStyle(
                fontSize: 8,
                color: AppColors.textTertiary,
              ),
              gridBorderData:
                  const BorderSide(color: AppColors.border, width: 1.2),
              radarBorderData:
                  const BorderSide(color: AppColors.border, width: 1.2),
              tickBorderData:
                  const BorderSide(color: AppColors.divider, width: 1),
              radarBackgroundColor: AppColors.surface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RadarLegend(color: AppColors.primary, label: 'Tu perfil'),
            SizedBox(width: 20),
            _RadarLegend(color: AppColors.gold, label: 'Destino'),
          ],
        ),
      ],
    );
  }
}

class _RadarLegend extends StatelessWidget {
  const _RadarLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
