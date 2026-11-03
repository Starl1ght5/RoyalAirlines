import 'package:royal_airlines/core/utils/seat_occupancy.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/travel_class.dart';

/// FlightDemandForecast
/// --------------------
/// Estimación de qué tan probable es que este vuelo se llene, calculada
/// a partir de los asientos disponibles restantes frente a la
/// capacidad típica de la aeronave. Es la pieza "predictiva" (Minería
/// de datos 2) integrada directamente en el flujo de búsqueda/reserva,
/// no solo en una pantalla de estadísticas separada.
///
/// Hoy se calcula con una fórmula simple en el propio modelo (ver
/// [FlightModel.demandForecast]); cuando Python entregue su propio
/// score de probabilidad, este valor se puede reemplazar por el que
/// venga del backend sin cambiar la UI que lo consume.
class FlightDemandForecast {
  final double fillProbability; // 0.0 a 1.0
  final String level; // 'Alta', 'Media', 'Baja'

  const FlightDemandForecast({
    required this.fillProbability,
    required this.level,
  });

  bool get isUrgent => level == 'Alta';
}

/// PriceForecast
/// -------------
/// Estimación simple de hacia dónde podría moverse el precio de este
/// vuelo en los próximos días, calculada a partir de qué tan ocupado
/// está (a mayor ocupación, mayor probabilidad de que suba de precio).
/// Es el mismo tipo de placeholder que [FlightDemandForecast]: hoy es
/// una fórmula transparente en el modelo, mañana puede venir de un
/// modelo real de Python sin cambiar la UI.
class PriceForecast {
  final bool isRising; // true = sugiere comprar ya, false = puede esperar
  final int changePercent; // variación estimada en los próximos días

  const PriceForecast({
    required this.isRising,
    required this.changePercent,
  });
}

/// FareModel
/// ---------
/// Representa una tarifa disponible para un vuelo específico. Cada
/// tarifa incluye su lista de [benefits] (equipaje, cambios,
/// devoluciones, acumulación de puntos, etc.) para mostrarse en el
/// bottom sheet de selección, estilo aerolínea real.
///
/// El backend NO expone cupos por tarifa (el cupo real se controla
/// por asiento en `GET /booking/seats/{flightId}`), así que aquí solo
/// viajan los datos de presentación que sí vienen en `FaresDTO`:
/// [tierRank], [checkedBagKg] y [carryOnKg].
class FareModel {
  final TravelClass travelClass;
  final String tierName; // "Basic", "Light", "Full", "Premium Economy"

  /// Identificador de la tarifa en el backend (`feeID` de `FaresDTO`).
  /// Es OBLIGATORIO al crear la reserva: `POST /booking/create` pide el
  /// `feeID`, no el nombre comercial de la tarifa.
  final String feeID;

  final double price;

  /// Orden de la tarifa dentro de su clase (`tierRank` de `FaresDTO`).
  final int tierRank;

  /// Equipaje de bodega incluido, en kg (`checkedBagKg` de `FaresDTO`).
  final int checkedBagKg;

  /// Equipaje de mano incluido, en kg (`carryOnKg` de `FaresDTO`).
  final int carryOnKg;

  final List<String> benefits;

  const FareModel({
    required this.travelClass,
    required this.tierName,
    this.feeID = '',
    required this.price,
    this.tierRank = 0,
    this.checkedBagKg = 0,
    this.carryOnKg = 0,
    required this.benefits,
  });

  factory FareModel.fromJson(Map<String, dynamic> json) {
    return FareModel(
      travelClass:
          travelClassFromStorageKey(json['travelClass'] as String? ?? ''),
      tierName: json['tierName'] as String? ?? '',
      feeID: json['feeID'] as String? ?? '',
      price: _priceFrom(json['price']),
      tierRank: json['tierRank'] as int? ?? 0,
      checkedBagKg: json['checkedBagKg'] as int? ?? 0,
      carryOnKg: json['carryOnKg'] as int? ?? 0,
      benefits: (json['benefits'] as List? ?? const []).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'travelClass': travelClass.storageKey,
      'tierName': tierName,
      'feeID': feeID,
      'price': price,
      'tierRank': tierRank,
      'checkedBagKg': checkedBagKg,
      'carryOnKg': carryOnKg,
      'benefits': benefits,
    };
  }
}

/// FlightModel
/// -----------
/// Representa un vuelo ofrecido en los resultados de búsqueda.
class FlightModel {
  final String id;
  final String airline;
  final String flightNumber;
  final String aircraft;
  final AirportModel origin;
  final AirportModel destination;
  final DateTime departureTime;
  final DateTime arrivalTime;

  /// Número de escalas. 0 = vuelo directo.
  final int stops;

  final List<FareModel> fares;

  const FlightModel({
    required this.id,
    required this.airline,
    required this.flightNumber,
    required this.aircraft,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.arrivalTime,
    required this.stops,
    required this.fares,
  });

  Duration get duration => arrivalTime.difference(departureTime);

  bool get isDirect => stops == 0;

  String get stopsLabel {
    if (stops == 0) return 'Directo';
    return '$stops ${stops == 1 ? 'parada' : 'paradas'}';
  }

  /// Tarifa más económica disponible, usada para mostrar "desde $X".
  FareModel get cheapestFare =>
      fares.reduce((a, b) => a.price < b.price ? a : b);

  FareModel? fareFor(TravelClass travelClass) {
    for (final fare in fares) {
      if (fare.travelClass == travelClass) return fare;
    }
    return null;
  }

  /// Predicción de qué tan probable es que este vuelo se llene.
  ///
  /// Usa [SeatOccupancy], la MISMA lógica determinística (basada en
  /// [id]) que [SeatSelector] usa para pintar los asientos ocupados en
  /// el mapa, así el porcentaje que se ve en la tarjeta de resultados
  /// coincide exactamente con la ocupación real del mapa de asientos
  /// de ese vuelo. Es un placeholder transparente del score que
  /// Python calcularía a futuro; se puede reemplazar por el valor real
  /// del backend sin cambiar la UI que lo consume.
  FlightDemandForecast get demandForecast {
    final fillProbability =
        SeatOccupancy.occupancyRatioFor(id).clamp(0.0, 0.97);

    final level = fillProbability >= 0.75
        ? 'Alta'
        : fillProbability >= 0.5
            ? 'Media'
            : 'Baja';

    return FlightDemandForecast(
      fillProbability: fillProbability,
      level: level,
    );
  }

  /// Predicción de tendencia de precio para los próximos días.
  ///
  /// Fórmula simple e intencionalmente transparente: entre más
  /// ocupado esté el vuelo, más probable (y más fuerte) es la subida
  /// de precio estimada. Reutiliza [demandForecast] para no introducir
  /// una fuente de aleatoriedad distinta.
  PriceForecast get priceForecast {
    final fill = demandForecast.fillProbability;
    final isRising = fill >= 0.55;
    // Variación estimada entre 4% y 22%, proporcional a la ocupación.
    final changePercent = (fill * 25).round().clamp(4, 22);
    return PriceForecast(
      isRising: isRising,
      changePercent: isRising ? changePercent : (changePercent / 2).round(),
    );
  }

  /// Deserializa desde JSON.
  ///
  /// Tolera los dos juegos de nombres que conviven:
  ///  - Contrato propio de la app: `id`, `origin`, `destination`,
  ///    `departureTime`, `arrivalTime`, `stops`, `fares`.
  ///  - Backend real (`FlightDTO`): `flightID`, `departureLocation`,
  ///    `arrivalLocation`, `departureDate`, `arrivalDate`, `scales`,
  ///    `availableFares`.
  factory FlightModel.fromJson(Map<String, dynamic> json) {
    final fares = json['fares'] ?? json['availableFares'];
    final origin = json['origin'] ?? json['departureLocation'];
    final destination = json['destination'] ?? json['arrivalLocation'];
    final departure = json['departureTime'] ?? json['departureDate'];
    final arrival = json['arrivalTime'] ?? json['arrivalDate'];

    return FlightModel(
      id: _readString(json['id']) ?? _readString(json['flightID']) ?? '',
      airline: _readString(json['airline']) ?? '',
      flightNumber: _readString(json['flightNumber']) ?? '',
      aircraft: _readString(json['aircraft']) ?? '',
      origin: _airportFrom(origin),
      destination: _airportFrom(destination),
      departureTime: _dateFrom(departure),
      arrivalTime: _dateFrom(arrival),
      stops: (json['stops'] ?? json['scales']) as int? ?? 0,
      fares: (fares as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FareModel.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'airline': airline,
      'flightNumber': flightNumber,
      'aircraft': aircraft,
      'origin': origin.toJson(),
      'destination': destination.toJson(),
      'departureTime': departureTime.toIso8601String(),
      'arrivalTime': arrivalTime.toIso8601String(),
      'stops': stops,
      'fares': fares.map((f) => f.toJson()).toList(),
    };
  }
}

/// Lee un valor del JSON como texto, tolerando que no sea un String.
String? _readString(Object? value) {
  if (value is String) return value;
  if (value == null) return null;
  return value.toString();
}

/// Lee el precio de una tarifa.
///
/// El backend real devuelve un objeto `Money` (Joda Money) con
/// `amountMajor` ya convertido a pesos colombianos; el contrato anterior
/// mandaba un número plano.
double _priceFrom(Object? value) {
  if (value is num) return value.toDouble();
  if (value is Map<String, dynamic>) {
    final major = value['amountMajor'];
    if (major is num) return major.toDouble();
    final amount = value['amount'];
    if (amount is num) return amount.toDouble();
  }
  return 0;
}

/// Lee un aeropuerto del JSON, tolerando que falte o venga con otro
/// nombre de campo.
AirportModel _airportFrom(Object? value) {
  if (value is Map<String, dynamic>) {
    return AirportModel.fromJson(value);
  }
  return const AirportModel(
    code: '',
    city: '',
    country: '',
    airportName: '',
  );
}

/// Lee una fecha del JSON.
///
/// Si viene mal formada se usa el momento actual en vez de reventar:
/// perder la lista COMPLETA de vuelos por un dato raro en uno solo es
/// peor que mostrar ese vuelo con una fecha aproximada.
DateTime _dateFrom(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}
