import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_airlines/models/user_model.dart';

/// SessionStorage
/// --------------
/// Persiste la sesión del usuario en el dispositivo, para que la app
/// recuerde quién inició sesión aunque se cierre por completo — igual
/// que Instagram, Facebook o Steam. Solo se borra al cerrar sesión
/// explícitamente desde Perfil, o automáticamente si la sesión expiró.
///
/// El token de acceso se guarda cifrado con [FlutterSecureStorage]
/// (Keystore en Android / Keychain en iOS), nunca en texto plano.
/// El resto de los datos del [UserModel] (nunca la contraseña) se
/// guardan en SharedPreferences por simplicidad, ya que no son
/// sensibles por sí solos.
class SessionStorage {
  static const _keyToken = 'session_access_token';
  static const _keyUserId = 'session_user_id';
  static const _keyFullName = 'session_user_fullName';
  static const _keyEmail = 'session_user_email';
  static const _keyAvatarUrl = 'session_user_avatarUrl';
  static const _keyLoginAt = 'session_login_at';

  /// Tiempo máximo que una sesión permanece válida sin volver a
  /// iniciar sesión. Pasado este tiempo, [loadUser] la descarta y se
  /// pide login de nuevo, aunque el dispositivo no se haya
  /// desconectado nunca.
  static const Duration sessionDuration = Duration(days: 7);

  static const _secureStorage = FlutterSecureStorage();

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, user.id);
    await prefs.setString(_keyFullName, user.fullName);
    await prefs.setString(_keyEmail, user.email);
    await prefs.setString(_keyLoginAt, DateTime.now().toIso8601String());
    if (user.avatarUrl != null) {
      await prefs.setString(_keyAvatarUrl, user.avatarUrl!);
    } else {
      await prefs.remove(_keyAvatarUrl);
    }
  }

  /// Guarda el token de acceso cifrado (no en SharedPreferences).
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _keyToken, value: token);
  }

  Future<String?> loadToken() async {
    return _secureStorage.read(key: _keyToken);
  }

  /// Devuelve el usuario guardado, o `null` si nunca inició sesión, ya
  /// cerró sesión, o la sesión guardada ya superó [sessionDuration]
  /// (en cuyo caso también se borra automáticamente).
  Future<UserModel?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_keyUserId);
    final fullName = prefs.getString(_keyFullName);
    final email = prefs.getString(_keyEmail);

    if (userId == null || fullName == null || email == null) {
      return null;
    }

    final loginAtRaw = prefs.getString(_keyLoginAt);
    if (loginAtRaw != null) {
      final loginAt = DateTime.tryParse(loginAtRaw);
      if (loginAt != null &&
          DateTime.now().difference(loginAt) > sessionDuration) {
        await clear();
        return null;
      }
    }

    return UserModel(
      id: userId,
      fullName: fullName,
      email: email,
      avatarUrl: prefs.getString(_keyAvatarUrl),
    );
  }

  /// Borra la sesión guardada. Se llama al cerrar sesión, o
  /// automáticamente cuando [loadUser] detecta que expiró.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyAvatarUrl);
    await prefs.remove(_keyLoginAt);
    await _secureStorage.delete(key: _keyToken);
  }
}
