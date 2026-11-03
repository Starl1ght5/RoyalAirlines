import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:royal_airlines/core/config/app_config.dart';
import 'package:royal_airlines/services/session_storage.dart';

/// ApiClient
/// ---------
/// Cliente base para todas las llamadas al backend real (Spring Boot).
/// Mantiene un único punto de entrada para endpoints, parsing y manejo
/// de errores, de modo que la UI y los servicios no tengan lógica de
/// red mezclada.
///
/// Toda petición (GET/POST/PUT) pasa por [_send], que aplica un timeout
/// y traduce errores de bajo nivel (sin internet, DNS, conexión
/// rechazada, timeout) a un [ApiException] con un mensaje que la UI
/// puede mostrar directamente, en vez de dejar que la excepción cruda
/// (`SocketException`, `TimeoutException`, etc.) llegue sin envolver
/// hasta la pantalla.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : _baseUrl =
            (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
        _providedClient = client;

  final String _baseUrl;

  /// Cliente HTTP inyectable (los tests usan un cliente simulado). Se
  /// crea perezosamente en la primera petición para no tocar la red al
  /// solo construir el objeto.
  final http.Client? _providedClient;

  /// Cliente compartido por TODAS las instancias de ApiClient: cada
  /// servicio crea su propio ApiClient (algunos por interacción de la
  /// UI), y un `http.Client` nuevo por llamada dejaría sockets sin
  /// cerrar. Uno solo reutiliza el pool de conexiones de principio a
  /// fin de la sesión. Los tests inyectan su propio cliente y no lo
  /// usan.
  static final http.Client _sharedClient = http.Client();

  late final http.Client _http = _providedClient ?? _sharedClient;

  static const Duration _timeout = Duration(seconds: 12);

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  Future<Map<String, String>> _defaultHeaders({
    Map<String, String>? headers,
  }) async {
    final token = await SessionStorage().loadToken();
    return <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?headers,
    };
  }

  /// Ejecuta [request] con timeout y traduce cualquier error de red de
  /// bajo nivel a [ApiException], para que quien llame (controllers)
  /// solo tenga que capturar un único tipo de excepción conocido.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    } on SocketException {
      throw const ApiException(
        'No hay conexión a internet. Verifica tu red e intenta de nuevo.',
      );
    } on HttpException {
      throw const ApiException(
        'No se pudo conectar con el servidor. Intenta más tarde.',
      );
    } on http.ClientException {
      // En Flutter Web es la ÚNICA forma de error de red que se ve:
      // el navegador bloquea la respuesta cuando el backend no envía
      // los cabeceros CORS, y el paquete `http` lo reporta como
      // ClientException.
      throw const ApiException(
        'No se pudo conectar con el servidor. Intenta más tarde.',
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Ocurrió un error inesperado: $error');
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await _send(() async => _http.get(
          _uri(path, queryParameters),
          headers: await _defaultHeaders(headers: headers),
        ));
    return _decodeResponse(response, path: path, method: 'GET');
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final response = await _send(() async => _http.post(
          _uri(path),
          headers: await _defaultHeaders(headers: headers),
          body: jsonEncode(body),
        ));
    return _decodeResponse(response, path: path, method: 'POST');
  }

  Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final response = await _send(() async => _http.put(
          _uri(path),
          headers: await _defaultHeaders(headers: headers),
          body: jsonEncode(body),
        ));
    return _decodeResponse(response, path: path, method: 'PUT');
  }

  /// PATCH con cuerpo opcional y soporte de query params, que el
  /// backend de reservas exige (`/booking/confirm?id=...` lleva el id
  /// como query param, no en el cuerpo). Respuestas vacías (el backend
  /// responde sin cuerpo en confirm/cancel/rate) quedan como éxito.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic> body = const <String, dynamic>{},
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await _send(() async => _http.patch(
          _uri(path, queryParameters),
          headers: await _defaultHeaders(headers: headers),
          body: jsonEncode(body),
        ));
    return _decodeResponse(response, path: path, method: 'PATCH');
  }

  /// DELETE sin cuerpo; un 204 vacío ya lo trata [_decodeResponse]
  /// como éxito. Lo usa, p. ej., quitar un favorito
  /// (`DELETE /favorites/{targetType}/{targetId}`).
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await _send(() async => _http.delete(
          _uri(path),
          headers: await _defaultHeaders(headers: headers),
        ));
    return _decodeResponse(response, path: path, method: 'DELETE');
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    required String path,
    required String method,
  }) {
    if (response.body.isEmpty) {
      return {'success': true, 'method': method, 'path': path, 'data': null};
    }

    late final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      // El backend responde TEXTO PLANO en algunas rutas (p. ej.
      // `POST /booking/create` devuelve SOLO el id de la reserva, sin
      // envolver en JSON). Con status 2xx se acepta ese texto como
      // dato crudo; con error se conserva el statusCode para que quien
      // dependa de 401 (p. ej. tryRestoreSession limpiando la sesión)
      // siga pudiendo decidir.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'method': method,
          'path': path,
          'data': response.body.trim(),
        };
      }
      throw ApiException(
        'La respuesta del backend no tiene formato JSON válido',
        statusCode: response.statusCode,
      );
    }

    // Algunos endpoints (p. ej. la búsqueda de vuelos) responden con un
    // ARRAY suelto en vez de un objeto. Se envuelve en `data` para no
    // romper el contrato de get/post/put, que siempre devuelve un mapa.
    if (decoded is List) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Error inesperado del servidor',
          statusCode: response.statusCode,
        );
      }
      return {'success': true, 'method': method, 'path': path, 'data': decoded};
    }

    // Un STRING suelto (p. ej. el id que devuelve `POST /booking/create`
    // cuando Spring lo serializa con Jackson: `"65f3..."`) también se
    // envuelve en `data` por la misma razón.
    if (decoded is String) {
      return {'success': true, 'method': method, 'path': path, 'data': decoded};
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'La respuesta del backend no tiene formato JSON válido',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // El mensaje del backend se acepta SOLO si es string: si un día
      // Spring Boot responde con un objeto/number en `message`, esto no
      // debe explotar con un TypeError dentro del cliente.
      throw ApiException(
        _errorMessageFrom(decoded),
        statusCode: response.statusCode,
      );
    }

    // Aunque el HTTP sea 2xx, el backend puede marcar la operación como
    // fallida con `success: false` (p. ej. 200 en login con credenciales
    // inválidas). Ese caso también debe tratarse como error.
    final success = decoded['success'];
    if (success is bool && !success) {
      throw ApiException(
        _errorMessageFrom(decoded),
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  /// Saca el mensaje de error del cuerpo de la respuesta.
  ///
  /// Conviven dos formatos en el backend:
  ///  - `{message: "..."}`: envoltura propia del servicio.
  ///  - Problem Details RFC 7807: `{title: "...", detail: "..."}`, que
  ///    es lo que devuelve Spring Boot por defecto (p. ej.
  ///    "Credenciales invalidas" al fallar un login).
  ///
  /// Se busca en ese orden para mostrar siempre el mensaje más
  /// específico que el backend envió.
  String _errorMessageFrom(Map<String, dynamic> decoded) {
    for (final key in const ['message', 'detail', 'title']) {
      final value = decoded[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return 'Error inesperado del servidor';
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message';
}
