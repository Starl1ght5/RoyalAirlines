import 'dart:convert';

/// JwtClaims
/// ---------
/// Claims del JWT que emite el backend (Spring Boot + jjwt).
///
/// El token trae:
///  - `sub`: el correo del usuario (subject).
///  - `id` : el identificador del usuario en la base de datos.
///  - `exp`: momento de expiración, en segundos desde epoch.
///
/// La firma NO se verifica aquí — el backend es la única autoridad.
/// Esta clase solo LEE el payload para responder preguntas que el
/// frontend necesita sin una llamada extra. El caso principal es la
/// restauración de sesión: este backend no expone un endpoint de
/// "usuario actual", así que la vigencia del token se decide mirando
/// su `exp` en vez de confiar en un 401 de una ruta inexistente.
class JwtClaims {
  const JwtClaims({this.subject, this.userId, this.expiresAt});

  /// Correo del usuario (`sub`).
  final String? subject;

  /// Identificador del usuario (`id`).
  final String? userId;

  /// Momento de expiración del token (`exp`).
  final DateTime? expiresAt;

  /// `true` si el token ya venció.
  ///
  /// Si el token no trae `exp` se considera vencido: es más seguro
  /// pedir login de nuevo que dejar entrar a alguien con un token que
  /// no se puede verificar.
  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return true;
    return exp.isBefore(DateTime.now());
  }

  /// Lee los claims de un JWT **sin verificar la firma**.
  ///
  /// Devuelve `null` si el token está vacío, no tiene los tres
  /// segmentos de un JWT o su payload no es un JSON válido. Nunca
  /// lanza excepciones.
  static JwtClaims? tryParse(String? token) {
    if (token == null || token.isEmpty) return null;

    final segments = token.split('.');
    if (segments.length != 3) return null;

    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;

      final subject = payload['sub'];
      final userId = payload['id'];
      final exp = payload['exp'];

      return JwtClaims(
        subject: subject is String ? subject : null,
        userId: userId is String ? userId : null,
        expiresAt: exp is num
            ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000)
            : null,
      );
    } catch (_) {
      // Token corrupto o de otro formato: se trata como "sin claims".
      return null;
    }
  }
}
