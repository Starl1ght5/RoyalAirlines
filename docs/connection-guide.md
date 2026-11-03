# Cómo se conecta Flutter con Spring Boot (guía rápida)

Esta guía responde la pregunta clave: **¿a qué URL exacta debe apuntar
Flutter para hablar con el backend?** y da un ejemplo real de una
petición (`/users/login`) para que el compañero de Spring Boot pueda
probar su endpoint ANTES de que Flutter se conecte.

> ✅ **La app no tiene modo mock:** Flutter siempre hace HTTP real al
> backend. Si el backend está apagado, la app muestra mensajes de error
> claros y vuelve a funcionar en cuanto el servidor responda.

## 1. ¿Qué es "localhost" aquí y por qué no siempre funciona tal cual?

Cuando Spring Boot corre en el computador, queda disponible en:

```
http://localhost:8080
```

Esa es la URL por defecto de esta app (ver
[lib/core/config/app_config.dart](../lib/core/config/app_config.dart)),
y funciona cuando Flutter corre en la **misma máquina**:

| Dónde corre Flutter | URL que debe usar | Por qué |
|---|---|---|
| Windows/Linux/macOS (escritorio) | `http://localhost:8080` | Misma máquina, mismo `localhost` ✅ (default) |
| Web (Chrome/Edge en la misma máquina) | `http://localhost:8080` | El navegador comparte red con el PC ✅ (default, pero ver CORS más abajo) |
| Emulador Android (Android Studio) | `http://10.0.2.2:8080` | `10.0.2.2` es la IP que el emulador usa para referirse al PC que lo contiene |
| Teléfono físico (USB o WiFi) | `http://192.168.X.X:8080` (la IP local del PC) | El teléfono es otro dispositivo en la red WiFi |

No hay que editar archivos para cambiar la URL: se pasa al correr la app:

```powershell
# Emulador Android
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# Teléfono físico (reemplaza con la IP de tu PC, obtenida con ipconfig)
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080
```

## 2. ¿Qué puerto debe usar Spring Boot?

Por defecto Spring Boot arranca en el puerto **8080**. Mientras nadie
lo cambie en `application.properties`, la URL completa queda:

```
http://localhost:8080/api/v1/users/login
```

(el prefijo `/api` es del backend y el `/v1` es el de versión que ya usa
Flutter, ver `AppConfig.apiVersion` y `AppConfig.apiBaseUrl`).

## 3. Ejemplo real: probar `/users/login` sin necesitar Flutter todavía

El compañero de Spring Boot puede probar su propio endpoint con este
comando, **sin depender de que Flutter esté corriendo**, para
confirmar que ya está listo antes de avisar al equipo:

```bash
curl -X POST http://localhost:8080/api/v1/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@royalairlines.com","password":"Demo2026!"}'
```

Respuesta esperada (ver contrato completo en
[docs/api-contract.md](api-contract.md)):

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJkZW1vQHJveWFsYWlybGluZXMuY29tIiwiaWQiOiJ1c3JfMDAxIn0.firma"
}
```

Y el catálogo de destinos, que es la ruta que usa el Home:

```bash
curl http://localhost:8080/api/v1/locations/
```

```json
{
  "content": [
    {
      "locationID": "6ad58b1754ba06e9d564c123",
      "cityName": "Madrid",
      "countryName": "España",
      "iataCode": "MAD",
      "airportName": "Aeropuerto Adolfo Suárez Madrid-Barajas"
    }
  ],
  "page": { "size": 10, "number": 0, "totalElements": 1, "totalPages": 1 }
}
```

> La barra final de `/locations/` es obligatoria: sin ella el backend
> responde 404.

Si Spring Boot responde así, Flutter ya puede conectarse a esos mismos
endpoints sin ningún cambio de código.

## 4. MongoDB

MongoDB corre en `localhost:27017` y **solo lo consume Spring Boot**.
Flutter nunca se conecta a la base de datos: toda la persistencia
(usuarios, reservas, vuelos) pasa por la API REST en el puerto 8080.

## 5. Un problema común que hay que anticipar: CORS

Cuando Flutter corre en modo **web** (navegador), este puede bloquear
la petición al backend por política de CORS. Esto NO afecta a app de
escritorio (Windows), emulador Android ni teléfono físico. Si pasa en
web, la solución es en Spring Boot: agregar `@CrossOrigin` (o una
configuración global de CORS) permitiendo el origen desde donde corre
Flutter Web.

## 6. Checklist para la primera prueba real conjunta

1. MongoDB corriendo en `localhost:27017`.
2. Spring Boot corriendo y respondiendo al `curl` del paso 3.
3. Confirmar el puerto real (8080 u otro) y avisar al equipo si cambia.
4. Correr Flutter (`flutter run`) — ya viene configurado para
   `http://localhost:8080`.
5. Probar registro e inicio de sesión desde la app real.
6. Si falla, revisar primero: ¿está bien el puerto?, ¿el firewall de
   Windows está bloqueando el puerto 8080?, ¿el celular/emulador está en
   la misma red WiFi que el computador (solo si aplica)?

## 7. Verificar la integración sin esperar a Spring Boot

Para que el equipo de Flutter valide sus peticiones y parsers antes de
que el backend exista, el repositorio incluye
[`tools/mock-backend.js`](../tools/mock-backend.js): un servidor de
prueba en Node puro que responde EXACTAMENTE como describe
`docs/api-contract.md` para los 18 endpoints (login, google, apple,
flights/search, bookings, payments/confirm, insights/community, etc.).

```powershell
# Terminal 1: levantar el servidor de prueba (puerto 8080)
node tools/mock-backend.js

# Terminal 2: correr la app contra ese servidor
flutter run

# Opcional: validar todos los parsers con peticiones HTTP reales
dart run tools/verify_real_integration.dart
```

Cuando Spring Boot esté listo, se apaga el mock server, se arranca
Spring Boot en el mismo puerto 8080 y la app funciona igual, sin
cambios de código. Guía completa del mock:
[`tools/README.md`](../tools/README.md).
