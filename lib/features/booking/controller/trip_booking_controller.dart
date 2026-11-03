import 'package:flutter/foundation.dart';
import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/features/booking/widgets/baggage_option.dart';
import 'package:royal_airlines/features/flights/repository/flight_repository.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/seat_map_model.dart';
import 'package:royal_airlines/models/seat_pricing.dart';

/// TripLegType
/// -----------
/// Identifica en qué tramo del viaje está el usuario cuando el tipo
/// de viaje es "Ida y vuelta". Para "Solo ida" no se usa — ese flujo
/// usa directamente [TripBookingController] con un solo tramo.
enum TripLegType { outbound, returnLeg }

/// LegBooking
/// ----------
/// Selección completa de UN tramo: vuelo, tarifa, asientos, equipaje y
/// el mapa real de asientos del vuelo. Ida y Regreso tienen cada uno su
/// propia instancia independiente, con su propio cálculo de subtotal —
/// nunca se mezclan entre sí.
class LegBooking {
  LegBooking({
    required this.flight,
    required this.fare,
    required this.requiredSeatCount,
  });

  FlightModel flight;
  FareModel fare;
  final List<String> selectedSeats = [];
  BaggageOption baggageOption = BaggageOption.included;
  bool travelInsurance = false;
  bool priorityBoarding = false;
  final int requiredSeatCount;

  /// Mapa REAL de asientos del vuelo (`GET /flights/{id}/seats`):
  /// distribución, precios por categoría en COP y asientos tomados.
  /// Es la fuente de verdad para pintar el mapa y calcular el cargo
  /// por asiento; `null` mientras no cargue.
  SeatMapModel? seatMap;

  /// Estado de la carga del mapa de ESTE tramo.
  bool seatMapLoading = false;
  String? seatMapError;

  double get fareSubtotal => fare.price * requiredSeatCount;

  /// Precio del asiento según la categoría del mapa del VUELO (los
  /// importes en COP los manda el backend). Solo se cae al tarifario
  /// local de [SeatPricing] mientras el mapa no haya cargado, para que
  /// el total nunca se quede en cero por un retardo de red.
  double seatPriceFor(String seatCode) {
    final map = seatMap;
    if (map != null) return map.priceForSeat(seatCode);
    return SeatPricing.categoryForSeat(seatCode).price.toDouble();
  }

  double get seatCharge => selectedSeats.fold<double>(
        0,
        (sum, code) => sum + seatPriceFor(code),
      );

  double get travelExtrasPrice {
    var total = 0.0;
    if (travelInsurance) total += 25000;
    if (priorityBoarding) total += 18000;
    return total;
  }

  double get totalPrice =>
      fareSubtotal + seatCharge + baggageOption.price + travelExtrasPrice;

  bool get hasRequiredSeats => selectedSeats.length == requiredSeatCount;

  /// Etiquetas de `extras` enviadas en `POST /booking/create`, que
  /// espera una LISTA de strings (≤20, cada uno ≤40 caracteres). Los
  /// extras de ASIENTO (SEAT_PREFERENTE, SEAT_EXTRA_LEGROOM,
  /// SEAT_WINDOW, ...) los deriva el backend a partir de los códigos,
  /// así que aquí solo viajan los contratados por el usuario.
  List<String> get bookingExtras => [
        if (baggageOption.extraTag.isNotEmpty) baggageOption.extraTag,
        if (travelInsurance) 'TRAVEL_INSURANCE',
        if (priorityBoarding) 'PRIORITY_BOARDING',
      ];
}

/// TripBookingController
/// ----------------------
/// Coordina la reserva de un viaje "Ida y vuelta": mantiene DOS
/// [LegBooking] independientes y sabe en todo momento cuál tramo está
/// activo ([currentLeg]). Una única instancia se crea al elegir la
/// tarifa de ida (en [FlightsScreen]) y se pasa por constructor a
/// través de [LegBookingScreen] -> [FlightsScreen] (regreso) ->
/// [LegBookingScreen] (regreso) -> [CheckoutScreen]. No se registra
/// vía Provider porque su ciclo de vida atraviesa varias rutas del
/// Navigator que no comparten el mismo subárbol de widgets.
///
/// También administra el mapa de asientos de cada tramo vía
/// [FlightRepository.fetchSeatMap], incluida la recuperación tras un
/// 409 de "asiento ya tomado" ([reloadSeatMapsAfterConflict]).
class TripBookingController extends ChangeNotifier {
  TripBookingController({
    required this.isRoundTrip,
    required this.requiredSeatCount,
    FlightRepository? repository,
  }) : _repository = repository ?? FlightRepository();

  final bool isRoundTrip;
  final int requiredSeatCount;
  final FlightRepository _repository;

  LegBooking? outbound;
  LegBooking? returnLeg;
  TripLegType currentLeg = TripLegType.outbound;

  LegBooking? get currentLegBooking =>
      currentLeg == TripLegType.outbound ? outbound : returnLeg;

  LegBooking? legFor(TripLegType legType) =>
      legType == TripLegType.outbound ? outbound : returnLeg;

  void setOutboundSelection(FlightModel flight, FareModel fare) {
    outbound = LegBooking(
      flight: flight,
      fare: fare,
      requiredSeatCount: requiredSeatCount,
    );
    notifyListeners();
  }

  void setReturnSelection(FlightModel flight, FareModel fare) {
    returnLeg = LegBooking(
      flight: flight,
      fare: fare,
      requiredSeatCount: requiredSeatCount,
    );
    notifyListeners();
  }

  void setCurrentLeg(TripLegType leg) {
    currentLeg = leg;
    notifyListeners();
  }

  void changeFare(FareModel fare) {
    final leg = currentLegBooking;
    if (leg == null) return;
    leg.fare = fare;
    notifyListeners();
  }

  /// Carga (o recarga) el mapa de asientos real de un tramo desde
  /// `GET /flights/{flightId}/seats`.
  ///
  /// Al refrescar, los asientos de la selección que ya no están libres
  /// (alguien más los tomó entre tanto) se descartan: el mapa es la
  /// fuente de verdad, no la selección local.
  Future<void> loadSeatMap(TripLegType legType) async {
    final leg = legFor(legType);
    if (leg == null || leg.seatMapLoading) return;

    leg.seatMapLoading = true;
    leg.seatMapError = null;
    notifyListeners();

    try {
      final map = await _repository.fetchSeatMap(leg.flight.id);
      leg.seatMap = map;
      leg.selectedSeats.removeWhere(map.isTaken);
      leg.seatMapLoading = false;
    } on ApiException catch (e) {
      leg.seatMapLoading = false;
      leg.seatMapError = e.message;
    } catch (_) {
      leg.seatMapLoading = false;
      leg.seatMapError = 'No se pudo cargar el mapa de asientos.';
    }
    notifyListeners();
  }

  /// Tras un 409 de "asiento ya tomado" en el checkout: recarga los
  /// mapas de TODOS los tramos (en un viaje redondo puede haber
  /// cambiado cualquiera de los dos) y depura la selección con los
  /// asientos que siguen libres.
  Future<void> reloadSeatMapsAfterConflict() async {
    await loadSeatMap(TripLegType.outbound);
    if (isRoundTrip) await loadSeatMap(TripLegType.returnLeg);
  }

  void toggleSeat(String seatCode) {
    final leg = currentLegBooking;
    if (leg == null) return;
    if (leg.selectedSeats.contains(seatCode)) {
      leg.selectedSeats.remove(seatCode);
    } else if (leg.seatMap?.isTaken(seatCode) == true) {
      // El mapa ya marcaba el asiento como tomado: no se puede elegir.
      return;
    } else if (leg.selectedSeats.length < requiredSeatCount) {
      leg.selectedSeats.add(seatCode);
    } else {
      return;
    }
    notifyListeners();
  }

  void setBaggage(BaggageOption option) {
    final leg = currentLegBooking;
    if (leg == null) return;
    leg.baggageOption = option;
    notifyListeners();
  }

  void setTravelInsurance(bool enabled) {
    final leg = currentLegBooking;
    if (leg == null) return;
    leg.travelInsurance = enabled;
    notifyListeners();
  }

  void setPriorityBoarding(bool enabled) {
    final leg = currentLegBooking;
    if (leg == null) return;
    leg.priorityBoarding = enabled;
    notifyListeners();
  }

  double get grandTotal {
    double total = outbound?.totalPrice ?? 0;
    if (isRoundTrip) total += returnLeg?.totalPrice ?? 0;
    return total;
  }
}
