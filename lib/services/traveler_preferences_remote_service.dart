import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';

/// Sincroniza las preferencias con Spring. SharedPreferences queda como caché
/// local: si el servidor falla, la app sigue con lo guardado en el teléfono.
class TravelerPreferencesRemoteService {
  TravelerPreferencesRemoteService({ApiClient? client})
      : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Devuelve null si el servidor aún no tiene preferencias.
  ///
  /// El backend responde 200 {"configured": false} en ese caso. No se usa 404
  /// porque ApiClient trata un cuerpo vacío como éxito (data = null) y
  /// fromJson devolvería preferencias VACÍAS, pisando las locales.
  Future<TravelerPreferencesModel?> fetch() async {
    final json = await _client.get(ApiEndpoints.userPreferences);
    if (json['configured'] == false || json['interests'] == null) return null;
    return TravelerPreferencesModel.fromJson(json);
  }

  Future<void> push(TravelerPreferencesModel prefs) async {
    await _client.put(ApiEndpoints.userPreferences, body: prefs.toJson());
  }
}

// Uso en TravelerPreferencesController:
//  _load():  1) cargar caché local y notificar;
//            2) remote.fetch(): si hay datos, guardarlos en local y notificar;
//               si devuelve null y el local tiene datos, remote.push(local) (migración única).
//            Envolver el paso 2 en try/catch (ApiException): offline no debe romper la pantalla.
//  save():   validar -> storage.save (local) -> remote.push (si falla, conservar lo local
//            y reintentar en el próximo arranque).
