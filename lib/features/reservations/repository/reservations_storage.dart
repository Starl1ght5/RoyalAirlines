import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_airlines/models/reservation_model.dart';

/// ReservationsStorage
/// -------------------
/// Persiste el historial de reservas EN DISCO (SharedPreferences, como
/// JSON), asociado al `userId` de la cuenta que las creó. Así el
/// historial sobrevive a que la app se cierre por completo o al
/// dispositivo se reinicie — el usuario no debe sentir que su viaje
/// "desapareció" solo porque salió de la app (no es un Hot Reload).
///
/// La clave de guardado incluye el `userId` para que, si dos cuentas
/// distintas usan el mismo dispositivo, cada una vea solo SUS propias
/// reservas. Al cerrar sesión NO se borra nada de aquí: las reservas
/// son historial legítimo de la cuenta y deben seguir apareciendo la
/// próxima vez que esa misma cuenta inicie sesión.
class ReservationsStorage {
  static String _keyFor(String userId) => 'reservations_$userId';

  Future<List<ReservationModel>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(userId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Datos corruptos de una versión vieja del modelo: se ignoran en
      // vez de tumbar la app, el usuario simplemente ve el historial
      // vacío y sigue reservando con normalidad.
      return [];
    }
  }

  Future<void> save(String userId, List<ReservationModel> reservations) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(reservations.map((r) => r.toJson()).toList());
    await prefs.setString(_keyFor(userId), raw);
  }
}
