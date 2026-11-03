import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/passenger_model.dart';
import 'package:royal_airlines/models/payment_model.dart';
import 'package:royal_airlines/models/reservation_model.dart';
import 'package:royal_airlines/services/booking_service.dart';
import 'package:royal_airlines/services/reservation_service.dart';

/// Error propio del flujo de reserva/pago, para que la UI pueda
/// mostrar un mensaje claro cuando el backend rechaza la operación.
class PaymentException implements Exception {
  const PaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// BookingRepository
/// -----------------
/// Única responsable de crear y confirmar una reserva contra el backend
/// real del MVP:
/// 1. `POST /booking/create` crea la reserva `PENDING` reteniendo los
///    asientos y devuelve su id. Si alguien más tomó uno de esos
///    asientos, el backend responde 409 y se propaga la [ApiException]
///    — la UI debe recargar el mapa de asientos.
/// 2. `PATCH /booking/confirm?id=` confirma (paga) la reserva. El MVP
///    no tiene pasarela de pago: los datos de la tarjeta se capturan
///    en el front pero no viajan al backend.
/// 3. `GET /booking/{id}` refresca la reserva para quedar con los
///    datos CANÓNICOS del servidor (importe total en COP, estado,
///    asientos). Si ese último paso falla, se devuelve la reserva
///    armada localmente — la compra ya está hecha y no se pierde.
class BookingRepository {
  BookingRepository({
    BookingService? bookingService,
    ReservationService? reservationService,
  })  : _bookingService = bookingService ?? BookingService(),
        _reservationService = reservationService ?? ReservationService();

  final BookingService _bookingService;
  final ReservationService _reservationService;

  Future<ReservationModel> confirmBooking({
    required FlightModel flight,
    required FareModel fare,
    required List<String> seats,
    required List<PassengerModel> passengers,
    required PaymentModel payment,
    required double totalPrice,
    required bool isRoundTrip,
    int? stayDays,
    List<String> extras = const [],
  }) async {
    final bookingId = await _bookingService.createBooking(
      flightId: flight.id,
      feeId: fare.feeID,
      seats: seats,
      // El backend exige UNA EDAD POR CADA ASIENTO. Se calcula al día
      // de la salida del vuelo, no al de hoy.
      passengerAges: passengers
          .map((passenger) => _ageAt(passenger.birthDate, flight.departureTime))
          .toList(),
      isRoundTrip: isRoundTrip,
      stayDays: stayDays,
      extras: extras,
    );

    await _bookingService.confirmBooking(bookingId);

    try {
      return await _reservationService.fetchReservationDetail(bookingId);
    } catch (_) {
      // La reserva YA QUEDÓ CONFIRMADA en el backend; si el refresco
      // falla (red, backend caído justo después) se devuelve la versión
      // local para que el usuario vea su código y no pierda la compra.
      return ReservationModel(
        id: bookingId,
        confirmationCode: bookingId,
        flight: flight,
        fare: fare,
        seats: seats,
        passengers: passengers,
        payment: payment,
        totalPrice: totalPrice,
        bookedAt: DateTime.now(),
        status: 'CONFIRMED',
      );
    }
  }

  /// Edad del pasajero al momento de [reference] (la salida del vuelo).
  int _ageAt(DateTime birthDate, DateTime reference) {
    var age = reference.year - birthDate.year;
    if (reference.month < birthDate.month ||
        (reference.month == birthDate.month && reference.day < birthDate.day)) {
      age--;
    }
    return age.clamp(0, 120);
  }
}
