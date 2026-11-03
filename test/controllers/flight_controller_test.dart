import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/features/flights/controller/flight_controller.dart';
import 'package:royal_airlines/features/flights/repository/flight_repository.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/travel_class.dart';

/// Repositorio de prueba que permite simular tanto una búsqueda
/// exitosa (con una lista de vuelos fija) como un fallo de red
/// (lanzando [ApiException]), sin depender de HTTP real ni del mock
/// interno de [FlightRepository].
class _FakeFlightRepository extends FlightRepository {
  _FakeFlightRepository({this.flightsToReturn, this.errorToThrow});

  final List<FlightModel>? flightsToReturn;
  final Object? errorToThrow;

  @override
  Future<List<FlightModel>> searchFlights({
    required AirportModel origin,
    required AirportModel destination,
    required DateTime date,
    DateTime? returnDate,
    int passengers = 1,
  }) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return flightsToReturn ?? [];
  }
}

void main() {
  const origin = AirportModel(
    code: 'BOG',
    city: 'Bogotá',
    country: 'Colombia',
    airportName: 'El Dorado',
  );
  const destination = AirportModel(
    code: 'CTG',
    city: 'Cartagena',
    country: 'Colombia',
    airportName: 'Rafael Núñez',
  );

  FlightSearchParams buildParams() {
    return FlightSearchParams(
      tripType: TripType.oneWay,
      origin: origin,
      destination: destination,
      departureDate: DateTime(2026, 9, 1),
      passengers: const PassengerCount(adults: 1),
    );
  }

  FlightModel buildFlight(String id, double price, int durationMinutes) {
    return FlightModel(
      id: id,
      airline: 'Royal Airlines',
      flightNumber: 'RA-101',
      aircraft: 'Airbus A320',
      origin: origin,
      destination: destination,
      departureTime: DateTime(2026, 9, 1, 8, 0),
      arrivalTime:
          DateTime(2026, 9, 1, 8, 0).add(Duration(minutes: durationMinutes)),
      stops: 0,
      fares: [
        FareModel(
          travelClass: TravelClass.economy,
          tierName: 'Basic',
          price: price,
          benefits: const ['Bolso o mochila'],
        ),
      ],
    );
  }

  group('FlightController - carga exitosa', () {
    test('loadFlights llena visibleFlights y apaga isLoading', () async {
      final repository = _FakeFlightRepository(
        flightsToReturn: [
          buildFlight('f1', 200000, 90),
          buildFlight('f2', 150000, 120),
        ],
      );
      final controller =
          FlightController(searchParams: buildParams(), repository: repository);

      expect(controller.isLoading, isFalse);
      final future = controller.loadFlights();
      expect(controller.isLoading, isTrue);
      await future;

      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.visibleFlights.length, 2);
    });

    test('visibleFlights se ordena por menor precio por defecto', () async {
      final repository = _FakeFlightRepository(
        flightsToReturn: [
          buildFlight('caro', 300000, 90),
          buildFlight('barato', 100000, 90),
        ],
      );
      final controller =
          FlightController(searchParams: buildParams(), repository: repository);
      await controller.loadFlights();

      expect(controller.visibleFlights.first.id, 'barato');
    });

    test('setStopsFilter deja solo vuelos directos', () async {
      final repository = _FakeFlightRepository(
        flightsToReturn: [
          FlightModel(
            id: 'directo',
            airline: 'Royal Airlines',
            flightNumber: 'RA-1',
            aircraft: 'A320',
            origin: origin,
            destination: destination,
            departureTime: DateTime(2026, 9, 1, 8, 0),
            arrivalTime: DateTime(2026, 9, 1, 9, 0),
            stops: 0,
            fares: [
              const FareModel(
                travelClass: TravelClass.economy,
                tierName: 'Basic',
                price: 100000,
                benefits: [],
              )
            ],
          ),
          FlightModel(
            id: 'con_escala',
            airline: 'Royal Airlines',
            flightNumber: 'RA-2',
            aircraft: 'A320',
            origin: origin,
            destination: destination,
            departureTime: DateTime(2026, 9, 1, 8, 0),
            arrivalTime: DateTime(2026, 9, 1, 10, 0),
            stops: 1,
            fares: [
              const FareModel(
                travelClass: TravelClass.economy,
                tierName: 'Basic',
                price: 100000,
                benefits: [],
              )
            ],
          ),
        ],
      );
      final controller =
          FlightController(searchParams: buildParams(), repository: repository);
      await controller.loadFlights();

      expect(controller.visibleFlights.length, 2);
      controller.setStopsFilter(StopsFilter.direct);
      expect(controller.visibleFlights.length, 1);
      expect(controller.visibleFlights.first.id, 'directo');
    });

    test('bestOptionFlight es null si hay menos de 2 vuelos', () async {
      final repository = _FakeFlightRepository(
          flightsToReturn: [buildFlight('unico', 100000, 90)]);
      final controller =
          FlightController(searchParams: buildParams(), repository: repository);
      await controller.loadFlights();

      expect(controller.bestOptionFlight, isNull);
    });
  });

  group('FlightController - manejo de errores de red', () {
    test('un ApiException deja errorMessage con el mensaje real', () async {
      final repository = _FakeFlightRepository(
        errorToThrow: const ApiException('No hay conexión a internet.'),
      );
      final controller =
          FlightController(searchParams: buildParams(), repository: repository);

      await controller.loadFlights();

      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, 'No hay conexión a internet.');
      expect(controller.visibleFlights, isEmpty);
    });

    test('un error inesperado (no ApiException) no rompe la app', () async {
      final repository = _FakeFlightRepository(errorToThrow: Exception('boom'));
      final controller =
          FlightController(searchParams: buildParams(), repository: repository);

      // No debe lanzar: loadFlights atrapa cualquier excepción.
      await controller.loadFlights();

      expect(controller.errorMessage, isNotNull);
      expect(controller.visibleFlights, isEmpty);
    });

    test('un reintento exitoso limpia el error anterior', () async {
      var shouldFail = true;
      final controller = FlightController(
        searchParams: buildParams(),
        repository: _RetryableFakeRepository(() => shouldFail),
      );

      await controller.loadFlights();
      expect(controller.errorMessage, isNotNull);

      shouldFail = false;
      await controller.loadFlights();
      expect(controller.errorMessage, isNull);
      expect(controller.visibleFlights, isNotEmpty);
    });
  });
}

/// Repositorio que falla o no según una condición externa mutable,
/// para simular el escenario "reintentar después de un error".
class _RetryableFakeRepository extends FlightRepository {
  _RetryableFakeRepository(this.shouldFail);

  final bool Function() shouldFail;

  @override
  Future<List<FlightModel>> searchFlights({
    required AirportModel origin,
    required AirportModel destination,
    required DateTime date,
    DateTime? returnDate,
    int passengers = 1,
  }) async {
    if (shouldFail()) {
      throw const ApiException('Falla simulada');
    }
    return [
      FlightModel(
        id: 'ok',
        airline: 'Royal Airlines',
        flightNumber: 'RA-1',
        aircraft: 'A320',
        origin: origin,
        destination: destination,
        departureTime: date,
        arrivalTime: date.add(const Duration(hours: 1)),
        stops: 0,
        fares: const [
          FareModel(
            travelClass: TravelClass.economy,
            tierName: 'Basic',
            price: 100000,
            benefits: [],
          )
        ],
      ),
    ];
  }
}
