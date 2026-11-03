import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/features/booking/controller/trip_booking_controller.dart';
import 'package:royal_airlines/features/booking/screens/checkout_screen.dart';
import 'package:royal_airlines/features/booking/widgets/baggage_selector.dart';
import 'package:royal_airlines/features/booking/widgets/fare_selector.dart';
import 'package:royal_airlines/features/booking/widgets/seat_selector.dart';
import 'package:royal_airlines/features/booking/widgets/travel_extras_selector.dart';
import 'package:royal_airlines/features/flights/controller/flight_controller.dart';
import 'package:royal_airlines/features/flights/screens/flights_screen.dart';
import 'package:royal_airlines/features/flights/widgets/airline_info.dart';
import 'package:royal_airlines/features/flights/widgets/flight_time_card.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart'
    show TripType;
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// LegBookingScreen
/// -----------------
/// Selección de tarifa/asiento/equipaje de UN tramo del viaje (ida o
/// regreso). Reutiliza los mismos widgets ([FareSelector],
/// [SeatSelector], [BaggageSelector]) pero operando sobre el
/// [LegBooking] activo del [TripBookingController] compartido.
///
/// Al continuar: si es el tramo de IDA y el viaje es redondo, navega
/// de vuelta a [FlightsScreen] pero para el tramo de REGRESO (origen/
/// destino invertidos, fecha de regreso). Si es el tramo de REGRESO
/// (o el viaje no es redondo), navega a [CheckoutScreen] para
/// pasajeros/pago — solo ahí se pide esa información, una única vez
/// para todo el viaje.
class LegBookingScreen extends StatefulWidget {
  final TripBookingController tripController;
  final TripLegType legType;
  final FlightSearchParams originalSearchParams;

  const LegBookingScreen({
    super.key,
    required this.tripController,
    required this.legType,
    required this.originalSearchParams,
  });

  @override
  State<LegBookingScreen> createState() => _LegBookingScreenState();
}

class _LegBookingScreenState extends State<LegBookingScreen> {
  @override
  void initState() {
    super.initState();
    // Asegura que el controller sepa que ESTE es el tramo activo
    // antes de que cualquier widget hijo (FareSelector, SeatSelector)
    // dispare cambios sobre él.
    widget.tripController.setCurrentLeg(widget.legType);
    // Descarga el mapa REAL de asientos del vuelo
    // (`GET /flights/{flightId}/seats`) con el que se pinta la cabina.
    widget.tripController.loadSeatMap(widget.legType);
  }

  void _handleContinue() {
    final leg = widget.legType == TripLegType.outbound
        ? widget.tripController.outbound
        : widget.tripController.returnLeg;
    if (leg == null) return;

    if (!leg.hasRequiredSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Selecciona ${leg.requiredSeatCount} asiento(s) para continuar'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final bool mustGoToReturnLeg = widget.legType == TripLegType.outbound &&
        widget.tripController.isRoundTrip;

    if (mustGoToReturnLeg) {
      final params = widget.originalSearchParams;
      final returnDate = params.returnDate ??
          params.departureDate.add(const Duration(days: 3));

      final returnParams = FlightSearchParams(
        tripType: TripType.oneWay,
        origin: params.destination,
        destination: params.origin,
        departureDate: returnDate,
        returnDate: null,
        passengers: params.passengers,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FlightsScreen(
            searchParams: returnParams,
            legType: TripLegType.returnLeg,
            tripController: widget.tripController,
            originalSearchParams: widget.originalSearchParams,
          ),
        ),
      );
      return;
    }

    _openCheckout();
  }

  /// Abre el checkout y, si el backend respondió 409 (alguien más tomó
  /// uno de los asientos elegidos), recarga los mapas de los tramos y
  /// avisa para que el usuario vuelva a elegir.
  Future<void> _openCheckout() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          tripController: widget.tripController,
        ),
      ),
    );

    if (result != CheckoutResult.seatConflict) return;

    await widget.tripController.reloadSeatMapsAfterConflict();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Alguien más tomó uno de tus asientos. El mapa se actualizó: elige de nuevo.',
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  /// Sección del mapa de asientos según el estado de su descarga:
  /// cargando (spinner), fallo (mensaje + reintentar) o el mapa REAL
  /// del vuelo servido por `GET /flights/{flightId}/seats`.
  Widget _buildSeatSection(LegBooking leg) {
    final map = leg.seatMap;

    if (map == null) {
      final error = leg.seatMapError;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: error == null
            ? const Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Cargando mapa de asientos…',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: AppColors.error, size: 26),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomButton.secondary(
                    label: 'Reintentar',
                    icon: Icons.refresh_rounded,
                    onPressed: () =>
                        widget.tripController.loadSeatMap(widget.legType),
                  ),
                ],
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeatSelector(
          seatMap: map,
          selectedSeats: leg.selectedSeats,
          requiredSeatCount: leg.requiredSeatCount,
          onSeatTapped: widget.tripController.toggleSeat,
        ),
        if (leg.seatMapLoading) ...[
          // Refresco en curso (p. ej. tras un conflicto de asientos):
          // el mapa anterior sigue visible para no perder la selección.
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(
            minHeight: 2,
            color: AppColors.primary,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.tripController,
      builder: (context, _) {
        final leg = widget.legType == TripLegType.outbound
            ? widget.tripController.outbound
            : widget.tripController.returnLeg;
        if (leg == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                color: AppColors.textPrimary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                widget.legType == TripLegType.outbound
                    ? 'Vuelo de ida'
                    : 'Vuelo de regreso',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            body: const Center(
              child: Text(
                'No se encontró el vuelo seleccionado',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        final isReturn = widget.legType == TripLegType.returnLeg;
        final isRoundTrip = widget.tripController.isRoundTrip;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
              color: AppColors.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              isReturn ? 'Vuelo de regreso' : 'Vuelo de ida',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [
                      if (isRoundTrip) ...[
                        _LegProgressBadge(isReturn: isReturn),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _FlightSummaryCard(flight: leg.flight),
                      const SizedBox(height: AppSpacing.xl),
                      FareSelector(
                        flight: leg.flight,
                        selected: leg.fare,
                        onChanged: widget.tripController.changeFare,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _buildSeatSection(leg),
                      const SizedBox(height: AppSpacing.xl),
                      BaggageSelector(
                        selected: leg.baggageOption,
                        onChanged: widget.tripController.setBaggage,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TravelExtrasSelector(
                        hasTravelInsurance: leg.travelInsurance,
                        hasPriorityBoarding: leg.priorityBoarding,
                        onTravelInsuranceChanged:
                            widget.tripController.setTravelInsurance,
                        onPriorityBoardingChanged:
                            widget.tripController.setPriorityBoarding,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 13, 20, 13),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: CustomButton(
                      label: (isReturn || !isRoundTrip)
                          ? 'Continuar a datos del pasajero'
                          : 'Continuar a vuelo de regreso',
                      onPressed: _handleContinue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Indicador de progreso "Ida -> Regreso", visible solo en viajes
/// redondos, para que el usuario siempre sepa en qué tramo está.
class _LegProgressBadge extends StatelessWidget {
  final bool isReturn;
  const _LegProgressBadge({required this.isReturn});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepChip(label: 'Ida', isActive: !isReturn, isDone: isReturn),
        Container(
          width: 26,
          height: 1.4,
          color: AppColors.divider,
          margin: const EdgeInsets.symmetric(horizontal: 6),
        ),
        _StepChip(label: 'Regreso', isActive: isReturn, isDone: false),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDone;

  const _StepChip({
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isActive
        ? AppColors.primary
        : (isDone ? AppColors.success : AppColors.textTertiary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.circle,
          size: isDone ? 15 : 8,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _FlightSummaryCard extends StatelessWidget {
  final FlightModel flight;
  const _FlightSummaryCard({required this.flight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AirlineInfo(
              airline: flight.airline, flightNumber: flight.flightNumber),
          const SizedBox(height: AppSpacing.md + 1),
          FlightTimeCard(
            departureTime: flight.departureTime,
            arrivalTime: flight.arrivalTime,
            duration: flight.duration,
            stopsLabel: flight.stopsLabel,
            isDirect: flight.isDirect,
            originCode: flight.origin.code,
            destinationCode: flight.destination.code,
          ),
        ],
      ),
    );
  }
}
