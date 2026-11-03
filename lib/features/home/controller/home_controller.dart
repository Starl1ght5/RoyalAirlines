import 'package:flutter/foundation.dart';
import 'package:royal_airlines/features/home/repository/home_repository.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/promotion_model.dart';

/// TripType
/// --------
/// Tipo de viaje seleccionado en el buscador.
enum TripType { roundTrip, oneWay }

/// PassengerCount
/// --------------
/// Conteo de pasajeros por categoría. Se modela como clase inmutable
/// (con `copyWith`) en vez de 3 enteros sueltos en el controller, para
/// que [PassengerSelector] pueda manipular una sola referencia y para
/// facilitar validaciones futuras (ej. "infantes no puede superar adultos").
class PassengerCount {
  final int adults;
  final int children;
  final int infants;

  const PassengerCount({
    this.adults = 1,
    this.children = 0,
    this.infants = 0,
  });

  int get total => adults + children + infants;

  /// Texto resumen mostrado en el buscador, ej. "2 Adultos, 1 Niño".
  String get summary {
    final parts = <String>[];
    parts.add('$adults ${adults == 1 ? 'Adulto' : 'Adultos'}');
    if (children > 0) {
      parts.add('$children ${children == 1 ? 'Niño' : 'Niños'}');
    }
    if (infants > 0) {
      parts.add('$infants ${infants == 1 ? 'Infante' : 'Infantes'}');
    }
    return parts.join(', ');
  }

  PassengerCount copyWith({int? adults, int? children, int? infants}) {
    return PassengerCount(
      adults: adults ?? this.adults,
      children: children ?? this.children,
      infants: infants ?? this.infants,
    );
  }
}

/// HomeController
/// --------------
/// Gestor de estado (Provider/ChangeNotifier) de la pantalla Home:
///   - Estado del formulario de búsqueda (tipo de viaje, origen/destino,
///     fechas, pasajeros, clase).
///   - Datos cargados desde [HomeRepository] (aeropuertos, promociones,
///     destinos populares).
///
/// La UI (HomeScreen y sus widgets) solo lee estas propiedades y llama
/// a estos métodos; nunca accede a [HomeRepository] directamente.
class HomeController extends ChangeNotifier {
  HomeController({HomeRepository? repository})
      : _repository = repository ?? HomeRepository();

  final HomeRepository _repository;

  // --- Estado del formulario de búsqueda ---

  /// Tipo de viaje por defecto del buscador: "Solo ida".
  ///
  /// Antes arrancaba en [TripType.roundTrip], lo que hacía que la
  /// opción "Ida y vuelta" apareciera SIEMPRE preseleccionada y
  /// encadenara un tramo de regreso (ver [TripBookingController]) aun
  /// cuando la persona solo quisiera un tramo. "Solo ida" es el
  /// camino más simple: quien quiera un viaje redondo lo elige
  /// explícitamente en [TripTypeSelector].
  TripType _tripType = TripType.oneWay;
  AirportModel? _origin = defaultOrigin;
  AirportModel? _destination;
  DateTime? _departureDate;
  DateTime? _returnDate;
  PassengerCount _passengers = const PassengerCount();

  // --- Datos cargados ---
  List<AirportModel> _airports = [];
  List<PromotionModel> _promotions = [];
  List<AirportModel> _popularDestinations = [];
  bool _isLoading = false;

  TripType get tripType => _tripType;
  AirportModel? get origin => _origin;
  AirportModel? get destination => _destination;
  DateTime? get departureDate => _departureDate;
  DateTime? get returnDate => _returnDate;
  PassengerCount get passengers => _passengers;

  List<AirportModel> get airports => _airports;
  List<PromotionModel> get promotions => _promotions;
  List<AirportModel> get popularDestinations => _popularDestinations;
  bool get isLoading => _isLoading;

  static const AirportModel defaultOrigin = AirportModel(
    code: 'CTG',
    city: 'Cartagena',
    country: 'Colombia',
    airportName: 'Aeropuerto Internacional Rafael Núñez',
  );

    List<AirportModel> get originOptions => [
        if (!_airports.any((a) => a.code == defaultOrigin.code)) defaultOrigin,
        ..._airports,
      ];

  /// Carga inicial de datos. Se llama una sola vez al crear el
  /// controller (ver [HomeScreen]) y también en cada pull-to-refresh.
  ///
  /// Cada recurso se pide por SEPARADO, no con un `Future.wait`
  /// único. El backend puede exponer unos endpoints y no otros (o
  /// cualquiera puede caerse), y con un `Future.wait` un solo error
  /// tumba TODOS los datos de Home — incluidos los destinos — sin
  /// dejar rastro, porque el error se tragaba en un `catch (_)` mudo.
  ///
  /// Ahora cada carga aísla su propio fallo: lo que sí se pudo cargar
  /// se muestra, lo que no se conserva lo que ya había y el error
  /// queda registrado en la consola para poder diagnosticarlo.
  Future<void> loadHomeData() async {
    _isLoading = true;
    notifyListeners();

    final airports = await _loadSafely(_repository.getAirports, 'aeropuertos');
    final promotions =
        await _loadSafely(_repository.getPromotions, 'promociones');
    final destinations =
        await _loadSafely(_repository.getPopularDestinations, 'destinos');

    if (airports != null) _airports = airports;
    if (promotions != null) _promotions = promotions;
    if (destinations != null) _popularDestinations = destinations;

    // Origen/destino iniciales sugeridos, si hay suficientes aeropuertos.
    // Solo si el usuario todavía no eligió: un refresh no debe pisar
    // lo que la persona ya había escogido en el buscador.
    if (_airports.length >= 2) {
      _origin ??= _airports[0];
      _destination ??= _airports[1];
    }

    _isLoading = false;
    notifyListeners();
  }


  /// Carga un recurso sin dejar que su fallo tumbe el resto de Home.
  ///
  /// Devuelve `null` si la carga falló, para que el controller pueda
  /// distinguir "no hay datos" de "el endpoint falló" y dejar intacto
  /// el valor anterior.
  Future<List<T>?> _loadSafely<T>(
    Future<List<T>> Function() loader,
    String label,
  ) async {
    try {
      return await loader();
    } catch (error) {
      // Antes esto se tragaba el error sin más. Se registra para que un
      // endpoint caído o con otro contrato se pueda ver desde la
      // consola en vez de aparecer como una pantalla vacía sin
      // explicación.
      debugPrint('[Home] No se pudo cargar $label: $error');
      return null;
    }
  }

  void setTripType(TripType type) {
    _tripType = type;
    // Un vuelo solo de ida no necesita fecha de regreso.
    if (type == TripType.oneWay) _returnDate = null;
    notifyListeners();
  }

  void setOrigin(AirportModel airport) {
    _origin = airport;
    notifyListeners();
  }

  void setDestination(AirportModel airport) {
    _destination = airport;
    notifyListeners();
  }

  /// Intercambia origen y destino (botón de swap en el buscador).
  void swapAirports() {
    final temp = _origin;
    _origin = _destination;
    _destination = temp;
    notifyListeners();
  }

  void setDepartureDate(DateTime date) {
    _departureDate = date;
    // Si la fecha de regreso quedó antes de la nueva salida, se limpia.
    if (_returnDate != null && _returnDate!.isBefore(date)) {
      _returnDate = null;
    }
    notifyListeners();
  }

  void setReturnDate(DateTime date) {
    _returnDate = date;
    notifyListeners();
  }

  void updatePassengers(PassengerCount count) {
    _passengers = count;
    notifyListeners();
  }
}
