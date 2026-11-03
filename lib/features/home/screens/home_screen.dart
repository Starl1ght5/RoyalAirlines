import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/features/flights/controller/flight_controller.dart';
import 'package:royal_airlines/features/flights/screens/flights_screen.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart';
import 'package:royal_airlines/features/home/widgets/destination_list.dart';
import 'package:royal_airlines/features/home/widgets/home_header.dart';
import 'package:royal_airlines/features/home/widgets/promotion_slider.dart';
import 'package:royal_airlines/features/home/widgets/search_card.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/promotion_model.dart';
import 'package:royal_airlines/services/user_event_tracker.dart';
import 'package:royal_airlines/shared/widgets/section_title.dart';

/// HomeScreen
/// ----------
/// Pantalla principal de la app autenticada (primer tab de
/// [MainNavigation]). Registra su propio [HomeController] con
/// `ChangeNotifierProvider` LOCAL.
///
/// Su única responsabilidad respecto al viaje redondo es CONSERVAR
/// [TripType] y la fecha de regreso al armar [FlightSearchParams] —
/// no decide el flujo de UI. La bifurcación real entre "Solo ida" y
/// "Ida y vuelta" (LegBookingScreen -> CheckoutScreen) vive en
/// [FlightsScreen] y su cadena de pantallas (ver
/// trip_booking_controller.dart, leg_booking_screen.dart,
/// checkout_screen.dart).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeController()..loadHomeData(),
      child: const _HomeScreenBody(),
    );
  }
}

class _HomeScreenBody extends StatelessWidget {
  const _HomeScreenBody();

  /// Al tocar un destino popular, arma una búsqueda completa con lo
  /// que ya tenga el usuario elegido (origen, fecha y tipo de viaje,
  /// si los hay) y navega DIRECTO a los resultados de vuelo. Conserva
  /// [TripType] y la fecha de regreso tal como los tenga el usuario:
  /// si eligió "Ida y vuelta" en el buscador antes de tocar un
  /// destino, ese viaje redondo se respeta también desde aquí.
  void _handleDestinationTap(
    BuildContext context,
    HomeController controller,
    AirportModel destination,
  ) {
    final origin = controller.origin ??
        controller.airports.firstWhere(
          (a) => a.code != destination.code,
          orElse: () => controller.airports.first,
        );

    final departureDate =
        controller.departureDate ?? DateTime.now().add(const Duration(days: 1));

    controller.setDestination(destination);

    // Telemetría (POST /events, solo con consentimiento de tracking):
    // tocar una tarjeta de destinos populares ES abrir la ficha de un
    // destino, y como además navega directo a los resultados, también
    // cuenta como una búsqueda. Dos señales distintas del mismo gesto.
    final tracker = context.read<UserEventTracker>();
    tracker.track(
      'destination_view',
      destinationId: destination.eventDestinationId,
      context: 'home',
    );
    tracker.track(
      'search',
      context: 'home',
      payload: {
        'origin': origin.code,
        'destination': destination.code,
        'departureDate': departureDate.toIso8601String().split('T').first,
        'adults': '${controller.passengers.adults}',
        'children': '${controller.passengers.children}',
        'tripType': controller.tripType == TripType.roundTrip
            ? 'ROUND_TRIP'
            : 'ONE_WAY',
        'source': 'destination_card',
      },
    );

    final params = FlightSearchParams(
      tripType: controller.tripType,
      origin: origin,
      destination: destination,
      departureDate: departureDate,
      returnDate: controller.tripType == TripType.roundTrip
          ? (controller.returnDate ??
              departureDate.add(const Duration(days: 3)))
          : null,
      passengers: controller.passengers,
    );

    _pushFlights(context, params);
  }

  /// Al tocar una tarjeta de promoción, navega DIRECTO a los resultados
  /// de la ruta que la tarjeta promete (su `origin` → su `destination`),
  /// usando la fecha que trae la promoción: es la fecha del vuelo más
  /// barato de esa ruta, así la lista siempre aterriza en un día con
  /// vuelos reales en vez de un "no hay vuelos" arbitrario.
  ///
  /// Sin fecha en la promoción (backend anterior) se cae a la fecha
  /// elegida en el buscador y, en último caso, a mañana — el mismo
  /// criterio que [_handleDestinationTap]. Si el catálogo todavía no
  /// cargó o la ruta no se puede resolver, no se navega.
  void _handlePromotionTap(
    BuildContext context,
    HomeController controller,
    PromotionModel promotion,
  ) {
    final airports = controller.airports;
    final destination = _airportByCode(airports, promotion.destination);
    if (destination == null) return;

    final origin = _airportByCode(airports, promotion.origin) ??
        controller.origin ??
        airports.firstWhere(
          (a) => a.code != destination.code,
          orElse: () => airports.first,
        );

    final departureDate = promotion.departureDate ??
        controller.departureDate ??
        DateTime.now().add(const Duration(days: 1));

    // El buscador queda reflejando la ruta recién vista, igual que al
    // tocar un destino popular.
    controller.setOrigin(origin);
    controller.setDestination(destination);

    // Dos señales del mismo gesto (mismo patrón que el tap de destino):
    // la tarjeta fue abierta y, como además navega a resultados, es
    // también una búsqueda.
    final tracker = context.read<UserEventTracker>();
    tracker.track(
      'offer_click',
      context: 'home',
      payload: {
        'origin': origin.code,
        'destination': destination.code,
        'departureDate': departureDate.toIso8601String().split('T').first,
        'source': 'promotion_card',
      },
    );
    tracker.track(
      'search',
      context: 'home',
      payload: {
        'origin': origin.code,
        'destination': destination.code,
        'departureDate': departureDate.toIso8601String().split('T').first,
        'adults': '${controller.passengers.adults}',
        'children': '${controller.passengers.children}',
        'tripType': controller.tripType == TripType.roundTrip
            ? 'ROUND_TRIP'
            : 'ONE_WAY',
        'source': 'promotion_card',
      },
    );

    final params = FlightSearchParams(
      tripType: controller.tripType,
      origin: origin,
      destination: destination,
      departureDate: departureDate,
      returnDate: controller.tripType == TripType.roundTrip
          ? (controller.returnDate ??
              departureDate.add(const Duration(days: 3)))
          : null,
      passengers: controller.passengers,
    );

    _pushFlights(context, params);
  }

  /// Aeropuerto del catálogo por código IATA, o `null` si el catálogo
  /// todavía no cargó o no lo trae.
  static AirportModel? _airportByCode(
    List<AirportModel> airports,
    String? code,
  ) {
    if (code == null) return null;
    for (final airport in airports) {
      if (airport.code == code) return airport;
    }
    return null;
  }

  /// Navega a los resultados con la transición fade+slide de Home.
  void _pushFlights(BuildContext context, FlightSearchParams params) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, animation, __) => FlightsScreen(searchParams: params),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: controller.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.4,
                ),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: controller.loadHomeData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                    AppSpacing.screenPadding,
                    AppSpacing.xxxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const HomeHeader(),
                          const SizedBox(height: 22),
                          SearchCard(controller: controller),
                          const SizedBox(height: 30),
                          const SectionTitle(title: 'Promociones'),
                          const SizedBox(height: 14),
                          PromotionSlider(
                            promotions: controller.promotions,
                            onSelect: (promotion) => _handlePromotionTap(
                                context, controller, promotion),
                          ),
                          const SizedBox(height: 30),
                          const SectionTitle(title: 'Destinos populares'),
                          const SizedBox(height: 14),
                          DestinationList(
                            destinations: controller.popularDestinations,
                            onDestinationTap: (airport) =>
                                _handleDestinationTap(
                                    context, controller, airport),
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
