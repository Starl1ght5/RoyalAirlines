import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/passenger_model.dart';
import 'package:royal_airlines/models/payment_model.dart';

/// ReservationModel
/// ----------------
/// Representa una reserva: el vuelo, la tarifa elegida, los asientos y
/// su estado en el backend. Es el modelo que lista el módulo
/// Reservations (tab "Mis Reservas") y el detalle en Profile.
///
/// Se deserializa desde el `BookingDTO` del backend real, cuyo shape es:
/// `bookingID`, `userID`, `bookedFight` (sic), `selectedFee`,
/// `totalPrice` (Money COP), `status`, `ticketCount`, `seats` (códigos
/// tipo "12B"), `flightID`, `feeID`, `companionType`, `cancelReason` y
/// `tripRating`. El parser es TOLERANTE: también acepta el shape propio
/// antiguo (`id`, `flight`, `fare`, `confirmationCode`, `bookedAt`) para
/// no romper el historial persistido en disco por [ReservationsStorage].
class ReservationModel {
  final String id;
  final String confirmationCode;
  final FlightModel flight;
  final FareModel fare;

  /// Códigos de asiento tipo "12B" (antes ObjectIds de butaca).
  final List<String> seats;

  final List<PassengerModel> passengers;
  final PaymentModel payment;
  final double totalPrice;
  final DateTime bookedAt;

  /// Estado de la reserva: `PENDING` | `CONFIRMED` | `CANCELED`.
  final String status;

  /// Motivo de cancelación (`USER` | `EXPIRED` | `SYSTEM`); solo viene
  /// cuando la reserva está cancelada.
  final String? cancelReason;

  /// Compañía con la que viaja (`SOLO` | `COUPLE` | `FAMILY` | `FRIENDS`
  /// | `BUSINESS`); `null` si el usuario no la indicó en el checkout.
  final String? companionType;

  /// Calificación del viaje dada por el usuario (1–5); `null` si aún no
  /// se calificó.
  final int? tripRating;

  const ReservationModel({
    required this.id,
    required this.confirmationCode,
    required this.flight,
    required this.fare,
    required this.seats,
    required this.passengers,
    required this.payment,
    required this.totalPrice,
    required this.bookedAt,
    this.status = 'CONFIRMED',
    this.cancelReason,
    this.companionType,
    this.tripRating,
  });

  bool get isCanceled => status == 'CANCELED';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isPending => status == 'PENDING';

  /// Código legible para la UI: últimos 8 caracteres en mayúsculas.
  /// El backend no emite un código de confirmación corto, así que el
  /// `bookingID` (ObjectId de 24 caracteres) se abrevia solo al mostrarlo.
  /// Para llamadas al API usa siempre [id].
  String get displayCode {
    final code = confirmationCode;
    return (code.length > 8 ? code.substring(code.length - 8) : code)
        .toUpperCase();
  }

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    // El backend del MVP no emite un código de confirmación separado:
    // el id de la reserva ES el código que ve el usuario.
    final bookingId =
        _readText(json['bookingID']) ?? _readText(json['id']) ?? '';

    return ReservationModel(
      id: bookingId,
      confirmationCode: _readText(json['confirmationCode']) ?? bookingId,
      flight: FlightModel.fromJson(_mapFrom(
        json['bookedFight'] ?? json['bookedFlight'] ?? json['flight'],
      )),
      fare: FareModel.fromJson(
          _mapFrom(json['selectedFee'] ?? json['fare'])),
      seats: (json['seats'] as List? ?? const [])
          .map((seat) => seat.toString())
          .toList(),
      // El backend no expande pasajeros ni medio de pago en el
      // BookingDTO: se quedan vacíos y la UI los muestra como
      // "no informado" en lugar de romper el parsing.
      passengers: (json['passengers'] as List? ?? const [])
          .whereType<Map>()
          .map((p) => PassengerModel.fromJson(p.cast<String, dynamic>()))
          .toList(),
      payment: json['payment'] is Map
          ? PaymentModel.fromJson(
              (json['payment'] as Map).cast<String, dynamic>())
          : const PaymentModel(
              cardHolderName: '',
              maskedCardNumber: '••••',
              expiry: '',
            ),
      totalPrice: _moneyCopFrom(json['totalPrice']),
      bookedAt: _dateFrom(json['bookedAt'] ?? json['bookingDate']),
      status: _readText(json['status']) ?? 'CONFIRMED',
      cancelReason: _readText(json['cancelReason']),
      companionType: _readText(json['companionType']),
      tripRating: (json['tripRating'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'confirmationCode': confirmationCode,
      'flight': flight.toJson(),
      'fare': fare.toJson(),
      'seats': seats,
      'passengers': passengers.map((p) => p.toJson()).toList(),
      'payment': payment.toJson(),
      'totalPrice': totalPrice,
      'bookedAt': bookedAt.toIso8601String(),
      'status': status,
      'cancelReason': cancelReason,
      'companionType': companionType,
      'tripRating': tripRating,
    };
  }
}

/// Lee un valor del JSON como texto, tolerando que venga null u otro
/// tipo (p. ej. enums serializados como string).
String? _readText(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  if (value == null) return null;
  return value.toString();
}

/// Convierte un mapa suelto a `Map<String, dynamic>`; si el valor no
/// es un mapa devuelve uno vacío para no tumbar el parsing completo.
Map<String, dynamic> _mapFrom(Object? value) {
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

/// Lee un importe monetario del backend.
///
/// Los precios viajan como objeto `Money` (Joda) con `amountMajor` ya
/// convertido a pesos colombianos; el contrato anterior mandaba un
/// número plano. Se aceptan las dos formas.
double _moneyCopFrom(Object? value) {
  if (value is num) return value.toDouble();
  if (value is Map) {
    final major = value['amountMajor'];
    if (major is num) return major.toDouble();
    final amount = value['amount'];
    if (amount is num) return amount.toDouble();
  }
  return 0;
}

/// Lee una fecha del JSON; si falta o viene mal formada usa el momento
/// actual en vez de reventar el parsing de la reserva completa.
DateTime _dateFrom(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}
