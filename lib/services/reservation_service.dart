import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';
import 'package:royal_airlines/models/reservation_model.dart';

/// ReservationService
/// ------------------
/// Servicio de historial y detalle de reservas contra el backend real
/// (`/api/v1/booking`), que responde con `BookingDTO`.
class ReservationService {
  ReservationService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Lista las reservas del usuario autenticado
  /// (`GET /booking/my` → `List<BookingDTO>`).
  ///
  /// A propósito NO recibe `userId`: el backend identifica al usuario
  /// por el token de la sesión (`Authorization`), no por un parámetro
  /// de la URL — así se evita que un cliente pueda pedir las reservas
  /// de otra cuenta cambiando un query param.
  Future<List<ReservationModel>> fetchReservations() async {
    final response = await _client.get(ApiEndpoints.bookingMy);

    // `GET /booking/my` responde con un ARRAY suelto; [ApiClient] lo
    // envuelve en `data`.
    final data = response['data'];
    final items = data is List ? data : const <dynamic>[];
    return items
        .whereType<Map>()
        .map((item) => ReservationModel.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// Detalle puntual de una reserva (`GET /booking/{bookingId}`):
  /// devuelve los datos MÁS ACTUALIZADOS (estado, asientos, importe en
  /// COP, calificación) que tenga el backend para esa reserva.
  Future<ReservationModel> fetchReservationDetail(String reservationId) async {
    final response = await _client.get(
      ApiEndpoints.bookingDetail.replaceAll(
        '{bookingId}',
        Uri.encodeComponent(reservationId),
      ),
    );

    // El backend sirve el BookingDTO como objeto SUELTO: se acepta
    // tanto ese shape como una eventual envoltura `{data: {...}}`.
    final data = response['data'] ?? response;
    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        'El backend no devolvió el detalle de la reserva',
      );
    }
    return ReservationModel.fromJson(data);
  }
}
