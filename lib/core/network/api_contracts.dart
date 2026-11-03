/// ApiEndpoints
/// ------------
/// Contratos HTTP para la app de vuelos escolar.
///
/// IMPORTANTE — dónde va el prefijo `/api`:
///
/// El backend real sirve TODO bajo `http://localhost:8080/api/v1/...`.
/// [AppConfig.baseUrl] ya apunta a `.../api/v1`, así que estas rutas
/// son RELATIVAS y NUNCA deben llevar `/api/v1` adentro: hacerlo
/// duplicaría el prefijo y la petición iría a
/// `http://localhost:8080/api/v1/api/v1/...`, que responde 401.
///
/// Barras finales: el backend mapea algunas rutas con `@GetMapping("/")`
/// sobre un `@RequestMapping("/api/v1/xyz")`. Spring Boot 4 ya no hace
/// matching con barra opcional, así que `/locations` (sin barra)
/// responde 404 y `/locations/` responde 200. Por eso las rutas de
/// este archivo llevan la barra cuando el backend la exige.
class ApiEndpoints {
  ApiEndpoints._();

  // ------------------------------------------------------------------
  // Autenticación
  // ------------------------------------------------------------------

  /// Login con correo y contraseña.
  ///
  /// OJO: este backend expone el login bajo `/users`, NO bajo `/auth`.
  /// Responde `{"token": "<jwt>"}` (sin envoltorio `data` y sin objeto
  /// de usuario).
  static const String login = '/users/login';

  /// Registro de cuenta. Responde 201 con el cuerpo VACÍO: el token se
  /// obtiene haciendo login después de registrar.
  static const String register = '/users/register';

  /// Login social: la app envía el token de identidad (JWT) que obtuvo
  /// del proveedor — Google (`idToken`) o Apple (`identityToken`) — y el
  /// backend lo verifica con las llaves públicas del proveedor antes de
  /// crear/devolver la sesión. Mismo shape de respuesta que [login].
  static const String authGoogle = '/auth/google';
  static const String authApple = '/auth/apple';

  /// Perfil del usuario autenticado — `GET`/`PUT /users/me`.
  ///
  /// El `GET` devuelve `{id, fullName, email, avatarUrl}` y refresca la
  /// sesión guardada al arrancar. El `PUT` actualiza nombre/correo y
  /// responde el MISMO perfil más un `token` nuevo: el JWT usa el correo
  /// como sujeto, así que al cambiarlo el token anterior deja de valer.
  static const String profile = '/users/me';

  static const String changePassword = '/auth/change-password';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // ------------------------------------------------------------------
  // Catálogo
  // ------------------------------------------------------------------

  /// Catálogo de aeropuertos y destinos: `GET /locations/`.
  ///
  /// La barra final es OBLIGATORIA (ver la nota de la clase).
  ///
  /// Este backend tiene un único catálogo: el mismo recurso sirve para
  /// alimentar el selector de origen/destino y la lista de destinos
  /// populares de Home.
  static const String locations = '/locations/';

  /// Aeropuertos disponibles para el buscador. Alias de [locations].
  static const String airports = locations;

  /// Destinos populares destacados en Home. Alias de [locations].
  static const String destinations = locations;

  /// Promociones activas para el slider de Home.
  ///
  /// Ruta PÚBLICA (sin token): responde con un ARRAY suelto que este
  /// cliente envuelve en `data`. Solo trae promociones `active: true`
  /// y, si no hay ninguna, devuelve `[]` y el slider no se pinta, sin
  /// romper el resto de la pantalla.
  ///
  /// El backend las genera solo a partir de los vuelos próximos (ver
  /// `docs/api-contract.md`): además de los tres textos de la tarjeta
  /// trae `origin`/`destination` (IATA de la ruta) y `departureDate`
  /// (fecha del vuelo más barato), que son con lo que el tap de la
  /// tarjeta arma la búsqueda hacia FlightsScreen.
  static const String promotions = '/promotions';

  // ------------------------------------------------------------------
  // Vuelos
  // ------------------------------------------------------------------

  /// Búsqueda de vuelos. El detalle COMPLETO de cada vuelo (tarifas
  /// incluidas) viaja dentro de esta respuesta: el backend no tiene
  /// `GET /flights/{flightId}` (consultarlo daría 404).
  static const String flightsSearch = '/flights/search';

  /// Mapa de asientos de un vuelo — `GET /flights/{flightId}/seats`.
  ///
  /// Ruta PÚBLICA (no pide JWT). La cabina es fija (15 filas × A–F =
  /// 90 asientos) y la respuesta trae las categorías con su rango de
  /// filas y precio en COP, las filas con espacio extra, los asientos
  /// tomados (`takenSeats`: retenidos + confirmados) y cuántos quedan
  /// libres (`seatsLeft`).
  static const String flightSeats = '/flights/{flightId}/seats';

  // ------------------------------------------------------------------
  // Reservas — el controlador vive bajo `/api/v1/booking`
  // ------------------------------------------------------------------

  /// Crea una reserva (nace `PENDING` con los asientos retenidos) y
  /// responde 201 con SOLO el id de la reserva. Si otro usuario tomó
  /// uno de los asientos pedidos, responde **409** y hay que recargar
  /// el mapa de asientos.
  static const String bookingCreate = '/booking/create';

  /// Reservas del usuario autenticado (`List<BookingDTO>`).
  static const String bookingMy = '/booking/my';

  /// Detalle de una reserva (`BookingDTO`).
  static const String bookingDetail = '/booking/{bookingId}';

  /// Confirma (paga) una reserva `PENDING`. El id viaja como QUERY
  /// param (`?id=`), no en el cuerpo: `PATCH /booking/confirm?id=...`.
  static const String bookingConfirm = '/booking/confirm';

  /// Cancela una reserva y libera sus asientos: `PATCH ?id=`.
  static const String bookingCancel = '/booking/cancel';

  /// Califica el viaje de una reserva `CONFIRMED` cuyo vuelo ya llegó
  /// (una sola vez): `PATCH ?id=...&rating=1..5`.
  static const String bookingRate = '/booking/rate';

  // ------------------------------------------------------------------
  // Recolección de datos para recomendaciones
  // ------------------------------------------------------------------

  /// Telemetría de comportamiento — `POST /events`.
  ///
  /// Body `{"events": [...]}` con **máximo 50** eventos por llamada;
  /// responde **202** `{"accepted": n, "rejected": m,
  /// "trackingEnabled": bool}`. Sin `consentTracking=true` el backend
  /// acepta el lote pero no guarda nada (`trackingEnabled:false`), así
  /// que el front NO debe abortar el envío por eso: lo usan
  /// [UserEventTracker] y las UI que llaman a `track()`.
  ///
  /// Solo el cliente puede enviar tipos de la lista cerrada
  /// (`search`, `flight_view`, `flight_click`, `checkout_start`,
  /// `destination_view`, `*_impression`...); `favorite_*`,
  /// `booking_*` y `preferences_updated` los emite el servidor.
  static const String events = '/events';

  /// Favoritos del usuario — `GET`/`POST /favorites` y
  /// `DELETE /favorites/{targetType}/{targetId}` (`targetType` en
  /// MAYÚSCULAS: `DESTINATION` | `FLIGHT`). El favorito se guarda
  /// aunque no haya consentimiento; los eventos `favorite_add` /
  /// `favorite_remove` los emite el servidor (por eso el front NO
  /// llama a `track()` al tocar un corazón). Máximo 200 por usuario
  /// (409 al excederlo). Lo usa [FavoritesService].
  static const String favorites = '/favorites';

  /// Recomendaciones del usuario — `GET /recommendations` (JWT).
  ///
  /// Devuelve la lista precalculada por el recomendador Python como
  /// `RecommendationListDTO`: `{strategy, modelVersion,
  /// recommendationID, generatedAt, items[]}` (sin envolver en
  /// `data`). SIEMPRE responde con una lista: si el job no corrió, el
  /// backend cae a `__popular__` o calcula un respaldo `fallback` al
  /// vuelo — nunca 404 por lista faltante.
  ///
  /// El `recommendationID` es el id de la LISTA y debe reenviarse en
  /// los eventos (`recommendationId`) y en las reservas
  /// (source `RECOMMENDATION`) para medir conversión. Lo usa
  /// [RecommendationService].
  static const String recommendations = '/recommendations';

  /// Preferencias declaradas del usuario — `GET`/`PUT`/`DELETE
  /// /users/me/preferences`.
  ///
  /// El `GET` responde **200** con `{"configured": false}` mientras no
  /// haya nada guardado (nunca 404/204). El primer `PUT` exitoso marca
  /// `User.onboardingCompleted=true` en el backend: hasta que el
  /// usuario guarde preferencias no se considera listo para
  /// recomendaciones. Lo usa [TravelerPreferencesRemoteService].
  static const String userPreferences = '/users/me/preferences';

  /// Consentimiento — `GET`/`PUT /users/me/consent`.
  ///
  /// `GET` → `{tracking, marketingOptIn, consentDate}`; `PUT` →
  /// `{tracking, marketingOptIn, consentVersion}`. Son DOS permisos
  /// separados: `tracking` habilita la recolección de eventos de
  /// comportamiento (sin él `POST /events` no guarda nada) y
  /// `marketingOptIn` autoriza ofertas por correo/notificación. Lo usa
  /// [TrackingConsentService].
  static const String trackingConsent = '/users/me/consent';

  /// Histórico de precios — `GET /prices/history?origin=BOG&destination
  /// =MDE&departureDate=yyyy-MM-dd&days=1..180` (solo lectura; por
  /// defecto 30 días).
  ///
  /// Lo escribe una tarea programada del backend (03:30), NO hay
  /// endpoint de escritura: si la ruta nunca tuvo vuelos la respuesta
  /// es `[]` y la UI debe mostrar "aún no hay historial", no un error.
  /// Los precios vienen en **USD** (única ruta en USD de toda la app).
  static const String priceHistory = '/prices/history';

  // ------------------------------------------------------------------
  // Notificaciones push
  // ------------------------------------------------------------------

  /// Dispositivos para push — `PUT /users/me/devices` (upsert del token FCM:
  /// `{token, platform: "android"|"ios", appVersion?}`, responde 204) y
  /// `DELETE /users/me/devices/{token}` (204; si el token no existe no pasa
  /// nada). Requiere JWT. Lo usa [PushNotificationService].
  static const String userDevices = '/users/me/devices';
}
