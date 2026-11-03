// tools/verify_real_integration.dart
//
// Verificación de extremo a extremo contra el backend real (Spring Boot)
// usando los MISMOS modelos con los que Flutter parsea las respuestas.
// Si este script pasa, los parsers de la app aceptan lo que devuelve el
// servidor.
//
// No depende de Flutter ni de plugins (solo dart:io y modelos puros),
// por eso se puede correr en consola:
//
//     dart run tools/verify_real_integration.dart
//
// Opciones:
//     --base-url=http://localhost:8080/api/v1
//     --email=demo@royalairlines.com
//     --password=Demo2026!
//
// Código de salida: 0 = todo OK, 1 = hay fallos, 2 = servidor caído.
//
// NOTA sobre el contrato: el backend real sirve sus rutas bajo
// `/api/v1` y usa Problem Details RFC 7807 para los errores
// (`{title, status, detail}`), no el envoltorio `{success, message}` del
// contrato anterior. Los endpoints que el backend todavía no expone
// (promociones, perfil del usuario, reservas) se reportan como
// "no implementado" en vez de contarse como fallo.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:royal_airlines/core/network/api_contracts.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/flight_model.dart';

class ApiResponse {
  ApiResponse(this.status, this.body, this.raw);

  final int status;
  final Map<String, dynamic> body;
  final String raw;
}

int _passed = 0;
int _failed = 0;

void section(String title) {
  stdout.writeln('\n=== $title ===');
}

void check(String name, bool condition, [String detail = '']) {
  if (condition) {
    _passed++;
    stdout.writeln('  [OK]   $name');
  } else {
    _failed++;
    stdout.writeln('  [FALLO] $name${detail.isEmpty ? '' : ' -> $detail'}');
  }
}

/// Endpoint que el backend todavía no expone. No es un fallo: se
/// informa para que quede claro qué falta del contrato.
void notImplemented(String name, String detail) {
  stdout.writeln('  [N/D]   $name -> $detail');
}

Future<ApiResponse> request(
  HttpClient client,
  String baseUrl,
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? token,
  Map<String, String>? headers,
}) async {
  final uri = Uri.parse('$baseUrl$path');
  final req = await client.openUrl(method, uri);
  req.headers
      .set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
  req.headers.set(HttpHeaders.acceptHeader, 'application/json');
  headers?.forEach(req.headers.set);
  if (token != null && token.isNotEmpty) {
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  if (body != null) req.write(jsonEncode(body));

  final res = await req.close();
  final raw = await res.transform(utf8.decoder).join();

  Map<String, dynamic> parsed;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      parsed = decoded;
    } else if (decoded is List) {
      parsed = <String, dynamic>{'__list__': decoded};
    } else {
      parsed = <String, dynamic>{'__no_map__': decoded};
    }
  } catch (_) {
    parsed = <String, dynamic>{'__invalid_json__': raw};
  }
  return ApiResponse(res.statusCode, parsed, raw);
}

/// Decodifica el payload de un JWT (sin verificar la firma) para leer
/// los claims que emite el backend.
Map<String, dynamic>? decodeJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map<String, dynamic> ? payload : null;
  } catch (_) {
    return null;
  }
}

Future<void> main(List<String> args) async {
  var baseUrl = 'http://localhost:8080/api/v1';
  var email = 'demo@royalairlines.com';
  var password = 'Demo2026!';

  for (final arg in args) {
    if (arg.startsWith('--base-url='))
      baseUrl = arg.substring('--base-url='.length);
    if (arg.startsWith('--email=')) email = arg.substring('--email='.length);
    if (arg.startsWith('--password='))
      password = arg.substring('--password='.length);
  }
  baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  stdout.writeln('Verificando backend real en $baseUrl');

  try {
    await client.getUrl(Uri.parse('$baseUrl${ApiEndpoints.locations}'));
  } on SocketException {
    stderr.writeln(
      '\nNo se pudo conectar al servidor. Arráncalo con:\n'
      '    mvn spring-boot:run   (en el proyecto Backend)',
    );
    exit(2);
  } on Exception {
    stderr.writeln(
      '\nNo se pudo conectar al servidor. Arráncalo con:\n'
      '    mvn spring-boot:run   (en el proyecto Backend)',
    );
    exit(2);
  }

  /* ---------------------------------------------------------------- */
  /* 1. Catálogo (sin token)                                           */
  /* ---------------------------------------------------------------- */

  section('1. Catálogo: destinos (`GET /locations/`)');

  final locations = await request(
      client, baseUrl, 'GET', ApiEndpoints.locations);
  check('GET /locations/ responde 200', locations.status == 200,
      'status=${locations.status} body=${locations.raw}');

  final content = locations.body['content'];
  check('La respuesta es una página de Spring Data {content, page}',
      content is List && locations.body['page'] is Map<String, dynamic>,
      locations.raw);

  final locationList =
      (content is List ? content : const []).whereType<Map<String, dynamic>>().toList();
  check('GET /locations/ trae al menos 1 destino', locationList.isNotEmpty,
      'total=${locationList.length}');

  if (locationList.isNotEmpty) {
    final first = locationList.first;
    check(
      'Cada destino trae locationID, cityName, countryName, iataCode y airportName',
      first['locationID'] is String &&
          first['cityName'] is String &&
          first['countryName'] is String &&
          first['iataCode'] is String &&
          first['airportName'] is String,
      first.toString(),
    );
  }

  var locationsParsed = 0;
  for (final item in locationList) {
    try {
      final airport = AirportModel.fromJson(item);
      if (airport.code.isNotEmpty && airport.city.isNotEmpty) {
        locationsParsed++;
      }
    } catch (_) {}
  }
  check(
    'AirportModel.fromJson acepta TODOS los destinos (iataCode/cityName/countryName)',
    locationsParsed == locationList.length,
    '$locationsParsed/${locationList.length}',
  );

  final noSlash = await request(client, baseUrl, 'GET', '/locations');
  check(
    'GET /locations SIN barra final responde 404 (la barra es obligatoria)',
    noSlash.status == 404,
    'status=${noSlash.status}',
  );

  final promotions =
      await request(client, baseUrl, 'GET', ApiEndpoints.promotions);
  if (promotions.status == 200) {
    check('GET /promotions responde 200', true);
  } else {
    notImplemented('GET /promotions', 'status=${promotions.status}');
  }

  /* ---------------------------------------------------------------- */
  /* 2. Autenticación                                                  */
  /* ---------------------------------------------------------------- */

  section('2. Autenticación (`POST /users/*`)');

  final uniqueEmail =
      'verify_${DateTime.now().millisecondsSinceEpoch}@royalairlines.com';
  final register = await request(
      client, baseUrl, 'POST', ApiEndpoints.register, body: {
    'email': uniqueEmail,
    'password': 'Verificacion2026!',
  });
  check('POST /users/register responde 201', register.status == 201,
      'status=${register.status} body=${register.raw}');
  check('POST /users/register responde con el cuerpo vacío',
      register.raw.isEmpty, register.raw);

  final duplicate = await request(
      client, baseUrl, 'POST', ApiEndpoints.register, body: {
    'email': uniqueEmail,
    'password': 'Verificacion2026!',
  });
  check('POST /users/register rechaza correo duplicado (409)',
      duplicate.status == 409, 'status=${duplicate.status}');

  final login = await request(client, baseUrl, 'POST', ApiEndpoints.login,
      body: {'email': email, 'password': password});
  check('POST /users/login responde 200', login.status == 200,
      'status=${login.status} body=${login.raw}');

  final token = login.body['token'];
  check('POST /users/login devuelve `token` en la raíz',
      token is String && token.isNotEmpty, login.raw);

  var authToken = '';
  if (token is String && token.isNotEmpty) {
    authToken = token;
    final claims = decodeJwt(token);
    check('El JWT trae los claims sub (correo), id y exp',
        claims != null &&
            claims['sub'] is String &&
            claims['id'] is String &&
            claims['exp'] is num,
        claims.toString());
  }

  final wrongLogin = await request(client, baseUrl, 'POST', ApiEndpoints.login,
      body: {'email': email, 'password': 'clave-mal-incorrecta'});
  check(
    'POST /users/login con contraseña errónea responde 401 con Problem Details',
    wrongLogin.status == 401 &&
        (wrongLogin.body['detail'] is String ||
            wrongLogin.body['message'] is String),
    'status=${wrongLogin.status} body=${wrongLogin.raw}',
  );

  final me = await request(client, baseUrl, 'GET', ApiEndpoints.profile,
      token: authToken);
  check('GET /users/me responde 200 con el perfil', me.status == 200,
      'status=${me.status} body=${me.raw}');

  /* ---------------------------------------------------------------- */
  /* 3. Vuelos                                                         */
  /* ---------------------------------------------------------------- */

  section('3. Búsqueda de vuelos (`GET /flights/search`)');

  final date = DateTime.now().add(const Duration(days: 10));
  final departureDate =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final flights = await request(
    client,
    baseUrl,
    'GET',
    '${ApiEndpoints.flightsSearch}?origin=MAD&destination=JFK'
        '&departureDate=$departureDate&passengers=1',
    token: authToken.isEmpty ? null : authToken,
  );
  check('GET /flights/search responde 200', flights.status == 200,
      'status=${flights.status} body=${flights.raw}');

  final flightList = flights.body['__list__'];
  if (flightList is List) {
    check('GET /flights/search responde un ARRAY (no un objeto envuelto)',
        true, 'total=${flightList.length}');
    var flightsParsed = 0;
    for (final item in flightList.whereType<Map<String, dynamic>>()) {
      try {
        FlightModel.fromJson(item);
        flightsParsed++;
      } catch (_) {}
    }
    check('FlightModel.fromJson acepta TODOS los vuelos',
        flightsParsed == flightList.length, '$flightsParsed/${flightList.length}');
  } else {
    check('GET /flights/search responde un ARRAY (no un objeto envuelto)',
        false, flights.raw);
  }

  /* ---------------------------------------------------------------- */
  /* 4. Rutas protegidas                                               */
  /* ---------------------------------------------------------------- */

  section('4. Rutas protegidas exigen token');

  final noToken = await request(client, baseUrl, 'GET', '/booking/create');
  check('Una ruta protegida sin token responde 401', noToken.status == 401,
      'status=${noToken.status} body=${noToken.raw}');

  /* ---------------------------------------------------------------- */
  /* 5. CORS (Flutter Web)                                             */
  /* ---------------------------------------------------------------- */

  section('5. CORS (lo necesita Flutter Web)');

  final origin = 'http://localhost:52345';
  final preflight = await request(
    client,
    baseUrl,
    'OPTIONS',
    ApiEndpoints.locations,
    headers: {
      'Origin': origin,
      'Access-Control-Request-Method': 'GET',
      'Access-Control-Request-Headers': 'authorization,content-type',
    },
  );
  check('El preflight OPTIONS responde 200', preflight.status == 200,
      'status=${preflight.status}');

  final realGet = await request(client, baseUrl, 'GET', ApiEndpoints.locations,
      headers: {'Origin': origin});
  check('GET con Origin de Flutter Web responde 200', realGet.status == 200,
      'status=${realGet.status}');

  /* ---------------------------------------------------------------- */

  client.close(force: true);

  stdout.writeln('\n------------------------------------------------------');
  stdout.writeln('Resultado: $_passed OK, $_failed FALLO(S)');
  stdout.writeln('------------------------------------------------------');

  if (_failed > 0) exit(1);
  exit(0);
}
