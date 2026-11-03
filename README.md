# Royal Airlines - Backend

API REST de **Royal Airlines**, una aplicación de reservas de vuelos. Es el servidor al que se conecta la app móvil en **Flutter** y que se integra con un microservicio de recomendaciones en **Python**.

```
┌─────────────┐   HTTPS + JWT    ┌──────────────────┐    ┌──────────┐
│ App Flutter │ ───────────────► │  Backend (este)  │ ─► │ MongoDB  │
└─────────────┘                  │  Spring Boot     │    └──────────┘
                                 └───────┬──────────┘          ▲
                                         │ X-API-Key           │ lectura
                                         ▼                     │
                                 ┌──────────────────┐          │
                                 │ Recomendador     │ ─────────┘
                                 │ Python (CBF)     │
                                 └──────────────────┘
```

## Funcionalidades

- Registro, login con email/contraseña y **login con Google** (flujo móvil con `idToken` y flujo web con redirección).
- Verificación de correo, edición de perfil, cambio y recuperación de contraseña.
- Búsqueda de vuelos, mapa de asientos, reservas (crear, confirmar, valorar, cancelar) con **expiración automática** de reservas pendientes.
- Destinos, destinos destacados/tendencia y promociones.
- Favoritos, preferencias de viaje y consentimiento del usuario.
- Registro de eventos de uso (clics, vistas, etc.), solo si el usuario dio su consentimiento.
- Historial de precios (snapshots diarios).
- **Recomendaciones personalizadas** calculadas por el microservicio Python.
- **Notificaciones push** (Firebase) cuando aparece una oferta que encaja con el usuario.

## Stack

| Capa | Tecnología |
|---|---|
| Lenguaje / framework | Java 21, Spring Boot 4.0.3 |
| Base de datos | MongoDB |
| Seguridad | Spring Security, JWT (jjwt 0.12), BCrypt (coste 12), Google OAuth2 |
| Push | Firebase Admin SDK |
| Dinero | Joda-Money |
| Build | Maven (wrapper incluido) |

## Requisitos

- JDK 21
- MongoDB (local o Atlas)
- Credenciales OAuth de Google Cloud
- *(Opcional)* proyecto de Firebase para push y el microservicio de recomendaciones

## Configuración

Toda la configuración sensible va en variables de entorno. Para desarrollo local:

```bash
cp env.example .env
# edita .env con tus valores
```

La aplicación lee `.env` automáticamente (`spring.config.import`). **El `.env` está en `.gitignore`: nunca lo subas.**

| Variable | Obligatoria | Descripción |
|---|:---:|---|
| `DB_URI` | Sí | URI de conexión a MongoDB |
| `DB_DATABASE` | Sí | Nombre de la base de datos |
| `GOOGLE_OAUTH_CLIENT` | Sí | Client ID de Google |
| `GOOGLE_OAUTH_SECRET` | Sí | Client secret de Google |
| `JWT_SECRET` | Sí | Clave HMAC en **Base64**, mínimo 32 bytes (`openssl rand -base64 48`) |
| `INTERNAL_API_KEY` | No* | Clave compartida con el recomendador. Si está vacía, `/internal/**` responde `503` |
| `RECOMMENDER_URL` | No | URL del servicio Python. Vacía = recálculo en caliente deshabilitado |
| `PUSH_ENABLED` | No | `true` para activar push (por defecto `false`) |
| `FIREBASE_CREDENTIALS_PATH` | Si push | Ruta al JSON de la cuenta de servicio de Firebase |
| `CORS_ALLOWED_ORIGINS` | No | Orígenes permitidos separados por coma (solo clientes web) |
| `FRONTEND_OAUTH_SUCCESS_URL` / `FRONTEND_OAUTH_FAILURE_URL` | No | Redirecciones del login web con Google |
| `PORT` | No | Puerto HTTP (por defecto `8080`) |

\* Obligatoria si usas el microservicio de recomendaciones.

## Ejecutar en local

```bash
./mvnw spring-boot:run          # Linux / macOS
.\mvnw.cmd spring-boot:run      # Windows
```

La API queda en `http://localhost:8080`.

## Tests

```bash
./mvnw test
```

Los tests no necesitan MongoDB, Firebase ni un `.env`: la prueba de arranque define sus propias propiedades.

## Docker

```bash
docker build -t royal-airlines-backend .
docker run --rm -p 8080:8080 --env-file .env royal-airlines-backend
```

La imagen usa un build multi-stage (Maven → JRE 21) y corre como usuario sin privilegios.

## Despliegue en un servicio de hosting

1. Conecta el repositorio (o la imagen Docker) al servicio.
2. Define las variables de entorno de la tabla anterior en el panel del servicio. **No subas el `.env`.**
3. El puerto se toma de `PORT`, que la mayoría de plataformas inyectan solas.
4. Para push, sube el JSON de Firebase como *secret file* de la plataforma y apunta `FIREBASE_CREDENTIALS_PATH` a esa ruta.
5. Si usas el recomendador, despliégalo aparte y configura `RECOMMENDER_URL` e `INTERNAL_API_KEY` (la misma en ambos servicios).
6. En la app Flutter, apunta la URL base de la API al dominio desplegado. Usa **HTTPS**.

> ⚠️ **Ejecuta una sola instancia.** Hay tareas programadas (`@Scheduled`) que correrían duplicadas si el servicio escala a varias réplicas. Además, en planes gratuitos que "duermen" el servicio, estas tareas (como la expiración de reservas) se detienen mientras está inactivo.

## Integración con el microservicio de recomendaciones

El recomendador es un servicio **Python** que usa **filtrado basado en contenido** (*content-based filtering*): compara el perfil/preferencias del usuario con las características de los destinos.

Se comunican en las dos direcciones, siempre con la cabecera `X-API-Key` (valor de `INTERNAL_API_KEY`), nunca con el JWT de usuario:

| Dirección | Endpoint | Para qué |
|---|---|---|
| Python → Backend | `GET /internal/export/{name}` | Leer colecciones de entrenamiento (paginadas con `since`) |
| Python → Backend | `POST /internal/recommendations/bulk` | Guardar las listas calculadas |
| Backend → Python | `POST /recomendaciones/{id}` | Recalcular la lista de un usuario cuando cambia sus preferencias |
| Cliente interno → Backend | `POST /internal/locations/refresh-featured` | Refrescar destinos destacados |
| Cliente interno → Backend | `POST /internal/promotions/refresh` | Refrescar promociones |
| Cliente interno → Backend | `POST /internal/offers/notify/{flightId}` | Disparar notificación de oferta |
| Cliente interno → Backend | `POST /internal/flights/create` | Crear un vuelo u oferta de prueba (ver abajo) |

### Crear vuelos y ofertas de prueba

Se hace con la API key, no con un usuario de la app (con descuento se crea como oferta y se dispara el push):

```bash
curl -X POST "http://localhost:8080/internal/flights/create?airline=Royal&price=250&depID=BOG&arrID=CTG&flightNum=RA101&discountPercentage=30" \
  -H "X-API-Key: $INTERNAL_API_KEY"
```

Cuando el usuario guarda sus preferencias, el backend invalida su lista y llama al recomendador **en segundo plano** (timeout de 10 s). Si Python no responde, la app sigue funcionando con la lista `__popular__` y el job nocturno repara la lista del usuario.

## Autenticación

- **App móvil:** el cliente obtiene un `idToken` de Google y lo envía a `POST /api/v1/auth/google`; la API responde con su propio JWT.
- **Web:** `/oauth2/authorization/google` → el backend redirige al frontend con `#token=...`.
- Después, todas las peticiones protegidas llevan `Authorization: Bearer <jwt>`. Los tokens expiran a los 60 minutos.

## Endpoints principales

Rutas públicas: registro, login, `GET /users/verify`, `auth/google`, recuperación de contraseña, `GET /api/v1/locations`, `GET /api/v1/flights/search`, `GET /api/v1/flights/{id}/seats` y `GET /api/v1/promotions`. El resto exige JWT.

| Recurso | Base |
|---|---|
| Usuarios | `/api/v1/users` (`register`, `login`, `verify`, `me` con `GET` y `PUT`) |
| Autenticación | `/api/v1/auth` (`google`, `change-password`, `forgot-password`, `reset-password`), todo en `AuthController` |
| Vuelos | `/api/v1/flights` (`search`, `{id}/seats`) |
| Reservas | `/api/v1/booking` (`create`, `my`, `{id}`, `confirm`, `rate`, `cancel`) |
| Destinos | `/api/v1/locations` |
| Promociones | `/api/v1/promotions` |
| Recomendaciones | `/api/v1/recommendations` |
| Favoritos | `/api/v1/favorites` |
| Precios | `/api/v1/prices/history` |
| Eventos de usuario | `/api/v1/events` |
| Preferencias | `/api/v1/users/me/preferences` |
| Consentimiento | `/api/v1/users/me/consent` |
| Dispositivos (push) | `/api/v1/users/me/devices` |

## Tareas programadas

Zona horaria `America/Bogota`.

| Tarea | Frecuencia |
|---|---|
| Expirar reservas pendientes | Cada minuto |
| Recalcular precio mínimo por destino | Cada 10 minutos |
| Barrido de respaldo de notificaciones de oferta | Cada 10 minutos |
| Snapshot de precios | Diario, 03:30 |
| Refresco de destinos destacados/tendencia | Diario, 03:45 |
| Refresco de promociones | Diario, 03:55 |

Los cron son configurables con `royal.prices.snapshot-cron`, `royal.trending.refresh-cron`, `royal.promotions.refresh-cron` y `royal.push.backup-cron`.

## Estructura

```
src/main/java/com/stellargear/royal_airlines/
├── Config/         Seguridad, JWT, CORS, API key interna, Firebase, async
├── Controllers/    Endpoints REST
├── Models/         DTOs, entidades, enums, eventos y validaciones (Validation/)
├── Repositories/   Acceso a MongoDB
├── Services/       Lógica de negocio
└── Utils/          Excepciones, manejo de errores, conversión de moneda, catálogo de asientos
src/main/resources/
├── application.properties
└── TravelDestinationsDataset.arff   Dataset de destinos
```

## Convenciones del código

- **Errores HTTP:** usa `BadRequestException` (400), `NotFoundException` (404) y `ConflictException` (409) de `Utils/`; las tres extienden `ResponseStatusException` y `GlobalExceptionHandler` las convierte en `ProblemDetail`. El único código sin clase corta es el 401, que se lanza con `ResponseStatusException`.
- **Validación de entrada:** el correo se valida con `@ValidEmail` (obligatorio, formato válido, máximo 254 caracteres) y la longitud de la contraseña con `@ValidPassword` (8 a 72, el límite de BCrypt). Cada solicitud conserva su propio `@NotBlank` para que el mensaje de "obligatorio" sea el que espera la app.
- **Contrato con el recomendador:** `RecommendationItem` es el mismo tipo en el documento que escribe Python, en la colección `UserRecommendations` y en la respuesta al cliente. Sus nombres de campo, y el `_id` de `UserRecommendationDocDTO`, son el contrato con `recommender/batch.py`: si cambian aquí, hay que cambiarlos allá a la vez.
- **Controladores delgados:** la lógica (por ejemplo, la del consentimiento) vive en los servicios; el controlador solo recibe, delega y responde.

## Seguridad

- Contraseñas con BCrypt (coste 12) y sesiones sin estado (JWT).
- Rutas `/internal/**` protegidas por API key con comparación en tiempo constante; fallan cerradas si no hay clave configurada.
- Ningún secreto vive en el repositorio: todo entra por variables de entorno.
- Las utilidades de operación (como crear vuelos de prueba) viven bajo `/internal/**`, protegidas por API key; ningún usuario de la app puede llamarlas.