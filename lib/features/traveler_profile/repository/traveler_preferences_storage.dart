import 'dart:convert';

import 'package:royal_airlines/models/traveler_preferences_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TravelerPreferencesStorage
/// --------------------------
/// Persiste las preferencias de viaje del usuario EN DISCO
/// (SharedPreferences, mismo backend que usa `ReservationsStorage`),
/// con clave `traveler_prefs_<userId>` para que cada cuenta tenga su
/// propio conjunto de preferencias y nunca se mezclen.
///
/// Las preferencias NO se borran al cerrar sesión: pertenecen a la
/// cuenta, igual que el historial de reservas. Solo se reemplazan si
/// el usuario las edita.
///
/// La lectura es tolerante a datos corruptos: si el JSON guardado no
/// se puede leer, se devuelve [TravelerPreferencesModel.empty] en vez
/// de lanzar (mismo criterio que `reservations_storage.dart`).
class TravelerPreferencesStorage {
  static String _keyFor(String userId) => 'traveler_prefs_$userId';

  /// Clave del flag "falta subir el último guardado al servidor".
  ///
  /// Si el `PUT /users/me/preferences` falla (offline, backend caído),
  /// lo local queda como verdad y se marca este flag para reintentar
  /// la subida en el PRÓXIMO arranque. Sin el flag, ese arranque
  /// tendría un `GET` que bajaría lo viejo del servidor y pisaría lo
  /// nuevo que el usuario acababa de guardar.
  static String _pendingPushKeyFor(String userId) =>
      'traveler_prefs_pending_push_$userId';

  Future<TravelerPreferencesModel> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(userId));
      if (raw == null || raw.isEmpty) {
        return TravelerPreferencesModel.empty();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return TravelerPreferencesModel.empty();
      }
      return TravelerPreferencesModel.fromJson(decoded);
    } catch (_) {
      // JSON corrupto o estructura inesperada: preferencias vacías,
      // nunca un crash.
      return TravelerPreferencesModel.empty();
    }
  }

  Future<void> save(String userId, TravelerPreferencesModel preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(userId), jsonEncode(preferences.toJson()));
  }

  /// `true` si hay un guardado local que todavía no llegó al servidor.
  /// Tolerante: cualquier error de disco se lee como "sin pendiente".
  Future<bool> hasPendingPush(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pendingPushKeyFor(userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPendingPush(String userId, bool pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingPushKeyFor(userId), pending);
  }
}
