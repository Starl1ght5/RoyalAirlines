import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/travel_class.dart';

/// Pruebas de la lógica real de [FlightModel]: duración, tarifa más
/// barata, y las fórmulas predictivas (demandForecast/priceForecast)
/// que son el corazón del módulo de Minería de datos 2 de esta app.
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

  FlightModel buildFlight({
    required String id,
    int stops = 0,
    DateTime? departure,
    DateTime? arrival,
  }) {
    return FlightModel(
      id: id,
      airline: 'Royal Airlines',
      flightNumber: 'RA-101',
      aircraft: 'Airbus A320',
      origin: origin,
      destination: destination,
      departureTime: departure ?? DateTime(2026, 9, 1, 8, 0),
      arrivalTime: arrival ?? DateTime(2026, 9, 1, 9, 40),
      stops: stops,
      fares: const [
        FareModel(
          travelClass: TravelClass.economy,
          tierName: 'Basic',
          price: 185000,
          benefits: ['Bolso o mochila'],
        ),
        FareModel(
          travelClass: TravelClass.economy,
          tierName: 'Light',
          price: 229000,
          benefits: ['Bolso o mochila', 'Maleta 12kg'],
        ),
      ],
    );
  }

  group('FlightModel - datos básicos', () {
    test('duration calcula la diferencia entre llegada y salida', () {
      final flight = buildFlight(
        id: 'f1',
        departure: DateTime(2026, 9, 1, 8, 0),
        arrival: DateTime(2026, 9, 1, 9, 40),
      );
      expect(flight.duration, const Duration(hours: 1, minutes: 40));
    });

    test('isDirect es true solo cuando stops == 0', () {
      expect(buildFlight(id: 'f1', stops: 0).isDirect, isTrue);
      expect(buildFlight(id: 'f2', stops: 1).isDirect, isFalse);
    });

    test('stopsLabel usa singular/plural correctamente', () {
      expect(buildFlight(id: 'f1', stops: 0).stopsLabel, 'Directo');
      expect(buildFlight(id: 'f2', stops: 1).stopsLabel, '1 parada');
      expect(buildFlight(id: 'f3', stops: 2).stopsLabel, '2 paradas');
    });

    test('cheapestFare devuelve la tarifa de menor precio', () {
      final flight = buildFlight(id: 'f1');
      expect(flight.cheapestFare.tierName, 'Basic');
      expect(flight.cheapestFare.price, 185000);
    });

    test('fareFor devuelve null si no existe esa clase de viaje', () {
      final flight = buildFlight(id: 'f1');
      expect(flight.fareFor(TravelClass.economy), isNotNull);
      expect(flight.fareFor(TravelClass.business), isNull);
    });
  });

  group('FareModel', () {
    test('fromJson mapea tierRank y equipaje incluido de FaresDTO', () {
      const fare = FareModel(
        travelClass: TravelClass.economy,
        tierName: 'Basic',
        price: 100000,
        tierRank: 1,
        checkedBagKg: 23,
        carryOnKg: 10,
        benefits: [],
      );
      expect(fare.tierRank, 1);
      expect(fare.checkedBagKg, 23);
      expect(fare.carryOnKg, 10);

      final parsed = FareModel.fromJson(const {
        'travelClass': 'economy',
        'tierName': 'Basic',
        'feeID': 'fee-1',
        'price': 100000,
        'tierRank': 2,
        'checkedBagKg': 15,
        'carryOnKg': 10,
        'benefits': [],
      });
      expect(parsed.tierRank, 2);
      expect(parsed.checkedBagKg, 15);
      expect(parsed.carryOnKg, 10);
    });

    test('fromJson tolera FaresDTO sin los campos de equipaje', () {
      final parsed = FareModel.fromJson(const {
        'travelClass': 'economy',
        'tierName': 'Basic',
        'price': 100000,
        'benefits': [],
      });
      expect(parsed.tierRank, 0);
      expect(parsed.checkedBagKg, 0);
      expect(parsed.carryOnKg, 0);
    });
  });

  group('FlightModel - predictivo (demandForecast)', () {
    test('fillProbability siempre queda entre 0.20 y 0.97', () {
      for (var i = 0; i < 50; i++) {
        final flight = buildFlight(id: 'flight_test_$i');
        final probability = flight.demandForecast.fillProbability;
        expect(probability, greaterThanOrEqualTo(0.20));
        expect(probability, lessThanOrEqualTo(0.97));
      }
    });

    test('el mismo id siempre da el mismo resultado (determinístico)', () {
      final flightA = buildFlight(id: 'flight_bog_ctg_3');
      final flightB = buildFlight(id: 'flight_bog_ctg_3');
      expect(
        flightA.demandForecast.fillProbability,
        flightB.demandForecast.fillProbability,
      );
    });

    test('vuelos con id distinto normalmente dan ocupación distinta', () {
      final probabilities = List.generate(
        10,
        (i) =>
            buildFlight(id: 'flight_variado_$i').demandForecast.fillProbability,
      );
      // No deben ser TODAS iguales (si lo fueran, la fórmula estaría
      // rota y se repetiría el bug original que reportó el usuario).
      expect(probabilities.toSet().length, greaterThan(1));
    });

    test('level coincide con el umbral de fillProbability', () {
      final flight = buildFlight(id: 'flight_bog_ctg_7');
      final forecast = flight.demandForecast;
      if (forecast.fillProbability >= 0.75) {
        expect(forecast.level, 'Alta');
        expect(forecast.isUrgent, isTrue);
      } else if (forecast.fillProbability >= 0.5) {
        expect(forecast.level, 'Media');
        expect(forecast.isUrgent, isFalse);
      } else {
        expect(forecast.level, 'Baja');
        expect(forecast.isUrgent, isFalse);
      }
    });
  });

  group('FlightModel - predictivo (priceForecast)', () {
    test('isRising es true solo si la ocupación es >= 0.55', () {
      final flight = buildFlight(id: 'flight_bog_ctg_9');
      final rising = flight.demandForecast.fillProbability >= 0.55;
      expect(flight.priceForecast.isRising, rising);
    });

    test('changePercent siempre es un porcentaje razonable (entre 2 y 22)', () {
      for (var i = 0; i < 30; i++) {
        final flight = buildFlight(id: 'flight_precio_$i');
        final percent = flight.priceForecast.changePercent;
        expect(percent, greaterThanOrEqualTo(2));
        expect(percent, lessThanOrEqualTo(22));
      }
    });
  });
}
