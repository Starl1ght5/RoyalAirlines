/// AirportModel
/// ------------
/// Representa un aeropuerto/ciudad. Vive en `models/` (no dentro de
/// `features/home/`) porque no es exclusivo de Home: el selector de
/// origen/destino se reutiliza en Flights (filtros) y Booking
/// (resumen del pasaje). Mantenerlo aquí evita que cada feature
/// defina su propia versión (DRY).
class AirportModel {
  final String code; // Código IATA, ej. "BOG"
  final String city;
  final String country;
  final String airportName;

  /// `Location.locationID` del backend (id de MongoDB), si vino en la
  /// respuesta de `GET /locations/`. Los aeropuertos construidos a
  /// mano (tests, datos locales) lo dejan en `null`.
  ///
  /// Es el id que exigen los eventos `destination_view` y los
  /// favoritos `DESTINATION`: el IATA identifica la ruta, no la fila
  /// del catálogo.
  final String? locationId;

  const AirportModel({
    required this.code,
    required this.city,
    required this.country,
    required this.airportName,
    this.locationId,
  });

  /// Texto corto usado en los campos de búsqueda: "Bogotá (BOG)".
  String get shortLabel => '$city ($code)';

  /// Id a mandar en la telemetría: el `locationID` real si existe y,
  /// si no, el código IATA (mejor una señal genérica que ninguna).
  String get eventDestinationId => locationId ?? code;

  /// Deserializa desde JSON (respuesta de API).
  ///
  /// Tolera los dos juegos de nombres de campo que conviven:
  ///  - Contrato propio de la app: `code`, `city`, `country`.
  ///  - Backend real (`LocationDTO`): `iataCode`, `cityName`,
  ///    `countryName`.
  ///
  /// Se toma el que esté presente en cada campo. Si no hay ninguno, se
  /// usa cadena vacía en vez de reventar: un destino con un dato
  /// faltante no debe tumbar la pantalla completa de Home.
  factory AirportModel.fromJson(Map<String, dynamic> json) {
    return AirportModel(
      code: _readString(json['code']) ?? _readString(json['iataCode']) ?? '',
      city: _readString(json['city']) ?? _readString(json['cityName']) ?? '',
      country: _readString(json['country']) ??
          _readString(json['countryName']) ??
          '',
      airportName: _readString(json['airportName']) ?? '',
      locationId:
          _readString(json['locationID']) ?? _readString(json['locationId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'city': city,
      'country': country,
      'airportName': airportName,
      if (locationId != null) 'locationID': locationId,
    };
  }
}

/// Lee un valor del JSON como texto, tolerando que no sea un String.
String? _readString(Object? value) {
  if (value is String) return value;
  if (value == null) return null;
  return value.toString();
}
