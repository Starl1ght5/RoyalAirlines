# Royal Airlines

Aplicación móvil Flutter para buscar y reservar vuelos, con recomendaciones
de destinos basadas en las preferencias y el comportamiento del viajero.
Proyecto universitario que se integra con una API REST en Spring Boot y un
módulo de minería de datos.

**Repositorio:** https://github.com/cbdvxzDev/Front-Flutter  
**Rama principal:** `main`

## Arquitectura

```text
Flutter  -- HTTP/REST -->  Spring Boot  -- bajo demanda -->  Python
   |                         |
   |                         v
   |                    MongoDB
   |               (localhost:27017)
   v
Backend: localhost:8080
```

- **Flutter:** interfaz móvil, navegación, validación y consumo de la API.
  Siempre consume la API real; no existe modo mock dentro de la app.
- **Spring Boot:** API principal en `http://localhost:8080`, autenticación,
  reservas, notificaciones push y conexión con la base de datos.
- **Python:** procesamiento de minería de datos y cálculo de recomendaciones,
  solicitado por Spring Boot.
- **MongoDB:** persistencia de usuarios, reservas y datos de operación.
  Solo Spring Boot se conecta a MongoDB.

Flutter no llama a Python ni a MongoDB directamente: toda la comunicación se
hace con los endpoints REST de Spring Boot.

## Funcionalidades

| Módulo | Función |
| --- | --- |
| Autenticación | Registro, inicio de sesión, sesión segura, recuperación y cambio de contraseña. Login con Google y Apple. También se puede explorar la app sin cuenta (modo invitado). |
| Inicio | Selección de origen/destino, promociones y destinos destacados. |
| Vuelos | Búsqueda, filtros, comparación de tarifas, histórico de precios y señales predictivas. |
| Reserva | Selección de tarifa, asientos, equipaje, extras, pasajeros y pago simulado. |
| Mis reservas | Historial y detalle de las reservas del pasajero (requiere cuenta). |
| Favoritos | Destinos y vuelos guardados. |
| Para ti | Perfil de viajero, preferencias y recomendaciones de destinos. |
| Notificaciones | Alertas de ofertas por push (Firebase Cloud Messaging). |
| Privacidad | Consentimiento explícito para la recolección de eventos de comportamiento y para ofertas. |
| Perfil | Datos de la cuenta, cambio de contraseña y acceso a reservas. |

Todas las cuentas usan la misma experiencia de pasajero: no hay roles ni
pantallas administrativas.

## Minería de datos y recomendaciones

1. **Perfil de viajero:** clasifica el historial personal en un arquetipo
   (Recién llegado, Cazador de ofertas, Explorador, Viajero frecuente o
   Viajero premium) con un clustering explicable de **centroide más cercano**
   sobre cantidad de viajes, diversidad de destinos y elección de tarifa
   económica o premium. Se calcula localmente, sin red.
2. **Señales de búsqueda:** probabilidad de ocupación, posible tendencia de
   precio y mejor opción entre los vuelos encontrados.
3. **Recomendaciones:** la app consume `GET /recommendations` (lista
   precalculada por el recomendador del backend) y reenvía el identificador
   de la lista en los eventos y reservas para medir la conversión. Además,
   `lib/features/recommendations/` incluye un motor local explicable que
   puntúa el catálogo de destinos contra el perfil.
4. **Eventos de comportamiento:** solo se envían a `POST /events` si el
   usuario dio su consentimiento (`tracking`).

## Primeros pasos

### Requisitos

- Flutter con Dart ≥ 3.3 (el proyecto se desarrolló con Flutter 3.44.8 /
  Dart 3.12.2).
- Backend Spring Boot + MongoDB en marcha, o el [Mock Server](#mock-server)
  para probar autenticación, catálogo y búsqueda de vuelos.
- Un proyecto de Firebase (para las notificaciones push).

### Configuración local

Estos archivos **no se suben al repositorio** (están en `.gitignore`); cada uno
tiene una plantilla versionada:

| Archivo local | Plantilla | Para qué |
| --- | --- | --- |
| `env.json` | `env.example.json` | URL del backend y credenciales de login social |
| `android/app/google-services.json` | `android/app/google-services.json.example` | Configuración de Firebase en Android |

1. Instala dependencias:

   ```powershell
   flutter pub get
   ```

2. **Firebase (Android):** en la consola de Firebase registra una app Android
   con el paquete `com.stellargear.royalairlines_app`, descarga su
   `google-services.json` y colócalo en `android/app/`. Sin este archivo el
   build de Android falla.

3. **Variables de entorno:** copia la plantilla y edita los valores.

   ```powershell
   Copy-Item env.example.json env.json
   ```

   | Variable | Descripción |
   | --- | --- |
   | `API_BASE_URL` | URL del backend **con** `/api` y sin versión. Si se omite, se usa `http://10.0.2.2:8080/api` en Android y `http://localhost:8080/api` en el resto. |
   | `GOOGLE_WEB_CLIENT_ID` | Client ID de tipo *Web* de Google Cloud Console (audiencia del `idToken` que verifica el backend). |
   | `APPLE_SERVICES_ID` | Services ID de Apple (obligatorio en Android para Apple Sign-In). |
   | `APPLE_REDIRECT_URI` | URI de retorno registrada en Apple Developer. |

   Las variables sin valor se pueden borrar del `env.json`.

### Ejecutar

```powershell
flutter run --dart-define-from-file=env.json
```

Qué URL usar según dónde corra la app (detalle en
[docs/connection-guide.md](docs/connection-guide.md)):

| Escenario | `API_BASE_URL` |
| --- | --- |
| Emulador Android | No hace falta (por defecto `http://10.0.2.2:8080/api`) |
| Escritorio / web en la misma máquina | No hace falta (por defecto `http://localhost:8080/api`) |
| Teléfono físico en la misma WiFi | `http://<IP-local-del-PC>:8080/api` |
| Teléfono físico por USB | `adb reverse tcp:8080 tcp:8080` y `http://localhost:8080/api` |

> **HTTP en desarrollo:** el tráfico sin cifrar (`http://`) solo está permitido
> en los builds *debug* y *profile* de Android. Un build *release* exige
> **HTTPS**.

### Validación

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

> **Builds release:** hoy se firman con la llave de debug, suficiente para la
> demo académica. Antes de publicar en una tienda hay que configurar una firma
> propia (ver `android/app/build.gradle.kts`).

## API REST

Todas las rutas parten de `{API_BASE_URL}/v1`. Las rutas protegidas reciben
`Authorization: Bearer <token>`. La fuente de verdad de las rutas que usa la
app es [`lib/core/network/api_contracts.dart`](lib/core/network/api_contracts.dart).

| Área | Endpoints |
| --- | --- |
| Autenticación | `POST /users/register`, `POST /users/login`, `POST /auth/google`, `POST /auth/apple`, `GET/PUT /users/me`, `POST /auth/change-password`, `POST /auth/forgot-password`, `POST /auth/reset-password` |
| Home | `GET /locations/`, `GET /promotions` |
| Vuelos | `GET /flights/search`, `GET /flights/{flightId}/seats` |
| Reservas | `POST /booking/create`, `GET /booking/my`, `GET /booking/{bookingId}`, `PATCH /booking/confirm`, `PATCH /booking/cancel`, `PATCH /booking/rate` |
| Datos y recomendaciones | `POST /events`, `GET/POST /favorites`, `DELETE /favorites/{targetType}/{targetId}`, `GET /recommendations`, `GET/PUT/DELETE /users/me/preferences`, `GET/PUT /users/me/consent`, `GET /prices/history` |
| Push | `PUT /users/me/devices`, `DELETE /users/me/devices/{token}` |

> `docs/api-contract.md` y el Mock Server describen una versión anterior del
> flujo de reservas (`/bookings`, `/payments/confirm`, `/reservations`). Ante
> cualquier diferencia, manda `api_contracts.dart`.

## Estructura

```text
lib/
  core/         configuración, red (ApiClient y contratos), rutas, tema y utilidades
  features/     módulos: auth, booking, favorites, flights, home, profile,
                recommendations, reservations, traveler_profile
  models/       modelos y conversión JSON
  navigation/   navegación principal
  services/     servicios REST y notificaciones push
  shared/       widgets reutilizables
test/           pruebas de controladores, modelos, servicios y widgets
docs/           contrato de API y guía de conexión
tools/          Mock Server y verificador de integración
```

El flujo de datos es:

```text
screen/widget -> controller -> repository -> service -> ApiClient
```

No se hacen llamadas HTTP directamente desde las pantallas.

## Seguridad y persistencia

- El token de sesión se almacena con `flutter_secure_storage`.
- La sesión expira automáticamente después de siete días.
- Al arrancar, la sesión guardada se refresca con `GET /users/me`; si el
  token venció se cierra la sesión, y si el backend está caído se conserva la
  sesión local.
- Las reservas se guardan localmente por usuario y se conservan al cerrar
  sesión o reiniciar la app (la fuente de verdad es el backend).
- El pago es académico y simulado en el backend: no se almacena número
  completo de tarjeta ni CVV.
- Las credenciales (Google, Apple, URL del backend) se inyectan con
  `--dart-define`; no hay secretos en el código.
- Si el backend no está disponible, cada pantalla que depende de la red
  muestra un mensaje de error y se recupera cuando vuelve a responder.

## Mock Server

`tools/mock-backend.js` es un servidor Node sin dependencias para probar la app
sin Spring Boot. **No es parte de la app** y sus datos (`tools/data/`) son
ficticios. Guía completa en [tools/README.md](tools/README.md).

```powershell
node tools/mock-backend.js        # Terminal 1: levanta el mock en el puerto 8080
flutter run                       # Terminal 2
dart run tools/verify_real_integration.dart   # opcional
```

## Cambios

Ver [CHANGELOG.md](CHANGELOG.md).
