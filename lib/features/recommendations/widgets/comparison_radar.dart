import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/models/recommendation_model.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';

/// ComparisonRadar
/// ----------------
/// Gráfico de radar con la comparación MULTI-DESTINO que mostró el
/// profesor: el perfil del usuario (eje azul) superpuesto contra los
/// N destinos mejor rankeados, cada uno con su propio color (como
/// "Marruecos, Venecia, Rusia" en colores distintos). Permite ver de
/// un solo vistazo en qué destinos se solapan los polígonos con el
/// perfil — cuanto más cerca estén los vértices del polígono azul,
/// mayor la probabilidad de que la experiencia guste.
///
/// A diferencia de [RecommendationRadar] (1 destino, en el sheet de
/// detalle), este widget es el "overview" de la sección principal.
class ComparisonRadar extends StatelessWidget {
  const ComparisonRadar({super.key, required this.results});

  /// Ranking del motor, ordenado de mayor a menor afinidad. Solo se
  /// grafican los primeros [maxDestinations].
  final List<RecommendationResult> results;

  static const int maxDestinations = 3;

  /// Paleta cíclica para los destinos (el azul del perfil se reserva
  /// para el usuario, así que estos arrancan en el dorado).
  static const List<Color> _destinationPalette = [
    AppColors.gold,
    AppColors.info,
    AppColors.success,
    AppColors.error,
  ];

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    final topResults = results.take(maxDestinations).toList();

    // El polígono del usuario es idéntico en todos los resultados
    // (sale del perfil declarado), así que se toma del primero.
    final userValues = topResults.first.userRadarValues;

    final dataSets = [
      RadarDataSet(
        dataEntries:
            userValues.map((value) => RadarEntry(value: value)).toList(),
        fillColor: AppColors.primary.withValues(alpha: 0.16),
        borderColor: AppColors.primary,
        borderWidth: 2.2,
        entryRadius: 2.5,
      ),
      for (var i = 0; i < topResults.length; i++)
        RadarDataSet(
          dataEntries: topResults[i]
              .destinationRadarValues
              .map((value) => RadarEntry(value: value))
              .toList(),
          fillColor: _destinationPalette[i % _destinationPalette.length]
              .withValues(alpha: 0.10),
          borderColor: _destinationPalette[i % _destinationPalette.length],
          borderWidth: 1.8,
          entryRadius: 2.5,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 280,
          child: RadarChart(
            RadarChartData(
              dataSets: dataSets,
              getTitle: (index, _) => RadarChartTitle(
                text: TravelInterest.values[index].label,
              ),
              titleTextStyle: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyMedium?.color ??
                    AppColors.textSecondary,
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
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            const _RadarLegend(
              color: AppColors.primary,
              label: 'Tu perfil',
              isDashed: false,
            ),
            for (var i = 0; i < topResults.length; i++)
              _RadarLegend(
                color: _destinationPalette[i % _destinationPalette.length],
                label: topResults[i].destination.city,
                affinityPercent: topResults[i].affinityPercent,
              ),
          ],
        ),
      ],
    );
  }
}

class _RadarLegend extends StatelessWidget {
  const _RadarLegend({
    required this.color,
    required this.label,
    this.affinityPercent,
    this.isDashed = true,
  });

  final Color color;
  final String label;
  final int? affinityPercent;
  final bool isDashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          affinityPercent != null ? '$label · $affinityPercent%' : label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
