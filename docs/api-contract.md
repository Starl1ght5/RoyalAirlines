# Contrato de API de Royal Airlines

Este documento es el acuerdo entre Flutter y backend para el proyecto
universitario. La app usa JSON y todas las rutas parten de:

`{BASE_URL}/api/v1`

La URL por defecto del backend (Spring Boot) es
`http://localhost:8080`, así que la base completa queda
`http://localhost:8080/api/v1`. Flutter SIEMPRE consume la API real: no
existe modo mock en la app.

> **OJO con el prefijo `/api`:** vive en `API_BASE_URL`, NO dentro de
> los endpoints. Si un endpoint llevara `/api/v1` adelante, la petición
> iría a `.../api/v1/api/v1/...` y el backend respondería 401.

> ¿Dudas sobre qué URL usar (localhost, IP del emulador, puerto) o
> cómo probar un endpoint sin depender de Flutter? Ver
> [connection-guide.md](connection-guide.md), tiene un ejemplo real con
> `curl` para `/users/login`.

> **Aviso:** las secciones de **Reservas y pago simulado** (`/bookings`,
> `/payments/confirm`, `/reservations`) y varias filas del resumen describen
> el diseño anterior. La fuente de verdad de las rutas que usa hoy la app es
> `lib/core/network/api_contracts.dart` (`/booking/create`, `/booking/my`,
> `/flights/{flightId}/seats`, `/events`, `/favorites`, `/recommendations`, etc.).

## Resumen rapido de endpoints (orden sugerido de implementacion)

Estas son las rutas que expone el backend real hoy. Las que faltan
están marcadas como **no implementado** en el backend: la app las
tolera (el error queda aislado y no tumba la pantalla) pero no tienen
datos.

| # | Metodo | Ruta | Requiere token | Notas |
|---|--------|------|:---:|-------|
| 1 | POST | `/users/register` | No | Responde 201 con el cuerpo VACÍO: el token se pide con un login después |
| 2 | POST | `/users/login` | No | Responde `{"token": "<jwt>"}`, sin envoltorio `data` y sin objeto de usuario |
| 3 | GET | `/users/verify` | No | Verificación de correo (`?verificationCode=`) |
| 4 | POST | `/auth/google` | No | Login con Google (envía JWT de Google). Responde `{"token": ...}` |
| 5 | GET | `/locations/` | No | Catálogo de destinos **y** aeropuertos. **La barra final es obligatoria** |
| 6 | GET | `/flights/search` | No | Query params, ver seccion Vuelos. Responde un ARRAY suelto |
| 7 | POST | `/flight` | Si | Crear reserva |
| 8 | GET | `/boarding/searchAll` | Si | |
| 9 | GET | `/promotions` | No | Slider de Home; array suelto con SOLO las promociones activas, generadas desde los vuelos |
| — | POST | `/auth/apple` | No | *No implementado* en el backend |
| 10 | GET | `/users/me` | Si | Perfil de la cuenta autenticada: `{id, fullName, email, avatarUrl}` |
| 11 | PUT | `/users/me` | Si | Actualiza nombre/correo. Responde el perfil + un `token` nuevo (el JWT usa el correo como sujeto) |
| 12 | POST | `/auth/change-password` | Si | Cambia la contraseña; exige `currentPassword` y `newPassword` (8-72 caracteres) |
| 13 | POST | `/auth/forgot-password` | No | Genera un código de recuperación (el envío de correo está simulado en el log). Siempre responde 200 |
| 14 | POST | `/auth/reset-password` | No | Restablece la contraseña con el código de 6 dígitos; el código es de un solo uso |
| — | GET | `/flights/{flightId}` | No | *No implementado* |
| — | GET | `/insights/community` | Si | *No usado por la app: la llamada fue eliminada* |

Todas las rutas con "Requiere token" esperan el header
`Authorization: Bearer <token>` con el `token` recibido en login/registro.

## Formato de las respuestas

El backend usa Spring Boot con Problem Details RFC 7807 para los
errores y `Page<T>` de Spring Data para las listas paginadas. Es decir:
**NO** usa el envoltorio `{success, message, data}` del contrato
anterior.

| Concepto | Formato real | Cómo lo lee la app |
|----------|--------------|--------------------|
| Lista paginada | `{"content": [...], "page": {...}}` | `response['content']` (con fallback a `data`) |
| Lista simple | `[...]` (array suelto) | `response['data']` (el `ApiClient` lo envuelve) |
| Error | `{"title": "...", "status": 401, "detail": "..."}` | `detail` (fallback a `message` y a `title`) |
| Dinero | Objeto `Money` de Joda (`amountMajor`, `amount`, `currencyUnit`) | `amountMajor` (ya en COP) |

El JWT que devuelve el login trae los claims `sub` (correo), `id`
(identificador del usuario) e `exp` (vencimiento). La app los usa para
reconstruir el usuario y para decidir si una sesión guardada sigue
vigente; al arrancar, además, refresca el perfil con `GET /users/me`.

> **CORS (solo si usan Flutter Web):** el navegador bloquea peticiones
> cross-origin. Como `flutter run -d chrome` sirve la app en un puerto
> distinto al del backend, el backend debe permitir ese origen. La
> configuración actual (`Config/CorsConfig.java`) usa
> `setAllowedOrigins(...)` con una lista explícita. Ojo: el puerto de
> Flutter Web cambia en cada ejecución — conviene fijar uno con
> `flutter run -d chrome --web-port=52345` y agregarlo a la lista, o
> usar `setAllowedOriginPatterns(List.of("http://localhost:[*]"))`.
> No afecta a escritorio, emulador ni teléfono.

## Reglas generales

- `Content-Type: application/json`
- `Accept: application/json`
- Las rutas protegidas reciben `Authorization: Bearer <token>`.
- Las fechas se envian en formato ISO 8601; los campos de fecha SIMPLE
  (sin hora), como `birthDate` de pasajeros y los query params de
  búsqueda de vuelos, usan `yyyy-MM-dd` (ej. `1995-06-15`).
- Los precios se envian como numero en COP, sin separadores.
- `travelClass` (dentro de cada tarifa/fares) usa los nombres exactos
  de este enum: `"economy"`, `"premiumEconomy"`, `"business"`,
  `"first"`.
- El campo `flight` de una reserva incluye SIEMPRE `fares` (plural,
  lista de tarifas del vuelo). El `fare` a nivel de reserva (singular)
  es la tarifa que el pasajero eligió.
- Respuesta con error: el backend usa **Problem Details RFC 7807**:

```json
{
  "type": "about:blank",
  "title": "No autenticado",
  "status": 401,
  "detail": "Credenciales invalidas",
  "instance": "/api/v1/users/login"
}
```

> Flutter muestra `detail` (con fallback a `message` y luego a
> `title`), así que `detail` es el campo donde debe ir el texto que ve
> la persona en la app.
>
> El backend todavía acepta el envoltorio `{success, message}`: si en
> algún momento se usa, Flutter lo sigue soportando y trata
> `success: false` como error aunque el HTTP sea 2xx.

## Autenticacion

> El backend expone el login y el registro bajo `/users`, **no** bajo
> `/auth`. Y la respuesta es pelada: `{"token": "..."}`, sin envoltorio
> `data` y sin objeto de usuario.

### `POST /users/register`

Request:

```json
{
  "email": "usuario@example.com",
  "password": "123456"
}
```

Response `201` con el cuerpo **vacío**. La cuenta queda creada y sin
verificar, pero el token no se entrega aquí: hay que hacer login
después. Si el correo ya existe, responde `409` con
`detail: "El email ya esta registrado"`.

### `POST /users/login`

Request:

```json
{
  "email": "demo@royalairlines.com",
  "password": "Demo2026!"
}
```

Response `200`:

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyQGV4YW1wbGUuY29tIiwiaWQiOiJ1c3JfMDAxIn0.firma"
}
```

El JWT trae los claims `sub` (correo), `id` (identificador del usuario)
e `exp` (vencimiento). La app los lee para reconstruir el usuario —el
backend no devuelve un objeto de usuario— y para decidir si una sesión
guardada sigue vigente.

Con credenciales incorrectas responde `401` con Problem Details:

```json
{
  "type": "about:blank",
  "title": "No autenticado",
  "status": 401,
  "detail": "Credenciales invalidas",
  "instance": "/api/v1/users/login"
}
```

### `GET /users/verify`

Verificación de correo. Query param `verificationCode`. Sin token.

### `GET /users/me`

Perfil de la cuenta autenticada. Requiere token.

Response `200`:

```json
{
  "id": "usr_001",
  "fullName": "Alejandro Torres",
  "email": "usuario@example.com",
  "avatarUrl": null
}
```

Si la cuenta es antigua y no tiene nombre guardado, `fullName` viaja
como cadena vacía (nunca `null`).

### `PUT /users/me`

Actualiza el nombre visible y el correo de la cuenta autenticada.
Requiere token.

Request:

```json
{
  "fullName": "Alejandro Torres",
  "email": "usuario@example.com"
}
```

Response `200`: el mismo perfil actualizado **más un `token` nuevo**:

```json
{
  "id": "usr_001",
  "fullName": "Alejandro Torres",
  "email": "usuario@example.com",
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

> El JWT usa el correo como sujeto, así que si la persona cambia su
> correo el token anterior deja de valer. El backend emite uno nuevo en
> cada `PUT` y la app lo guarda para no perder la sesión.
>
> Si el correo nuevo ya pertenece a otra cuenta responde `409` con
> `detail: "El email ya esta registrado"`.

### `POST /auth/change-password`

Cambia la contraseña del usuario autenticado. Requiere token.

Request:

```json
{
  "currentPassword": "12345678",
  "newPassword": "87654321"
}
```

- `newPassword` debe tener entre 8 y 72 caracteres (el máximo es el
  límite de BCrypt).
- Si la cuenta se creó solo con Google/Apple y no tiene contraseña
  propia, responde `400` pidiendo iniciar sesión con el proveedor.
- Si `currentPassword` no coincide, responde `400` con
  `detail: "La contrasena actual no es correcta"`.

Response `200`:

```json
{ "success": true, "message": "Contrasena actualizada" }
```

### `POST /auth/forgot-password`

Pide enviar instrucciones de recuperación de contraseña a un correo.
NO requiere token. Siempre responde `200`, exista o no la cuenta, para
no filtrar qué correos están registrados.

Request:

```json
{
  "email": "usuario@example.com"
}
```

Response `200`:

```json
{
  "success": true,
  "message": "Si el correo existe, recibiras instrucciones"
}
```

> El backend genera un código de 6 dígitos con vencimiento de 30
> minutos. Como no hay servidor SMTP configurado, el envío del correo
> está simulado: el código se guarda en la cuenta y se escribe en el
> log del servidor.

### `POST /auth/reset-password`

Restablece la contraseña usando el código de recuperación. NO requiere
token (quien olvidó su contraseña no puede autenticarse).

Request:

```json
{
  "email": "usuario@example.com",
  "code": "123456",
  "newPassword": "87654321"
}
```

- `code` debe tener exactamente 6 dígitos.
- `newPassword` debe tener entre 8 y 72 caracteres.
- El código es de **un solo uso**: al aceptarse se borra junto con su
  vencimiento.
- Un correo inexistente, un código equivocado y un código vencido
  responden igual (`400`, `detail: "El codigo es invalido o ha expirado"`)
  para no filtrar qué correos están registrados.

Response `200`:

```json
{ "success": true, "message": "Contrasena actualizada" }
```

### `POST /auth/google`

Login con Google. NO requiere token. La app abre el diálogo nativo de
Google (`google_sign_in`), obtiene un `idToken` (JWT) y lo envía aquí.
El backend DEBE verificar la firma del JWT con las llaves públicas de
Google antes de aceptarlo, y luego crear o encontrar al usuario por el
`sub`/`email` que trae el token.

Request:

```json
{
  "identityToken": "jwt_emitido_por_google"
}
```

Response `200`: misma estructura que `/auth/login` (`token` + `user`).

### `POST /auth/apple`

Login con Apple. NO requiere token. Mismo flujo que Google pero con el
`identityToken` que produce `sign_in_with_apple`. Apple solo envía el
nombre completo la PRIMERA vez que el usuario autoriza la app, por eso
`fullName` es opcional.

Request:

```json
{
  "identityToken": "jwt_emitido_por_apple",
  "fullName": "Ada Lovelace"
}
```

Response `200`: `{"token": "..."}`, misma estructura que `/users/login`.

## Home

### `GET /locations/`

El catálogo de destinos y aeropuertos. Ver la sección
[`GET /locations/`](#get-locations) para el formato completo de la
respuesta (`{content, page}`).

> No existe un `/airports` separado: es el mismo recurso. La app pide
> los airports y los destinos al mismo endpoint.

### `GET /promotions`

Promociones para el slider de Home. **Ruta pública: no pide token.**

La respuesta es un **ARRAY suelto** (no paginado; el `ApiClient` lo
envuelve en `data`) y trae SOLO las promociones con `active: true`, en
el orden en que deben mostrarse. Si no hay ninguna, responde `[]` y el
slider simplemente no se pinta.

**Las promociones se generan solas a partir de los vuelos** (no hay
seed estático): `PromotionService` toma los vuelos `ACTIVE` de los
próximos 90 días, los agrupa por ruta y publica las 6 mejores según un
puntaje mixto (descuento + baratura + directo + destino featured). Se
regeneran con un cron diario (03:55, `royal.promotions.refresh-cron`),
al servir si los documentos tienen más de 6 horas, y a mano con
`POST /internal/promotions/refresh`. Si no hay ningún vuelo
utilizable se conservan las promociones actuales (no se vacía el
slider).

Dos reglas anti-repetición: **una sola tarjeta por ciudad destino**
(el ranking elige qué ruta la representa) y el badge `% OFF` **solo en
la mejor oferta** de la muestra — el resto de las tarjetas muestra
`Desde COP ...`.

Al tocar una tarjeta el front navega a los resultados de
`origin` → `destination` en la fecha `departureDate`: por eso la fecha
viaja en la respuesta, para que la búsqueda siempre aterrice en un día
con vuelos reales. Para ocultar una promoción se pone `active: false`
en la base, NO se borra el documento (el refresh conserva ese campo
manual).

Response `data`:

```json
[
  {
    "id": "promo_BOG_CTG",
    "title": "Ofertas a Cartagena",
    "subtitle": "Vuelos directos desde Bogotá",
    "discountLabel": "Hasta 30% OFF",
    "origin": "BOG",
    "destination": "CTG",
    "departureDate": "2026-11-15",
    "active": true
  }
]
```

Campos:

- `title`, `subtitle`, `discountLabel`: los tres textos que pinta la
  tarjeta (el badge mide ~11.5px: mantenerlo corto).
- `origin`, `destination`: códigos IATA de la ruta que promete la
  tarjeta.
- `departureDate`: fecha (`yyyy-MM-dd`) del vuelo más barato de la
  ruta — es el vuelo cuyo precio publica el badge. Puede venir `null`
  en documentos antiguos: el front entonces cae a la fecha elegida en
  el buscador.
- `active`: el endpoint solo devuelve `true`; se conserva en el shape
  porque el front lo revisa (`item['active'] != false`).

### `GET /locations/`

Catálogo de destinos **y** aeropuertos. Es el único catálogo del
backend: la app lo usa tanto para los destinos populares de Home como
para el selector de origen/destino del buscador.

**La barra final es obligatoria**: el controller mapea
`@GetMapping("/")` sobre `@RequestMapping("/api/v1/locations")` y
Spring Boot 4 ya no hace *matching* con barra opcional, así que
`GET /locations` (sin barra) responde **404**.

Query parameters:

- `page`: número de página, empezando en cero. Por defecto `0`.
- `size`: cantidad de destinos por página. Por defecto `10`, máximo `50`.
- `featured`: si es `true`, devuelve solo los destacados. Por defecto
  `false`.

Respuesta (`Page<LocationDTO>` de Spring Data):

```json
{
  "content": [
    {
      "locationID": "6ad58b1754ba06e9d564c123",
      "cityName": "Madrid",
      "countryName": "España",
      "iataCode": "MAD",
      "airportName": "Aeropuerto Adolfo Suárez Madrid-Barajas",
      "cheapestPrice": {
        "amount": 160000.00,
        "amountMajor": 160000,
        "amountMinor": 16000000,
        "currencyUnit": { "code": "COP", "decimalPlaces": 2, "symbol": "$" }
      },
      "featured": true,
      "climate": "Mediterráneo continentalizado",
      "bestDate": "Marzo - Mayo / Septiembre - Noviembre",
      "activities": ["Arte", "Museos", "Gastronomía"],
      "rating": 3.0
    }
  ],
  "page": { "size": 10, "number": 0, "totalElements": 3, "totalPages": 1 }
}
```

Los nombres del DTO (`iataCode`, `cityName`, `countryName`) NO coinciden
con los del modelo de la app (`code`, `city`, `country`): el parser
traduce de un juego al otro.

## Vuelos

### `GET /flights/search`

Query parameters:

`origin=BOG&destination=CTG&departureDate=2026-09-01&returnDate=2026-09-05&passengers=2`

- `departureDate` y `returnDate` (opcional, solo ida y vuelta):
  formato `yyyy-MM-dd`.
- `passengers`: total de pasajeros (adultos + niños + infantes).

La respuesta es un **ARRAY suelta** (no un objeto envuelto).

Cada vuelo (`FlightDTO`) incluye `flightID`, `airline`, `ticketPrice`
(objeto `Money`), `duration`, `flightNumber`, `aircraft`,
`departureLocation` y `arrivalLocation` (ambos `LocationDTO`),
`departureDate`, `arrivalDate`, `scales` y `availableFares` (lista de
`FaresDTO`).

Cada tarifa (`FaresDTO`) incluye `feeID`, `travelClass` (nombre de enum,
ver Reglas generales), `tierName`, `priceDifference`, `seatsAvailable`,
`benefits` (lista de textos) y `price` (objeto `Money`).

> Estos nombres tampoco coinciden con los del modelo de la app
> (`id`/`origin`/`destination`/`departureTime`/`stops`/`fares`): el
> parser acepta los dos juegos de nombres.

### `GET /flights/{flightId}`

Devuelve el detalle de un vuelo y sus tarifas disponibles.

## Reservas y pago simulado

### `POST /bookings`

Request:

```json
{
  "flightId": "FL_1001",
  "passengers": [
    {
      "fullName": "Nombre del pasajero",
      "documentNumber": "12345678",
      "birthDate": "1995-06-15"
    }
  ],
  "fareType": "economy",
  "seats": ["12A", "12B"],
  "extras": {
    "selectedSeats": [
      { "seatCode": "12A", "category": "estandar", "price": 46000 },
      { "seatCode": "12B", "category": "estandar", "price": 46000 }
    ],
    "baggage": { "option": "extra10kg", "price": 15000 },
    "services": [
      { "name": "travelInsurance", "price": 25000 },
      { "name": "priorityBoarding", "price": 18000 }
    ]
  }
}
```

- `passengers[].birthDate`: formato `yyyy-MM-dd` (sin hora).
- `fareType`: nombre de enum de `travelClass` (`"economy"`,
  `"premiumEconomy"`, ...).
- `extras` (opcional): desglose de cargos adicionales que la app ya
  cobró al usuario en la UI (cargo por asiento, equipaje, seguro,
  embarque prioritario). El backend DEBE usarlo para calcular el
  `totalPrice` definitivo de la reserva:

```
totalPrice = (precio de la tarifa × número de pasajeros)
           + suma de extras.selectedSeats[].price
           + extras.baggage.price
           + suma de extras.services[].price
```

Response `201`:

```json
{
  "success": true,
  "data": {
    "bookingId": "BK_1001",
    "status": "pending_payment",
    "totalPrice": 627000
  }
}
```

> El `totalPrice` de esta respuesta es el monto AUTORITATIVO: el
> frontend lo reutiliza como `amount` de `POST /payments/confirm`. No
> calcule un total distinto al desglose enviado.

### `POST /payments/confirm`

Es un pago simulado para la presentacion. Nunca se debe guardar el numero
completo ni el CVV.

**Importante:** el campo del monto se llama `amount` (no `totalPrice`),
para diferenciarlo del `totalPrice` que sí usa `POST /bookings`. Son dos
endpoints distintos con nombres de campo distintos a propósito. El valor
de `amount` DEBE ser igual al `totalPrice` devuelto por
`POST /bookings`.

Request:

```json
{
  "bookingId": "BK_1001",
  "paymentMethod": "card",
  "cardHolderName": "Titular de la tarjeta",
  "cardLastFour": "4242",
  "expiry": "12/29",
  "amount": 627000,
  "currency": "COP"
}
```

Response aprobada:

```json
{
  "success": true,
  "data": {
    "paymentId": "PAY_1001",
    "status": "approved",
    "reservationId": "RSV_1001",
    "confirmationCode": "ROYAL7A2"
  }
}
```

### `GET /reservations`

Lista las reservas del usuario autenticado, identificado por el token
(`Authorization`) — **no** recibe `userId` como query param. Puede
aceptar `status` como filtro opcional.

Response `data`: lista de reservas con esta forma (la parsea
`ReservationService`/`ReservationModel` de Flutter):

```json
[
  {
    "id": "RSV_1001",
    "confirmationCode": "ROYAL7A2",
    "flight": {
      "id": "FL_1001",
      "airline": "Royal Airlines",
      "flightNumber": "RA 1001",
      "aircraft": "Boeing 737-800",
      "origin": {
        "code": "BOG",
        "city": "Bogota",
        "country": "Colombia",
        "airportName": "El Dorado"
      },
      "destination": {
        "code": "CTG",
        "city": "Cartagena",
        "country": "Colombia",
        "airportName": "Rafael Nunez"
      },
      "departureTime": "2026-09-01T08:00:00",
      "arrivalTime": "2026-09-01T09:30:00",
      "stops": 0,
      "fares": [
        {
          "travelClass": "economy",
          "tierName": "Basic",
          "price": 260000,
          "seatsAvailable": 12,
          "benefits": ["Equipaje de mano 10 kg"]
        }
      ]
    },
    "fare": {
      "travelClass": "economy",
      "tierName": "Basic",
      "price": 260000,
      "seatsAvailable": 12,
      "benefits": ["Equipaje de mano 10 kg"]
    },
    "seats": ["12A", "12B"],
    "passengers": [
      {
        "fullName": "Nombre del pasajero",
        "documentNumber": "12345678",
        "birthDate": "1995-06-15"
      }
    ],
    "payment": {
      "cardHolderName": "Titular de la tarjeta",
      "maskedCardNumber": "•••• •••• •••• 4242",
      "expiry": "12/29"
    },
    "totalPrice": 627000,
    "bookedAt": "2026-08-20T14:30:00"
  }
]
```

Notas importantes:

- `flight.fares` (plural): lista de tarifas del vuelo — el MISMO shape
  que `GET /flights/search`. No hace falta mandar `fare` (singular)
  dentro de `flight`.
- `fare` (singular, a nivel reserva): la tarifa que el pasajero eligió.
- `payment.maskedCardNumber`: solo los últimos 4 dígitos enmascarados;
  nunca el número completo.

### `GET /reservations/{reservationId}`

Devuelve el detalle de una reserva confirmada con la MISMA forma de
`GET /reservations`, pero `data` es un único objeto reserva (no lista).

### `GET /insights/community` (NO usada por la app)

Esta ruta **dejo de usarse en el frontend**: se eliminaron
`CommunityInsightsService`, la constante `ApiEndpoints.communityInsights`,
el modelo `CommunityInsights` y la sección "Comparación con la comunidad"
de `TravelerProfileScreen`.

Toda la pestaña "Para ti" se resuelve sin esta llamada:

- Arquetipo y dashboard personal → cálculo 100% local
  (`TravelerProfileRepository.classify` sobre `ReservationsStore`).
- Preferencias declaradas → `GET`/`PUT /users/me/preferences`.
- Recomendaciones → `GET /recommendations`.

Si más adelante el equipo implementa el agregado global, habría que
volver a crear la constante en `ApiEndpoints`, su servicio y la tarjeta
de comparación.

## Orden de implementacion recomendado

1. Auth: register, login y me.
2. Airports, promotions y destinations.
3. Flights search y flight detail.
4. Bookings.
5. Payment confirm simulado.
6. Reservations y reservation detail.
7. Forgot-password (recuperación de contraseña).

Flutter ya está escrito contra estas rutas: en cuanto Spring Boot
responda con el formato de este contrato en
`http://localhost:8080/api/v1`, la app funciona sin cambios de código.
