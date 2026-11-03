import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/features/traveler_profile/repository/traveler_profile_repository.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/passenger_model.dart';
import 'package:royal_airlines/models/payment_model.dart';
import 'package:royal_airlines/models/reservation_model.dart';
import 'package:royal_airlines/models/travel_class.dart';
import 'package:royal_airlines/models/traveler_profile_model.dart';

/// Pruebas del clasificador nearest-centroid de [TravelerProfileRepository]:
/// valida que el historial de reservas (dato 100% local, sin red) se
/// traduzca en el [TravelerArchetype] esperado y en métricas correctas.
void main() {
  const bogota = AirportModel(
    code: 'BOG',
    city: 'Bogotá',
    country: 'Colombia',
    airportName: 'El Dorado',
  );
  const cartagena = AirportModel(
    code: 'CTG',
    city: 'Cartagena',
    country: 'Colombia',
    airportName: 'Rafael Núñez',
  );
  const medellin = AirportModel(
    code: 'MDE',
    city: 'Medellín',
    country: 'Colombia',
    airportName: 'José María Córdova',
  );

  FlightModel buildFlight({
    required String id,
    required AirportModel destination,
    required double cheapestPrice,
  }) {
    return FlightModel(
      id: id,
      airline: 'Royal Airlines',
      flightNumber: 'RA-101',
      aircraft: 'Airbus A320',
      origin: bogota,
      destination: destination,
      departureTime: DateTime(2026, 9, 1, 8, 0),
      arrivalTime: DateTime(2026, 9, 1, 9, 40),
      stops: 0,
      fares: [
        FareModel(
          travelClass: TravelClass.economy,
          tierName: 'Basic',
          price: cheapestPrice,
          benefits: const ['Bolso o mochila'],
        ),
        FareModel(
          travelClass: TravelClass.business,
          tierName: 'Business',
          price: cheapestPrice * 3,
          benefits: const ['Equipaje 30kg', 'Sala VIP'],
        ),
      ],
    );
  }

  ReservationModel buildReservation({
    required FlightModel flight,
    required FareModel fare,
  }) {
    return ReservationModel(
      id: 'RSV_${flight.id}',
      confirmationCode: 'ROYAL${flight.id}',
      flight: flight,
      fare: fare,
      seats: const ['12A'],
      passengers: [
        PassengerModel(
          fullName: 'Test Passenger',
          documentNumber: '12345678',
          birthDate: DateTime(1995, 6, 15),
        ),
      ],
      payment: const PaymentModel(
        cardHolderName: 'Test Passenger',
        maskedCardNumber: '•••• •••• •••• 4242',
        expiry: '12/29',
      ),
      totalPrice: fare.price,
      bookedAt: DateTime(2026, 1, 1),
    );
  }

  final repository = TravelerProfileRepository();

  test('sin reservas devuelve el arquetipo newcomer y métricas en cero', () {
    final profile = repository.classify([]);

    expect(profile.archetype, TravelerArchetype.newcomer);
    expect(profile.totalTrips, 0);
    expect(profile.uniqueDestinations, 0);
  });

  test('reservas siempre en la tarifa más barata clasifica como dealHunter',
      () {
    final flight1 =
        buildFlight(id: '1', destination: cartagena, cheapestPrice: 185000);
    final flight2 =
        buildFlight(id: '2', destination: cartagena, cheapestPrice: 190000);

    final reservations = [
      buildReservation(flight: flight1, fare: flight1.cheapestFare),
      buildReservation(flight: flight2, fare: flight2.cheapestFare),
    ];

    final profile = repository.classify(reservations);

    expect(profile.archetype, TravelerArchetype.dealHunter);
    expect(profile.cheapestFareRatio, 1.0);
    expect(profile.totalTrips, 2);
  });

  test('reservas siempre en tarifa business clasifica como premiumTraveler',
      () {
    final flight1 =
        buildFlight(id: '1', destination: cartagena, cheapestPrice: 185000);
    final flight2 =
        buildFlight(id: '2', destination: medellin, cheapestPrice: 200000);

    final businessFare1 =
        flight1.fareFor(TravelClass.business) ?? flight1.cheapestFare;
    final businessFare2 =
        flight2.fareFor(TravelClass.business) ?? flight2.cheapestFare;

    final reservations = [
      buildReservation(flight: flight1, fare: businessFare1),
      buildReservation(flight: flight2, fare: businessFare2),
    ];

    final profile = repository.classify(reservations);

    expect(profile.archetype, TravelerArchetype.premiumTraveler);
    expect(profile.premiumRatio, 1.0);
  });

  test('destinos distintos se cuentan sin duplicados', () {
    final flight1 =
        buildFlight(id: '1', destination: cartagena, cheapestPrice: 185000);
    final flight2 =
        buildFlight(id: '2', destination: cartagena, cheapestPrice: 185000);
    final flight3 =
        buildFlight(id: '3', destination: medellin, cheapestPrice: 210000);

    final reservations = [
      buildReservation(flight: flight1, fare: flight1.cheapestFare),
      buildReservation(flight: flight2, fare: flight2.cheapestFare),
      buildReservation(flight: flight3, fare: flight3.cheapestFare),
    ];

    final profile = repository.classify(reservations);

    expect(profile.uniqueDestinations, 2);
    expect(profile.totalTrips, 3);
  });
}
