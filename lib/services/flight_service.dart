import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/seat_map_model.dart';

/// FlightService
/// -------------
/// Servicio HTTP para buscar vuelos y consultar el mapa de asientos
/// contra el backend real (Spring Boot). Nunca genera datos localmente.
class FlightService {
  FlightService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<FlightModel>> searchFlights({
    required String origin,
    required String destination,
    required DateTime departureDate,
    DateTime? returnDate,
    int passengers = 1,
  }) async {
    final response = await _client.get(
      ApiEndpoints.flightsSearch,
      queryParameters: {
        'origin': origin,
        'destination': destination,
        // Fecha simple (yyyy-MM-dd) exactamente como pide el contrato:
        // un backend con LocalDate estricto rechazaría el ISO datetime.
        'departureDate': departureDate.toIso8601String().split('T').first,
        if (returnDate != null)
          'returnDate': returnDate.toIso8601String().split('T').first,
        'passengers': passengers.toString(),
      },
    );

    // El backend real responde con un ARRAY suelta; el contrato
    // anterior lo envolvía en `{data: [...]}`. Se aceptan las dos.
    final data = response['data'] ?? response['content'];
    final items = data is List ? data : const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(FlightModel.fromJson)
        .toList();
  }

  /// Mapa de asientos de un vuelo — `GET /flights/{flightId}/seats`
  /// (ruta PÚBLICA, no pide JWT).
  ///
  /// Devuelve la cabina fija del MVP (15 filas × A–F) con las
  /// categorías y sus precios en COP, las filas con espacio extra, los
  /// asientos tomados (retenidos + confirmados) y cuántos quedan
  /// libres. Es la fuente de verdad para elegir asiento: nunca se
  /// genera ocupación localmente.
  Future<SeatMapModel> fetchSeatMap(String flightId) async {
    final response = await _client.get(
      ApiEndpoints.flightSeats.replaceAll(
        '{flightId}',
        Uri.encodeComponent(flightId),
      ),
    );

    // El backend sirve el SeatMapDTO como objeto SUELTO (los arrays
    // sueltos [ApiClient] los envuelve en `data`, pero los objetos no):
    // se aceptan las dos formas para no depender del envoltorio.
    final data = response['data'] ?? response;
    if (data is! Map<String, dynamic>) {
      throw const ApiException('El backend no devolvió el mapa de asientos');
    }
    return SeatMapModel.fromJson(data);
  }
}
