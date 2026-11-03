import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/features/auth/screens/login_screen.dart';
import 'package:royal_airlines/features/booking/controller/trip_booking_controller.dart';
import 'package:royal_airlines/features/booking/screens/leg_booking_screen.dart';
import 'package:royal_airlines/features/flights/controller/flight_controller.dart';
import 'package:royal_airlines/features/flights/screens/flight_comparison_screen.dart';
import 'package:royal_airlines/features/flights/widgets/filter_sheet.dart';
import 'package:royal_airlines/features/flights/widgets/flight_card.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart'
    show TripType;
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/services/user_event_tracker.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// FlightsScreen
/// -------------
/// Pantalla de resultados de búsqueda. Se REUTILIZA para ambos tramos
/// de cualquier viaje: [legType] identifica si esta instancia muestra
/// vuelos de ida o de regreso, y [tripController] (no nulo mientras el
/// viaje ya está en curso) acumula la selección de cada tramo.
///
/// UNIFICADO: tanto "Solo ida" como "Ida y vuelta" pasan por el mismo
/// mecanismo — [TripBookingController] + [LegBookingScreen] +
/// CheckoutScreen. La diferencia entre ambos vive únicamente en
/// [TripBookingController.isRoundTrip]: si es `false`, [LegBookingScreen]
/// salta directo a Checkout tras un solo tramo; si es `true`, encadena
/// un segundo [FlightsScreen] para el regreso antes de Checkout. Un
/// único flujo modular para ambos casos.
class FlightsScreen extends StatelessWidget {
  final FlightSearchParams searchParams;
  final TripLegType legType;
  final TripBookingController? tripController;

  /// Parámetros de la búsqueda ORIGINAL (la de ida, con el
  /// origen/destino/fechas reales elegidos en Home) — se conservan
  /// intactos a través de toda la navegación del viaje para poder
  /// construir la búsqueda del tramo de regreso (origen/destino
  /// invertidos, fecha de regreso) sin perder el contexto original.
  final FlightSearchParams? originalSearchParams;

  const FlightsScreen({
    super.key,
    required this.searchParams,
    this.legType = TripLegType.outbound,
    this.tripController,
    this.originalSearchParams,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          FlightController(searchParams: searchParams)..loadFlights(),
      child: _FlightsScreenBody(
        legType: legType,
        tripController: tripController,
        originalSearchParams: originalSearchParams ?? searchParams,
      ),
    );
  }
}

class _FlightsScreenBody extends StatelessWidget {
  final TripLegType legType;
  final TripBookingController? tripController;
  final FlightSearchParams originalSearchParams;

  const _FlightsScreenBody({
    required this.legType,
    required this.tripController,
    required this.originalSearchParams,
  });

  Future<void> _openFilterSheet(
      BuildContext context, FlightController controller) async {
    final result = await showModalBottomSheet<(SortOption, StopsFilter)>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FilterSheet(
        initialSort: controller.sortOption,
        initialStops: controller.stopsFilter,
      ),
    );
    if (result == null) return;
    controller.setSortOption(result.$1);
    controller.setStopsFilter(result.$2);
  }

  /// Al elegir vuelo+tarifa: SIEMPRE registra la selección en un
  /// [TripBookingController] (creándolo la primera vez, en el tramo de
  /// ida) y navega a [LegBookingScreen] para completar asiento/equipaje
  /// de ese tramo. `isRoundTrip` en el controller es lo único que
  /// determina si después habrá un segundo tramo (regreso) o si se
  /// salta directo a Checkout — así "Solo ida" y "Ida y vuelta"
  /// comparten exactamente el mismo camino de pantallas.
  void _handleFlightSelected(
    BuildContext context,
    FlightController controller,
    FlightModel flight,
    FareModel fare,
  ) {
    // Guard de invitado: reservar y pagar requieren token en el header
    // (`Authorization`), así que un invitado no puede llegar a Checkout.
    // Se redirige a Login en vez de esperar un 401 confuso en el pago.
    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Inicia sesión o crea una cuenta para completar tu reserva'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final passengers = controller.searchParams.passengers;
    final requiredSeatCount = passengers.adults + passengers.children;

    // El usuario confirma vuelo+tarifa y entra al flujo de reserva.
    // Se cuenta UNA sola vez por viaje (tramo de ida): el tramo de
    // regreso continúa una reserva ya iniciada, no abre otra.
    if (legType == TripLegType.outbound) {
      context.read<UserEventTracker>().track(
        'checkout_start',
        flightId: flight.id,
        context: 'flights',
        payload: {
          'fareId': fare.feeID,
          'fare': fare.tierName,
          'price': fare.price.round().toString(),
          'origin': controller.searchParams.origin.code,
          'destination': controller.searchParams.destination.code,
          'tripType': controller.searchParams.tripType == TripType.roundTrip
              ? 'ROUND_TRIP'
              : 'ONE_WAY',
        },
      );
    }

    final activeTripController = tripController ??
        TripBookingController(
          isRoundTrip: controller.searchParams.tripType == TripType.roundTrip,
          requiredSeatCount: requiredSeatCount,
        );

    if (legType == TripLegType.outbound) {
      activeTripController.setOutboundSelection(flight, fare);
    } else {
      activeTripController.setReturnSelection(flight, fare);
    }
    activeTripController.setCurrentLeg(legType);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegBookingScreen(
          tripController: activeTripController,
          legType: legType,
          originalSearchParams: originalSearchParams,
        ),
      ),
    );
  }

  /// Marca/desmarca un vuelo para comparar. Si ya hay
  /// [FlightController.maxCompare], avisa en vez de fallar en silencio.
  void _toggleCompare(
    BuildContext context,
    FlightController controller,
    FlightModel flight,
  ) {
    final ok = controller.toggleCompare(flight);
    if (ok) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Puedes comparar hasta ${FlightController.maxCompare} vuelos a la vez',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
  }

  /// Abre la comparación. La elección final reutiliza
  /// [_handleFlightSelected], así conserva el guard de login y el flujo
  /// de ida/regreso sin duplicar lógica.
  void _openComparison(BuildContext context, FlightController controller) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlightComparisonScreen(
          flights: controller.compareFlights,
          refreshFlight: controller.refreshFlightDetail,
          onRemove: (flight) => controller.toggleCompare(flight),
          onSelect: (flight, fare) =>
              _handleFlightSelected(context, controller, flight, fare),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FlightController>();
    final params = controller.searchParams;
    final isReturnLeg = legType == TripLegType.returnLeg;

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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isReturnLeg)
              const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  'VUELO DE REGRESO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.gold,
                  ),
                ),
              ),
            Text(
              '${params.origin.code} → ${params.destination.code}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${params.passengers.summary} · ${_formatDate(params.departureDate)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded,
                color: AppColors.textPrimary, size: 21),
            onPressed: () => _openFilterSheet(context, controller),
          ),
        ],
      ),
      bottomNavigationBar: controller.compareCount > 0
          ? _CompareBar(
              count: controller.compareCount,
              max: FlightController.maxCompare,
              onClear: controller.clearCompare,
              onCompare: () => _openComparison(context, controller),
            )
          : null,
      body: SafeArea(
        top: false,
        child: controller.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.4,
                ),
              )
            : controller.errorMessage != null
                ? _ErrorState(
                    message: controller.errorMessage!,
                    onRetry: controller.loadFlights,
                  )
                : controller.visibleFlights.isEmpty
                    ? const _EmptyResults()
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${controller.resultsCount} vuelos encontrados',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                _sortLabelFor(controller.sortOption),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // asMap() conserva la POSICIÓN de cada vuelo en
                          // la lista actual: viaja en `index` y la usan
                          // los eventos `flight_view` / `flight_click`.
                          ...controller.visibleFlights.asMap().entries.map(
                                (entry) => FlightCard(
                                  index: entry.key,
                                  flight: entry.value,
                                  isBestOption:
                                      controller.bestOptionFlight?.id ==
                                          entry.value.id,
                                  isInCompare:
                                      controller.isInCompare(entry.value.id),
                                  onToggleCompare: () => _toggleCompare(
                                      context, controller, entry.value),
                                  onSelect: (f, fare) => _handleFlightSelected(
                                      context, controller, f, fare),
                                ),
                              ),
                        ],
                      ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  static String _sortLabelFor(SortOption option) {
    switch (option) {
      case SortOption.priceAsc:
        return 'Menor precio';
      case SortOption.priceDesc:
        return 'Mayor precio';
      case SortOption.duration:
        return 'Más corto';
      case SortOption.earliestDeparture:
        return 'Salida temprana';
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 46,
              color: AppColors.textTertiary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            const Text(
              'No se pudieron cargar los vuelos',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flight_takeoff_rounded,
            size: 46,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'No hay vuelos con estos filtros',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Intenta ajustar los filtros de escalas',
            style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// _CompareBar
/// -----------
/// Barra inferior que aparece en cuanto hay al menos un vuelo marcado.
/// El botón "Comparar" se habilita desde 2 vuelos.
class _CompareBar extends StatelessWidget {
  const _CompareBar({
    required this.count,
    required this.max,
    required this.onClear,
    required this.onCompare,
  });

  final int count;
  final int max;
  final VoidCallback onClear;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final canCompare = count >= 2;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: AppShadows.floating,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count de $max vuelos',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      canCompare
                          ? 'Listo para comparar'
                          : 'Elige al menos 2 para comparar',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Limpiar'),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 150,
                height: 50,
                child: CustomButton(
                  label: 'Comparar',
                  icon: Icons.compare_arrows_rounded,
                  onPressed: canCompare ? onCompare : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
