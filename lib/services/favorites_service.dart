import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';

enum FavoriteTarget { destination, flight }

class FavoriteItem {
  const FavoriteItem({required this.targetType, required this.targetId});
  final FavoriteTarget targetType;
  final String targetId; // Location.locationID o Flight.flightID

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
        targetType: json['targetType'] == 'FLIGHT'
            ? FavoriteTarget.flight
            : FavoriteTarget.destination,
        targetId: json['targetId']?.toString() ?? '',
      );
}

String _wire(FavoriteTarget t) =>
    t == FavoriteTarget.flight ? 'FLIGHT' : 'DESTINATION';

class FavoritesService {
  FavoritesService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Lista ordenada por fecha descendente. `ApiClient` envuelve los
  /// arrays en `data`, por eso se lee `response['data']`.
  Future<List<FavoriteItem>> list() async {
    final response = await _client.get(ApiEndpoints.favorites);
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(FavoriteItem.fromJson)
        .toList();
  }

  /// Idempotente en el backend: si ya existía devuelve el favorito
  /// existente sin duplicarlo (201). Lanza `ApiException` con 404 si
  /// `targetId` no existe (`Location.locationID` / `Flight.flightID`)
  /// y con 409 si el usuario ya tiene los 200 favoritos.
  Future<void> add(FavoriteTarget type, String targetId) =>
      _client.post(ApiEndpoints.favorites,
          body: {'targetType': _wire(type), 'targetId': targetId});

  /// 204 sin cuerpo; `ApiClient.delete` ya existe y `_decodeResponse`
  /// trata el 204 vacío como éxito.
  Future<void> remove(FavoriteTarget type, String targetId) =>
      _client.delete('${ApiEndpoints.favorites}/${_wire(type)}/$targetId');
}

// Uso en la UI (fase de favoritos): actualizar el corazón de inmediato y,
// si add/remove lanza ApiException, revertirlo (optimista + rollback).
// El estado inicial se refresca con list() al arrancar la sesión.
//
// OJO: NO llamar a track() en favoritos — favorite_add / favorite_remove
// los emite el servidor con context: "favorites" (y solo si hay
// consentimiento). Enviarlos del cliente sería duplicado y además el
// backend los rechaza.
