import 'package:flutter/material.dart';
import 'package:royal_airlines/core/navigation/app_keys.dart';
import 'package:royal_airlines/features/flights/controller/flight_controller.dart';
import 'package:royal_airlines/features/flights/screens/flights_screen.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart'
    show PassengerCount, TripType;
import 'package:royal_airlines/features/home/repository/home_repository.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/services/push_message_handler.dart';

/// Abre los resultados de vuelos de la ruta de una oferta (solo ida, 1 adulto),
/// como hace el slider de promociones al tocar una tarjeta.
///
/// Espera a que termine un frame para que, si la app se acaba de abrir o de
/// iniciar sesión, `MainNavigation` ya esté montado y los resultados queden
/// ENCIMA de Inicio (al volver atrás el usuario cae en la app, no en el vacío).
Future<void> openOfferSearch(OfferPushPayload payload) async {
  await WidgetsBinding.instance.endOfFrame;

  // El catálogo trae ciudad y nombre del aeropuerto; si no responde, se busca
  // igual con los códigos IATA (la búsqueda del backend solo necesita eso).
  var airports = const <AirportModel>[];
  try {
    airports = await HomeRepository().getAirports();
  } catch (_) {}

  final params = FlightSearchParams(
    tripType: TripType.oneWay,
    origin: _airport(airports, payload.origin),
    destination: _airport(airports, payload.destination),
    departureDate: _searchDate(payload.departureDate),
    passengers: const PassengerCount(),
  );

  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.push(
    MaterialPageRoute<void>(builder: (_) => FlightsScreen(searchParams: params)),
  );
}

/// Aviso dentro de la app para una oferta que llega con la app abierta.
void showOfferBanner(
  PushMessage message,
  OfferPushPayload payload,
  VoidCallback onOpen,
) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.title != null)
              Text(message.title!, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (message.body != null) Text(message.body!),
          ],
        ),
        action: SnackBarAction(label: 'VER', onPressed: onOpen),
      ),
    );
}

AirportModel _airport(List<AirportModel> airports, String code) {
  for (final airport in airports) {
    if (airport.code == code) return airport;
  }
  return AirportModel(code: code, city: code, country: '', airportName: code);
}

/// La fecha de la oferta; si ya pasó o no vino, mañana.
DateTime _searchDate(DateTime? date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (date == null || date.isBefore(today)) {
    return today.add(const Duration(days: 1));
  }
  return date;
}
