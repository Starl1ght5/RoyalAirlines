import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/features/home/controller/home_controller.dart';
import 'package:royal_airlines/features/home/repository/home_repository.dart';

/// Pruebas de la carga de datos de Home contra el backend real.
///
/// Este backend responde el catálogo como una página de Spring Data:
/// `{"content": [...], "page": {...}}` — NO como `{"data": [...]}`.
/// Y expone un único catálogo (`/locations/`) para tanto
/// aeropuertos como destinos.
///
/// El caso crítico que estas pruebas fijan: **que un endpoint caído no
/// tumbe los demás**. Antes, un `Future.wait` único hacía que un 401 de
/// promociones vaciara también los destinos, y el error se tragaba en
/// un `catch (_)` sin dejar rastro.
void main() {
  // ApiClient consulta SessionStorage (flutter_secure_storage), que
  // necesita el binding de servicios para usar MethodChannel. El canal
  // se simula devolviendo null (sin token), igual que un dispositivo
  // recién instalado.
  TestWidgetsFlutterBinding.ensureInitialized();
  TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => null,
  );

  /// Respuesta real del backend: una página de Spring Data.
  String locationsPage() => jsonEncode({
        'content': [
          {
            'locationID': '6ad58b1754ba06e9d564c123',
            'cityName': 'Madrid',
            'countryName': 'España',
            'iataCode': 'MAD',
            'airportName': 'Aeropuerto Adolfo Suárez Madrid-Barajas',
            'featured': true,
            'rating': 3.0,
          },
          {
            'locationID': '6ad8e75f251433bf3773ce72',
            'cityName': 'Londres',
            'countryName': 'Reino Unido',
            'iataCode': 'LHR',
            'airportName': 'Aeropuerto de Londres-Heathrow',
            'featured': false,
            'rating': 3.0,
          },
        ],
        'page': {
          'size': 10,
          'number': 0,
          'totalElements': 2,
          'totalPages': 1,
        },
      });

  /// Backend simulado que se comporta como el real: `/locations/`
  /// responde 200 con la página, y cualquier otra ruta (aquí
  /// `/promotions` se simula caída) responde 401.
  MockClient backendClient() => MockClient((request) async {
        if (request.url.path.endsWith('/locations/')) {
          return http.Response(
            locationsPage(),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'title': 'No autenticado',
            'status': 401,
            'detail': 'Token requerido',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

  HomeRepository buildRepository() => HomeRepository(
        apiClient: ApiClient(
          baseUrl: 'http://localhost:8080/api/v1',
          client: backendClient(),
        ),
      );

  group('HomeRepository', () {
    test('lee los destinos de la envoltura `content` del backend real',
        () async {
      final repository = buildRepository();

      final destinations = await repository.getPopularDestinations();

      expect(destinations, hasLength(2));
      // Los nombres del backend real (`iataCode`, `cityName`,
      // `countryName`) se mapearon a los del modelo de la app.
      expect(destinations.first.code, 'MAD');
      expect(destinations.first.city, 'Madrid');
      expect(destinations.first.country, 'España');
      expect(destinations.first.airportName,
          'Aeropuerto Adolfo Suárez Madrid-Barajas');
    });

    test('los aeropuertos salen del mismo catálogo', () async {
      final repository = buildRepository();

      final airports = await repository.getAirports();

      expect(airports, hasLength(2));
      expect(airports.map((a) => a.code), containsAll(['MAD', 'LHR']));
    });
  });

  group('Promociones', () {
    /// Backend que sirve `/promotions` con el shape real del contrato:
    /// array suelto con ruta, fecha ancla y una promoción inactiva.
    HomeRepository promotionsRepository() => HomeRepository(
          apiClient: ApiClient(
            baseUrl: 'http://localhost:8080/api/v1',
            client: MockClient((request) async {
              if (request.url.path.endsWith('/promotions')) {
                return http.Response(
                  jsonEncode([
                    {
                      'id': 'promo_BOG_CTG',
                      'title': 'Ofertas a Cartagena',
                      'subtitle': 'Vuelos directos desde Bogotá',
                      'discountLabel': 'Hasta 30% OFF',
                      'origin': 'BOG',
                      'destination': 'CTG',
                      'departureDate': '2026-11-15',
                      'active': true,
                    },
                    {
                      'id': 'promo_BOG_MAD',
                      'title': 'Madrid desde',
                      'subtitle': 'Vuelos desde Bogotá',
                      'discountLabel': 'Desde COP 900K',
                      'origin': 'BOG',
                      'destination': 'MAD',
                      'departureDate': '2026-11-20',
                      'active': false,
                    },
                    {
                      // Backend anterior: sin ruta ni fecha de ancla.
                      'id': 'promo_001',
                      'title': 'Cartagena desde',
                      'subtitle': 'Tarifas especiales',
                      'discountLabel': 'Desde COP 245K',
                      'active': true,
                    },
                  ]),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              return http.Response(
                jsonEncode({'status': 404}),
                404,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        );

    test('las tarjetas traen ruta y fecha para navegar al tocarlas',
        () async {
      final promotions = await promotionsRepository().getPromotions();

      // La inactiva no llega al slider (mismo filtro que siempre).
      expect(promotions, hasLength(2));
      final offer = promotions.first;
      expect(offer.origin, 'BOG');
      expect(offer.destination, 'CTG');
      // yyyy-MM-dd → DateTime (medianoche local), lista para la
      // búsqueda que arma el tap.
      expect(offer.departureDate, DateTime(2026, 11, 15));
    });

    test('un backend sin ruta ni fecha no rompe el parseo', () async {
      final promotions = await promotionsRepository().getPromotions();

      final legacy = promotions.last;
      expect(legacy.title, 'Cartagena desde');
      expect(legacy.origin, isNull);
      expect(legacy.destination, isNull);
      expect(legacy.departureDate, isNull);
    });
  });

  group('HomeController - carga de datos', () {
    test('los destinos cargan aunque promociones y airports fallen',
        () async {
      // Este es el escenario que hay que tolerar: una ruta caída
      // (`/promotions` responde 401) mientras `/locations/` sí
      // responde. Un `Future.wait` único habría dejado TODA la
      // pantalla vacía.
      final controller = HomeController(repository: buildRepository());

      await controller.loadHomeData();

      expect(controller.popularDestinations, hasLength(2));
      expect(controller.popularDestinations.first.city, 'Madrid');
      expect(controller.isLoading, isFalse);
    });

    test('un refresh no pisa el origen y destino que el usuario ya eligió',
        () async {
      final controller = HomeController(repository: buildRepository());

      await controller.loadHomeData();
      final origin = controller.origin;
      final destination = controller.destination;

      controller.swapAirports();
      await controller.loadHomeData();

      expect(controller.origin, destination);
      expect(controller.destination, origin);
    });

    test('si el catálogo falla, la carga termina igual sin romper la app',
        () async {
      final controller = HomeController(
        repository: HomeRepository(
          apiClient: ApiClient(
            baseUrl: 'http://localhost:8080/api/v1',
            client: MockClient(
              (_) async => http.Response('{}', 500,
                  headers: {'content-type': 'application/json'}),
            ),
          ),
        ),
      );

      await controller.loadHomeData();

      expect(controller.isLoading, isFalse);
      expect(controller.popularDestinations, isEmpty);
    });
  });
}
