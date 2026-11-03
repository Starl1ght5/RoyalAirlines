import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/animations/app_motion.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/favorites/widgets/favorite_button.dart';
import 'package:royal_airlines/features/flights/controller/flight_controller.dart';
import 'package:royal_airlines/features/flights/widgets/airline_info.dart';
import 'package:royal_airlines/features/flights/widgets/fare_details_sheet.dart';
import 'package:royal_airlines/features/flights/widgets/flight_time_card.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/services/user_event_tracker.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';
import 'package:royal_airlines/shared/widgets/fade_slide_in.dart';

/// FlightCard
/// ----------
/// Tarjeta principal de resultados con jerarquía fuerte en precio y horario.
class FlightCard extends StatefulWidget {
  final FlightModel flight;
  final bool isBestOption;
  final bool isFastest;

  /// Posición del vuelo en la lista de resultados (0-based). Dibuja el
  /// stagger de entrada de [FadeSlideIn] y viaja en los eventos
  /// `flight_view` / `flight_click` como `position`.
  final int index;
  final void Function(FlightModel flight, FareModel fare) onSelect;

  /// Si este vuelo está marcado para la comparación.
  final bool isInCompare;

  /// Alterna el vuelo en la comparación. Si es null, el botón
  /// "Comparar" no se muestra (útil para reutilizar la tarjeta).
  final VoidCallback? onToggleCompare;

  const FlightCard({
    super.key,
    required this.flight,
    required this.onSelect,
    this.isBestOption = false,
    this.isFastest = false,
    this.index = 0,
    this.isInCompare = false,
    this.onToggleCompare,
  });

  @override
  State<FlightCard> createState() => _FlightCardState();
}

class _FlightCardState extends State<FlightCard> {
  bool _isPressed = false;
  bool _isLoadingDetail = false;

  @override
  void initState() {
    super.initState();
    // El vuelo entró en la lista de resultados: una `flight_view` por
    // tarjeta montada (si el usuario sale y vuelve a entrar a la
    // pantalla, se vuelve a contar — es lo que interesa: cuántas veces
    // se MIRÓ cada vuelo, no cuántas veces se reconstruyó el widget).
    context.read<UserEventTracker>().track(
          'flight_view',
          flightId: widget.flight.id,
          position: widget.index,
        );
  }

  Future<void> _openFareSheet(BuildContext context) async {
    if (_isLoadingDetail) return;

    // Tocar la tarjeta para seguir (ver tarifas) = intención sobre
    // este vuelo, con su posición en la lista ordenada actual.
    context.read<UserEventTracker>().track(
          'flight_click',
          flightId: widget.flight.id,
          position: widget.index,
        );

    setState(() => _isLoadingDetail = true);
    try {
      // Pide el detalle ACTUALIZADO del vuelo (tarifas/cupos frescos
      // de GET /flights/{flightId}) antes de mostrar las tarifas.
      final controller = context.read<FlightController>();
      final freshFlight = await controller.refreshFlightDetail(widget.flight);
      if (!context.mounted) return;

      final fare = await FareDetailsSheet.show(context, freshFlight);
      if (fare != null) widget.onSelect(freshFlight, fare);
    } finally {
      // Pase lo que pase (incluida una excepción futura), el botón no
      // puede quedarse con spinner permanente.
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  String get _availabilityMessage =>
      '${widget.flight.fares.length} tarifas disponibles hoy';

  @override
  Widget build(BuildContext context) {
    final flight = widget.flight;
    final cheapest = flight.cheapestFare;
    final forecast = flight.demandForecast;
    final priceForecast = flight.priceForecast;
    final cardShadows = widget.isBestOption
        ? [...AppShadows.floating, ...AppShadows.goldGlow]
        : AppShadows.card;

    return FadeSlideIn(
      index: widget.index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: AnimatedScale(
          scale: 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openFareSheet(context),
              onHighlightChanged: (value) {
                if (_isPressed == value) return;
                setState(() => _isPressed = value);
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              splashColor: AppColors.primary.withValues(alpha: 0.06),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppColors.glassGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: widget.isBestOption
                        ? AppColors.gold.withValues(alpha: 0.75)
                        : AppColors.border,
                    width: widget.isBestOption ? 1.5 : 1,
                  ),
                  boxShadow: cardShadows,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppSpacing.radiusLg),
                        ),
                      ),
                      // Expanded + Flexible repartían el ancho 50/50: en un
                      // teléfono, AirlineInfo quedaba con ~115 px y se
                      // desbordaba con nombres de aerolínea reales. En
                      // pantallas estrechas el precio pasa debajo.
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final airline = AirlineInfo(
                            airline: flight.airline,
                            flightNumber: flight.flightNumber,
                          );
                          // Favorito del VUELO: `targetId` es directo
                          // `FlightModel.id` (flightID), no pasa por
                          // catálogo. Va fuera del InkWell de la tarjeta
                          // para no disparar "Ver tarifas".
                          final favorite = FavoriteButton(
                            targetType: FavoriteTarget.flight,
                            hint: flight.id,
                            chip: true,
                            inactiveColor:
                                AppColors.textOnPrimary.withValues(alpha: 0.85),
                            activeColor: AppColors.gold,
                            tooltip: 'Guardar vuelo',
                          );
                          final price = ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 158),
                            child: _PriceHero(price: cheapest.price),
                          );

                          if (constraints.maxWidth < 380) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: airline),
                                    const SizedBox(width: AppSpacing.md),
                                    favorite,
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: price,
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: airline),
                              const SizedBox(width: AppSpacing.md),
                              favorite,
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: price,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FlightTimeCard(
                            departureTime: flight.departureTime,
                            arrivalTime: flight.arrivalTime,
                            duration: flight.duration,
                            stopsLabel: flight.stopsLabel,
                            isDirect: flight.isDirect,
                            originCode: flight.origin.code,
                            destinationCode: flight.destination.code,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Icon(
                                Icons.airplanemode_active_rounded,
                                size: 16,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  flight.aircraft,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (widget.onToggleCompare != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                _CompareToggle(
                                  isSelected: widget.isInCompare,
                                  onTap: widget.onToggleCompare!,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              if (widget.isBestOption)
                                _FlightTag(
                                  label: 'Mejor opción',
                                  icon: Icons.auto_awesome_rounded,
                                  textColor: AppColors.primaryDark,
                                  borderColor: AppColors.gold,
                                  gradient: AppColors.goldGradient,
                                  shadows: AppShadows.goldGlow,
                                ),
                              if (widget.isFastest)
                                _FlightTag(
                                  label: 'Más rápido',
                                  icon: Icons.bolt_rounded,
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.08),
                                  textColor: AppColors.primary,
                                  borderColor:
                                      AppColors.primary.withValues(alpha: 0.16),
                                ),
                              _FlightTag(
                                label: flight.isDirect
                                    ? 'Directo'
                                    : flight.stopsLabel,
                                icon: flight.isDirect
                                    ? Icons.check_circle_rounded
                                    : Icons.connecting_airports_rounded,
                                backgroundColor: flight.isDirect
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.surfaceVariant,
                                textColor: flight.isDirect
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                                borderColor: flight.isDirect
                                    ? AppColors.success.withValues(alpha: 0.18)
                                    : AppColors.border,
                              ),
                            ],
                          ),
                          if (forecast.level != 'Baja') ...[
                            const SizedBox(height: AppSpacing.md),
                            _InsightBanner(
                              icon: Icons.local_fire_department_rounded,
                              accentColor: forecast.level == 'Alta'
                                  ? AppColors.error
                                  : AppColors.warning,
                              title: forecast.level == 'Alta'
                                  ? 'Alta demanda'
                                  : 'Demanda activa',
                              message:
                                  '${(forecast.fillProbability * 100).toStringAsFixed(0)}% de ocupación estimada para este vuelo.',
                            ),
                          ],
                          if (priceForecast.isRising) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _InsightBanner(
                              icon: Icons.trending_up_rounded,
                              accentColor: AppColors.info,
                              title: 'Precio al alza',
                              message:
                                  'Podría subir ${priceForecast.changePercent}% si reservas más tarde.',
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            padding: const EdgeInsets.only(top: AppSpacing.lg),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.divider),
                              ),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 360;
                                final priceBlock = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tarifa más baja disponible',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      CurrencyFormatter.cop(cheapest.price),
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Por pasajero · incluye tasas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      _availabilityMessage,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                );

                                final action = SizedBox(
                                  width: compact ? double.infinity : 150,
                                  height: 54,
                                  child: CustomButton(
                                    label: 'Ver tarifas',
                                    icon: Icons.arrow_forward_rounded,
                                    // Spinner mientras se refresca el
                                    // detalle del vuelo antes de abrir.
                                    isLoading: _isLoadingDetail,
                                    onPressed: () => _openFareSheet(context),
                                  ),
                                );

                                if (compact) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      priceBlock,
                                      const SizedBox(height: AppSpacing.md),
                                      action,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(child: priceBlock),
                                    const SizedBox(width: AppSpacing.md),
                                    action,
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceHero extends StatelessWidget {
  final double price;

  const _PriceHero({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'DESDE',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.goldLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.cop(price),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'por pasajero',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.goldLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? backgroundColor;
  final Color textColor;
  final Color borderColor;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;

  const _FlightTag({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.borderColor,
    this.backgroundColor,
    this.gradient,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String message;

  const _InsightBanner({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
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

/// _CompareToggle
/// --------------
/// Botón compacto "Comparar" / "Comparando" de la tarjeta. Tiene su
/// propio InkWell, así que tocarlo NO dispara el onTap de la tarjeta
/// (que abre las tarifas).
class _CompareToggle extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CompareToggle({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? AppColors.textOnPrimary : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_rounded : Icons.compare_arrows_rounded,
                size: 15,
                color: foreground,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                isSelected ? 'Comparando' : 'Comparar',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
