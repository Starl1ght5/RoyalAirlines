import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';

/// Versión de la política de consentimiento que se envía en cada `PUT`.
/// El backend la guarda en `User.consentVersion` para poder demostrar
/// Bajo qué texto aceptó cada persona (y pedir de nuevo si cambia).
const String consentVersion = 'v1';

/// TrackingConsent
/// ---------------
/// Los DOS permisos del consentimiento, que son independientes:
/// - [tracking]: autoriza a registrar eventos de comportamiento
///   (`POST /events`). Sin él el backend responde 202 con
///   `accepted:0, trackingEnabled:false` y no se entrena nada.
/// - [marketingOptIn]: autoriza ofertas por correo/notificación.
///   Sin él no hay campañas, aunque el tracking esté activo.
class TrackingConsent {
  const TrackingConsent({
    required this.tracking,
    required this.marketingOptIn,
    this.consentDate,
  });

  final bool tracking;
  final bool marketingOptIn;

  /// `consentDate` solo viene en el `GET` (cuándo se dio/retiró).
  final String? consentDate;

  /// Cuerpo listo para `PUT /users/me/consent`.
  Map<String, dynamic> toJson() => {
        'tracking': tracking,
        'marketingOptIn': marketingOptIn,
        'consentVersion': consentVersion,
      };
}

/// Consentimiento opt-in para registrar eventos y para marketing
/// (`GET`/`PUT /users/me/consent`). Sin `tracking=true`, UserEventTracker
/// se queda apagado y el backend no guarda nada de comportamiento.
class TrackingConsentService {
  TrackingConsentService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Estado actual. Si el backend no responde (o la ruta aún no existe),
  /// lanza `ApiException`: quien llame debe conservar el estado que ya
  /// tenía y reintentar más tarde, NO asumir `false`.
  Future<TrackingConsent> fetch() async {
    final json = await _client.get(ApiEndpoints.trackingConsent);
    return TrackingConsent(
      // `json['tracking'] == true` (no `?? false`): un cuerpo sin la
      // clave se trata como "sin confirmar", y en ese caso lo correcto
      // es NO empezar a recolectar.
      tracking: json['tracking'] == true,
      marketingOptIn: json['marketingOptIn'] == true,
      consentDate: json['consentDate']?.toString(),
    );
  }

  /// Guarda ambos permisos en una sola escritura (un `PUT` por toggle
  /// envía el par completo para no pisar el permiso que no cambió).
  Future<TrackingConsent> save({
    required bool tracking,
    required bool marketingOptIn,
  }) async {
    final consent = TrackingConsent(
      tracking: tracking,
      marketingOptIn: marketingOptIn,
    );
    final json =
        await _client.put(ApiEndpoints.trackingConsent, body: consent.toJson());
    // Si el backend responde 204/sin cuerpo, se devuelve lo que se acaba
    // de guardar: asumir `false` aquí apagaría el tracker y desmarcaría
    // el toggle aunque la escritura haya sido exitosa.
    return TrackingConsent(
      tracking: json['tracking'] is bool ? json['tracking'] as bool : tracking,
      marketingOptIn: json['marketingOptIn'] is bool
          ? json['marketingOptIn'] as bool
          : marketingOptIn,
      consentDate: json['consentDate']?.toString(),
    );
  }

  /// Lectura rápida de solo tracking (la usa la puerta de arranque en
  /// `lib/app.dart`).
  Future<bool> getTracking() async => (await fetch()).tracking;
}
