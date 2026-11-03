import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/features/flights/controller/flight_controller.dart';
import 'package:royal_airlines/features/flights/screens/flights_screen.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart';
import 'package:royal_airlines/features/home/widgets/passenger_selector.dart';
import 'package:royal_airlines/features/home/widgets/selector_field.dart';
import 'package:royal_airlines/features/home/widgets/trip_type_selector.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/services/user_event_tracker.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// SearchCard
/// ----------
/// Tarjeta elevada con todo el formulario de búsqueda de vuelos.
class SearchCard extends StatelessWidget {
  final HomeController controller;

  const SearchCard({super.key, required this.controller});

  Future<void> _pickDepartureDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: controller.departureDate ??
          DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) controller.setDepartureDate(date);
  }

  Future<void> _pickReturnDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: controller.returnDate ??
          controller.departureDate?.add(const Duration(days: 3)) ??
          DateTime.now().add(const Duration(days: 4)),
      firstDate: controller.departureDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) controller.setReturnDate(date);
  }

  void _handleSearch(BuildContext context) {
    if (controller.origin == null || controller.destination == null) {
      _showValidationError(context, 'Selecciona origen y destino');
      return;
    }
    if (controller.departureDate == null) {
      _showValidationError(context, 'Selecciona la fecha de salida');
      return;
    }
    if (controller.tripType == TripType.roundTrip &&
        controller.returnDate == null) {
      _showValidationError(context, 'Selecciona la fecha de regreso');
      return;
    }

    final params = FlightSearchParams(
      tripType: controller.tripType,
      origin: controller.origin!,
      destination: controller.destination!,
      departureDate: controller.departureDate!,
      returnDate: controller.returnDate,
      passengers: controller.passengers,
    );

    // Señal más barata y más valiosa del recomendador: qué buscó la
    // persona, con qué y cuántas veces. Solo sale si hay
    // consentimiento de tracking (ver UserEventTracker).
    context.read<UserEventTracker>().track(
      'search',
      context: 'home',
      payload: {
        'origin': params.origin.code,
        'destination': params.destination.code,
        'departureDate':
            params.departureDate.toIso8601String().split('T').first,
        if (params.returnDate != null)
          'returnDate': params.returnDate!.toIso8601String().split('T').first,
        'adults': '${params.passengers.adults}',
        'children': '${params.passengers.children}',
        'tripType':
            params.tripType == TripType.roundTrip ? 'ROUND_TRIP' : 'ONE_WAY',
        'source': 'search_form',
      },
    );

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

  void _showValidationError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TripTypeSelector(
            selected: controller.tripType,
            onChanged: controller.setTripType,
          ),
          const SizedBox(height: AppSpacing.lg),
          _OriginDestinationFields(controller: controller),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SelectorField(
                  icon: Icons.calendar_today_rounded,
                  label: 'Salida',
                  value: controller.departureDate != null
                      ? _formatDate(controller.departureDate!)
                      : 'Elegir fecha',
                  onTap: () => _pickDepartureDate(context),
                ),
              ),
              if (controller.tripType == TripType.roundTrip) ...[
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: SelectorField(
                    icon: Icons.calendar_today_rounded,
                    label: 'Regreso',
                    value: controller.returnDate != null
                        ? _formatDate(controller.returnDate!)
                        : 'Elegir fecha',
                    onTap: () => _pickReturnDate(context),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PassengerSelector(
            value: controller.passengers,
            onChanged: controller.updatePassengers,
          ),
          const SizedBox(height: AppSpacing.xl),
          CustomButton(
            label: 'Buscar vuelos',
            onPressed: () => _handleSearch(context),
          ),
        ],
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
}

class _OriginDestinationFields extends StatefulWidget {
  final HomeController controller;
  const _OriginDestinationFields({required this.controller});

  @override
  State<_OriginDestinationFields> createState() =>
      _OriginDestinationFieldsState();
}

class _OriginDestinationFieldsState extends State<_OriginDestinationFields> {
  double _turns = 0;

  Future<void> _pickAirport({
    required BuildContext context,
    required bool isOrigin,
  }) async {
    final selected = await showModalBottomSheet<AirportModel>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AirportPickerSheet(
        title: isOrigin ? 'Origen' : 'Destino',
        airports: widget.controller.airports,
      ),
    );
    if (selected == null) return;
    if (isOrigin) {
      widget.controller.setOrigin(selected);
    } else {
      widget.controller.setDestination(selected);
    }
  }

  void _handleSwap() {
    setState(() => _turns += 0.5);
    widget.controller.swapAirports();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            SelectorField(
              icon: Icons.flight_takeoff_rounded,
              label: 'Origen',
              value: controller.origin?.shortLabel ?? 'Elegir origen',
              onTap: () => _pickAirport(context: context, isOrigin: true),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            SelectorField(
              icon: Icons.flight_land_rounded,
              label: 'Destino',
              value: controller.destination?.shortLabel ?? 'Elegir destino',
              onTap: () => _pickAirport(context: context, isOrigin: false),
            ),
          ],
        ),
        Positioned(
          right: 14,
          child: GestureDetector(
            onTap: _handleSwap,
            child: AnimatedRotation(
              turns: _turns,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.swap_vert_rounded,
                  color: AppColors.gold,
                  size: 17,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AirportPickerSheet extends StatelessWidget {
  final String title;
  final List<AirportModel> airports;

  const _AirportPickerSheet({required this.title, required this.airports});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Seleccionar $title',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: airports.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (context, index) {
                    final airport = airports[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        airport.city,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${airport.airportName}, ${airport.country}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Text(
                        airport.code,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(airport),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
