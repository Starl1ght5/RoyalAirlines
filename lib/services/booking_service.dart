import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';

/// BookingService
/// --------------
/// Servicio de reservas contra el backend real del MVP, cuyo
/// controlador vive bajo `/api/v1/booking` (todas las rutas piden JWT,
/// salvo las que el backend declara públicas).
///
/// El flujo es SIEMPRE create → confirm (el MVP no tiene pasarela de
/// pago: "pagar" es confirmar la reserva):
/// 1. `POST /booking/create` nace la reserva `PENDING` con los
///    asientos RETENIDOS y responde con su id. Si otro usuario tomó
///    uno de los asientos, el backend responde **409** (se propaga como
///    [ApiException] con `statusCode == 409`).
/// 2. `PATCH /booking/confirm?id=` pasa la reserva a `CONFIRMED`. El id
///    viaja como QUERY param — el backend no lo lee del cuerpo.
class BookingService {
  BookingService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Crea una reserva (`CreateBookingRequest`) y devuelve su id.
  ///
  /// [seats] es OBLIGATORIO (1..9 asientos, formato `^\d{1,2}[A-F]$`)
  /// y [passengerAges] debe llevar UNA EDAD POR CADA ASIENTO, si no el
  /// backend responde 400. Los extras de asiento (SEAT_PREFERENTE,
  /// SEAT_EXTRA_LEGROOM, SEAT_WINDOW, ...) los deriva el backend a
  /// partir de los códigos: aquí solo viajan los contratados por el
  /// usuario (equipaje extra, seguro, embarque preferente).
  Future<String> createBooking({
    required String flightId,
    required String feeId,
    required List<String> seats,
    required List<int> passengerAges,
    required bool isRoundTrip,
    int? stayDays,
    List<String> extras = const [],
    String source = 'MANUAL_SEARCH',
  }) async {
    final response = await _client.post(
      ApiEndpoints.bookingCreate,
      body: {
        'flightID': flightId,
        'feeID': feeId,
        'seats': seats,
        'tripType': isRoundTrip ? 'ROUND_TRIP' : 'ONE_WAY',
        if (isRoundTrip && stayDays != null) 'stayDays': stayDays,
        if (passengerAges.isNotEmpty) 'passengerAges': passengerAges,
        // El backend limita `extras` a 20 etiquetas de ≤40 caracteres.
        if (extras.isNotEmpty)
          'extras': extras.where((extra) => extra.isNotEmpty).take(20).toList(),
        'source': source,
      },
    );

    // El backend responde 201 con SOLO el id de la reserva (texto
    // plano o string JSON); [ApiClient] lo normaliza en `data`.
    final data = response['data'];
    final bookingId = data is String ? data.trim() : '';
    if (bookingId.isEmpty) {
      throw const ApiException(
        'El backend no devolvió el identificador de reserva.',
      );
    }
    return bookingId;
  }

  /// Confirma (paga) una reserva `PENDING`: `PATCH /booking/confirm?id=`.
  ///
  /// Si la reserva ya no está pendiente (por ejemplo, expiró a los 15
  /// minutos y el backend la canceló), responde 409 y se propaga.
  Future<void> confirmBooking(String bookingId) async {
    await _client.patch(
      ApiEndpoints.bookingConfirm,
      queryParameters: {'id': bookingId},
    );
  }
}
