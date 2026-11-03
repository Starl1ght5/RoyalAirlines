import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/favorites/widgets/favorite_button.dart';
import 'package:royal_airlines/features/flights/controller/flight_controller.dart'
    show FlightSearchParams;
import 'package:royal_airlines/features/flights/screens/flights_screen.dart';
import 'package:royal_airlines/features/flights/widgets/price_history_card.dart';
import 'package:royal_airlines/features/home/repository/home_repository.dart';
import 'package:royal_airlines/features/recommendations/widgets/recommendation_radar.dart';
import 'package:royal_airlines/features/traveler_profile/widgets/preferences_status_card.dart'
    show MonthLabels;
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/recommendation_model.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart'
    show HomeController, PassengerCount, TripType;

/// DestinationMatchSheet
/// ---------------------
/// Bottom sheet con el ANÁLISIS COMPLETO de una recomendación: radar
/// perfil-vs-destino, desglose de los 4 sub-scores, probabilidad de
/// experiencia favorable y el CTA para reservar (solo si el destino
/// tiene ruta hoy; los aspiracionales muestran "Próximamente").
///
/// Se abre bajo el Navigator raíz, por eso recibe [result] por
/// parámetro en vez de leer providers.
class DestinationMatchSheet extends StatelessWidget {
  const DestinationMatchSheet({super.key, required this.result});

  final RecommendationResult result;

  Future<void> _bookFlight(BuildContext context) async {
    final destination = result.destination;
    if (!destination.isBookable) return;

    // Se cierra el sheet INMEDIATAMENTE, antes de cualquier await:
    // además de una UX natural (el sheet no queda encima al volver),
    // imposibilita toques repetidos que dispararían N búsquedas en
    // paralelo y apilarían varias rutas FlightsScreen. Se capturan
    // navigator y messenger ANTES del pop para seguir usándolos sin
    // depender del contexto ya desmontado.
    //
    // El pop LLEVA el resultado `'booked'`: RecommendationsSection lo
    // usa para no contar este cierre como `recommendation_dismiss`
    // (sí lo es cuando el usuario cierra el sheet a mano o con el X).
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop('booked');

    // Si el backend no responde, el CTA no debe lanzar una excepción
    // sin capturar: se avisa con un SnackBar en la pantalla de abajo.
    final List<AirportModel> airports;
    try {
      airports = await HomeRepository().getAirports();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content:
            Text('No se pudieron cargar los aeropuertos. Revisa tu conexión.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final destinationAirport = airports.cast<AirportModel?>().firstWhere(
          (airport) => airport?.code == destination.code,
          orElse: () => null,
        );
    if (destinationAirport == null) {
      messenger.showSnackBar(SnackBar(
        content: Text('Próximamente: aún no hay rutas a ${destination.city}.'),
        backgroundColor: AppColors.primary,
      ));
      return;
    }

    // Origen por defecto: el primer aeropuerto que no sea el destino
    // (mismo criterio que al tocar un destino popular en Home).
        // Origen base de la app: siempre Cartagena (CTG).
    const origin = HomeController.defaultOrigin;

    final departureDate = DateTime.now().add(const Duration(days: 7));
    final params = FlightSearchParams(
      tripType: TripType.oneWay,
      origin: origin,
      destination: destinationAirport,
      departureDate: departureDate,
      passengers: const PassengerCount(),
    );

    navigator.push(
      MaterialPageRoute(builder: (_) => FlightsScreen(searchParams: params)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = result.destination;
    final monthLabels = destination.bestMonths.isEmpty
        ? 'Sin temporada marcada'
        : MonthLabels.join(destination.bestMonths);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.city,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destination.country,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${result.affinityPercent}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: AppColors.success,
                      ),
                    ),
                    const Text(
                      'de afinidad',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Corazón del destino: el id REAL viene en el
                    // resultado si la lista es del backend; si no, se
                    // resuelve por IATA vía catálogo (ver
                    // FavoriteButton).
                    FavoriteButton(
                      hint: result.locationId,
                      code: destination.code,
                      tooltip: 'Guardar destino',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Tu perfil vs este destino',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            RecommendationRadar(result: result),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              '¿Qué tan probable es que disfrutes el viaje?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ProbabilityBar(percent: result.favorablePercent),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Cómo se calculó',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ScoreBar(
              label: 'Intereses',
              score: result.interestScore,
              weight: '40%',
              icon: Icons.favorite_outline_rounded,
            ),
            _ScoreBar(
              label: 'Presupuesto',
              score: result.budgetScore,
              weight: '25%',
              icon: Icons.payments_outlined,
            ),
            _ScoreBar(
              label: 'Estacionalidad',
              score: result.seasonalityScore,
              weight: '20%',
              icon: Icons.calendar_month_outlined,
            ),
            _ScoreBar(
              label: 'Historial',
              score: result.historyScore,
              weight: '15%',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Precio solo si el perfil lo conoce (los destinos del
            // backend sin catálogo curado vienen sin precio).
            if (destination.averagePriceCop > 0)
              _InfoTile(
                icon: Icons.payments_outlined,
                label: 'Precio promedio',
                value: CurrencyFormatter.cop(destination.averagePriceCop),
              ),
            _InfoTile(
              icon: Icons.wb_sunny_outlined,
              label: 'Mejor momento para viajar',
              value: monthLabels,
            ),
            const SizedBox(height: AppSpacing.md),
            // Histórico de precios de la ruta (USD): el origen se
            // resuelve con el catálogo porque esta ficha no tiene un
            // vuelo concreto.
            PriceHistoryCard.forDestination(
              destinationCode: destination.code,
            ),
            if (result.reasons.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Por qué te lo recomendamos',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final reason in result.reasons)
                    Chip(
                      label: Text(reason),
                      labelStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      backgroundColor: AppColors.surfaceVariant,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (destination.isBookable)
              CustomButton(
                label: 'Ver vuelos a ${destination.city}',
                icon: Icons.flight_takeoff_rounded,
                onPressed: () => _bookFlight(context),
              )
            else
              CustomButton.secondary(
                label: 'Ruta próximamente — avísame',
                icon: Icons.notifications_outlined,
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProbabilityBar extends StatelessWidget {
  const _ProbabilityBar({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = switch (percent) {
      >= 70 => AppColors.success,
      >= 45 => AppColors.info,
      _ => AppColors.warning,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Probabilidad estimada',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 10,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.score,
    required this.weight,
    required this.icon,
  });

  final String label;
  final double score;
  final String weight;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final percent = (score * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 110,
            child: Text(
              '$label ($weight)',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: LinearProgressIndicator(
                value: score,
                minHeight: 8,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(
                  AppColors.primary.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 38,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
