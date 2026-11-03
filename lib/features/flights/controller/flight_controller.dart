import 'package:flutter/foundation.dart';
import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/features/flights/repository/flight_repository.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart'
    show TripType, PassengerCount;
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/flight_model.dart';

/// FlightSearchParams
/// -------------------
/// Snapshot inmutable de los criterios de búsqueda capturados en el
/// [SearchCard] de Home. Se define aquí (no en `models/`) porque es un
/// objeto de "traspaso" entre dos pantallas, no una entidad de dominio
/// persistente como [FlightModel] o [AirportModel].
class FlightSearchParams {
  final TripType tripType;
  final AirportModel origin;
  final AirportModel destination;
  final DateTime departureDate;
  final DateTime? returnDate;
  final PassengerCount passengers;

  const FlightSearchParams({
    required this.tripType,
    required this.origin,
    required this.destination,
    required this.departureDate,
    this.returnDate,
    required this.passengers,
  });
}

/// SortOption
/// ----------
/// Criterios de ordenamiento disponibles para los resultados.
enum SortOption { priceAsc, priceDesc, duration, earliestDeparture }

/// StopsFilter
/// -----------
/// Filtro de escalas disponible en [FilterSheet].
enum StopsFilter { all, direct, oneStop }

/// FlightController
/// -----------------
/// Gestor de estado de la pantalla Flights: carga los resultados desde
/// [FlightRepository] según [FlightSearchParams], y expone la lista ya
/// filtrada/ordenada según las preferencias del usuario ([sortOption],
/// [stopsFilter]). La UI (FlightsScreen, FilterSheet) nunca ordena ni
/// filtra por su cuenta — solo lee [visibleFlights].
class FlightController extends ChangeNotifier {
  FlightController({
    required this.searchParams,
    FlightRepository? repository,
  }) : _repository = repository ?? FlightRepository();

  final FlightSearchParams searchParams;
  final FlightRepository _repository;

  List<FlightModel> _flights = [];
  bool _isLoading = false;
  String? _errorMessage;

  SortOption _sortOption = SortOption.priceAsc;
  StopsFilter _stopsFilter = StopsFilter.all;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SortOption get sortOption => _sortOption;
  StopsFilter get stopsFilter => _stopsFilter;

  /// Lista final que debe pintar la UI: ya filtrada y ordenada.
  /// Se recalcula en cada acceso (la lista base rara vez supera pocas
  /// decenas de elementos en este mock, así que no hace falta cachear).
  List<FlightModel> get visibleFlights {
    var result = _flights.where(_matchesStopsFilter).toList();
    result.sort(_compareBySortOption);
    return result;
  }

  int get resultsCount => visibleFlights.length;

  /// Vuelo recomendado como "⭐ Mejor opción" entre los resultados
  /// visibles: combina precio, duración y qué tan ocupado está, para
  /// premiar el vuelo más barato, rápido y con más disponibilidad a
  /// la vez (no solo el más barato). Es una fórmula simple de puntaje
  /// (menor puntaje = mejor), pensada para lucir "inteligente" sin
  /// requerir un modelo real.
  FlightModel? get bestOptionFlight {
    final flights = visibleFlights;
    if (flights.length < 2) return null;

    final cheapestPrice = flights
        .map((f) => f.cheapestFare.price)
        .reduce((a, b) => a < b ? a : b);
    final shortestMinutes = flights
        .map((f) => f.duration.inMinutes)
        .reduce((a, b) => a < b ? a : b);

    FlightModel? best;
    double bestScore = double.infinity;
    for (final flight in flights) {
      final priceScore = flight.cheapestFare.price / cheapestPrice;
      final durationScore = flight.duration.inMinutes / shortestMinutes;
      final occupancyScore = flight.demandForecast.fillProbability;
      final score =
          priceScore * 0.5 + durationScore * 0.3 + occupancyScore * 0.2;
      if (score < bestScore) {
        bestScore = score;
        best = flight;
      }
    }
    return best;
  }

  // -------------------------------------------------------------------
  // Comparación de vuelos
  // -------------------------------------------------------------------

  /// Máximo de vuelos que se pueden comparar a la vez. Con más de 3
  /// columnas la tabla deja de caber en pantallas de ~6".
  static const int maxCompare = 3;

  final Set<String> _compareIds = {};

  int get compareCount => _compareIds.length;

  bool isInCompare(String flightId) => _compareIds.contains(flightId);

  /// Vuelos marcados para comparar, en el mismo orden de la búsqueda.
  List<FlightModel> get compareFlights =>
      _flights.where((f) => _compareIds.contains(f.id)).toList();

  /// Agrega o quita un vuelo de la comparación. Devuelve `false` si el
  /// vuelo NO se pudo agregar por alcanzar [maxCompare] (la UI usa eso
  /// para avisar al usuario); quitar siempre devuelve `true`.
  bool toggleCompare(FlightModel flight) {
    if (!_compareIds.remove(flight.id)) {
      if (_compareIds.length >= maxCompare) return false;
      _compareIds.add(flight.id);
    }
    notifyListeners();
    return true;
  }

  void clearCompare() {
    if (_compareIds.isEmpty) return;
    _compareIds.clear();
    notifyListeners();
  }

  Future<void> loadFlights() async {
    _isLoading = true;
    _errorMessage = null;
    // Una búsqueda nueva invalida la selección: esos ids ya no existen.
    _compareIds.clear();
    notifyListeners();

    try {
      _flights = await _repository.searchFlights(
        origin: searchParams.origin,
        destination: searchParams.destination,
        date: searchParams.departureDate,
        returnDate: searchParams.returnDate,
        passengers: searchParams.passengers.total,
      );
    } on ApiException catch (e) {
      _flights = [];
      _errorMessage = e.message;
    } catch (_) {
      _flights = [];
      _errorMessage = 'No se pudieron cargar los vuelos. Intenta de nuevo.';
    }

    _isLoading = false;
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void setStopsFilter(StopsFilter filter) {
    _stopsFilter = filter;
    notifyListeners();
  }

  /// El backend real NO tiene `GET /flights/{flightId}`: el detalle
  /// completo del vuelo (tarifas incluidas) viaja dentro de
  /// `GET /flights/search`, cuyo resultado ya está en memoria. Por eso
  /// este método ya NO hace llamada de red y devuelve el vuelo tal
  /// como vino de la búsqueda — se conserva como punto de extensión
  /// (y para no romper las pantallas que lo llaman) por si el backend
  /// agrega una ruta de detalle en el futuro.
  Future<FlightModel> refreshFlightDetail(FlightModel flight) async => flight;

  bool _matchesStopsFilter(FlightModel flight) {
    switch (_stopsFilter) {
      case StopsFilter.all:
        return true;
      case StopsFilter.direct:
        return flight.isDirect;
      case StopsFilter.oneStop:
        return flight.stops <= 1;
    }
  }

  int _compareBySortOption(FlightModel a, FlightModel b) {
    switch (_sortOption) {
      case SortOption.priceAsc:
        return a.cheapestFare.price.compareTo(b.cheapestFare.price);
      case SortOption.priceDesc:
        return b.cheapestFare.price.compareTo(a.cheapestFare.price);
      case SortOption.duration:
        return a.duration.compareTo(b.duration);
      case SortOption.earliestDeparture:
        return a.departureTime.compareTo(b.departureTime);
    }
  }
}
