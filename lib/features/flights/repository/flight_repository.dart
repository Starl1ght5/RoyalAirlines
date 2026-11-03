import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/seat_map_model.dart';
import 'package:royal_airlines/services/flight_service.dart';

/// FlightRepository
/// -----------------
/// Única responsable de proveer los resultados de búsqueda de vuelos.
/// Delega en [FlightService], que llama a `GET /flights/search` del
/// backend real — las tarifas, beneficios y cupos vienen del servidor,
/// nunca se generan en el frontend.
class FlightRepository {
  FlightRepository({FlightService? flightService})
      : _flightService = flightService ?? FlightService();

  final FlightService _flightService;

  Future<List<FlightModel>> searchFlights({
    required AirportModel origin,
    required AirportModel destination,
    required DateTime date,
    DateTime? returnDate,
    int passengers = 1,
  }) {
    return _flightService.searchFlights(
      origin: origin.code,
      destination: destination.code,
      departureDate: date,
      returnDate: returnDate,
      passengers: passengers,
    );
  }

  /// Mapa de asientos de un vuelo (`GET /flights/{flightId}/seats`,
  /// ruta pública): cabina fija, precios por categoría en COP y los
  /// asientos ya tomados. Es lo que usa [SeatSelector] para pintar el
  /// mapa real de cada vuelo.
  Future<SeatMapModel> fetchSeatMap(String flightId) {
    return _flightService.fetchSeatMap(flightId);
  }
}
