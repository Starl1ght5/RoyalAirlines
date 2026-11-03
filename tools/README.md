# Mock Server de Royal Airlines

Servidor de prueba local que reemplaza temporalmente al backend Spring
Boot durante la integración y las demos. Implementa **exactamente los 18
endpoints** definidos en [`docs/api-contract.md`](../docs/api-contract.md)
y nada más.

> Este mock **no** es Spring Boot, ni MongoDB, ni Python. Es un doble de
> prueba en Node puro para poder desarrollar y presentar Flutter sin
> esperar al backend real. Cuando Spring Boot esté listo, basta con
> apuntar la app a esa URL: la app no cambia.

> **Datos ficticios:** usuarios, contraseñas (p. ej. `Demo2026!`) y vuelos de
> `tools/data/` son solo de demostración y no corresponden a cuentas reales.
>
> **Alcance:** el mock sigue el contrato de `docs/api-contract.md` (autenticación,
> catálogo, búsqueda y el flujo de reservas anterior). No implementa rutas más
> recientes como `/booking/*`, `/favorites`, `/events` o `/recommendations`; ver
> `lib/core/network/api_contracts.dart`.

---

## 1. Requisitos

| Herramienta | Versión usada | Para qué |
| --- | --- | --- |
| **Node.js** | v24.18.0 (cualquier LTS ≥ 18 sirve) | Ejecutar el Mock Server |
| **Flutter / Dart** | Flutter 3.44.8 · Dart 3.12.2 | Correr la app y el verificador |

**No hay que instalar ningún paquete.** El servidor usa solo módulos
nativos de Node (`http`, `fs`, `path`, `crypto`): no existe
`package.json` y **no** hay que ejecutar `npm install`.

---

## 2. Iniciar el Mock Server

Desde la raíz del proyecto:

```powershell
node tools/mock-backend.js
```

Deberías ver:

```text
======================================================
 Royal Airlines - Mock Server
 Escuchando en http://localhost:8080/v1
 Interface: 0.0.0.0 (0.0.0.0 permite el emulador via 10.0.2.2)
 ...
======================================================
```

Cada petición recibida se imprime en la consola:

```text
[14:32:07] POST /v1/auth/login -> 200 (3ms)
[14:32:08] GET /v1/airports -> 200 (1ms)
```

**Esa lista es la evidencia de que Flutter está haciendo HTTP real.**

### Detenerlo

`Ctrl + C` en la misma terminal, o cierra la ventana.

### URL

| Desde dónde | URL |
| --- | --- |
| Terminal del PC / scripts | `http://localhost:8080/v1` |
| **Emulador Android** | `http://10.0.2.2:8080/v1` |
| Teléfono físico (misma WiFi) | `http://<IP-del-PC>:8080/v1` |

Variables opcionales:

```powershell
$env:PORT = "8081"; node tools/mock-backend.js   # otro puerto
```

Comprobación rápida de que está vivo:

```powershell
Invoke-RestMethod http://localhost:8080/health
```

---

## 3. Verificar el contrato con los parsers reales de Flutter

```powershell
dart run tools/verify_real_integration.dart
```

Este script usa los **mismos modelos** con los que Flutter parsea las
respuestas (`AirportModel.fromJson`, `FlightModel.fromJson`,
`ReservationModel.fromJson`, `UserModel.fromJson`). Si termina en `0 FALLO(S)`, la app acepta lo que
devuelve el servidor.

Salidas posibles:

| Código | Significado |
| --- | --- |
| `0` | Todo OK |
| `1` | Hay fallos (el detalle sale por pantalla) |
| `2` | No pudo conectar: el Mock Server no está corriendo |

Opciones:

```powershell
dart run tools/verify_real_integration.dart --base-url=http://localhost:8080/v1
```

---

## 4. Conectar Flutter al Mock Server

La app siempre hace HTTP real (no tiene modo mock interno) y usa
`http://localhost:8080/v1` por defecto, que es exactamente donde
escucha este servidor:

```powershell
# Terminal 1
node tools/mock-backend.js

# Terminal 2
flutter run
```

Para otro destino (solo si hace falta):

```powershell
# Teléfono físico o PC
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080

# Emulador Android
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

> Los tests (`flutter test`) no necesitan servidor: usan un cliente
> HTTP simulado e inyectado (`package:http/testing.dart`).

---

## 5. Cómo comprobar que Flutter hace HTTP de verdad

1. Arranca el Mock Server y borra la consola.
2. Ejecuta `flutter run`.
3. Inicia sesión en la app.
4. Mira la consola del servidor: debe aparecer `POST /v1/auth/login`,
   y al cargar Home `GET /v1/airports`, `GET /v1/promotions` y
   `GET /v1/destinations`.

Señal inequívoca: **la consola del servidor recibe peticiones.** Si no
imprime nada, revisa que el backend (Mock Server o Spring Boot) esté
corriendo en el puerto 8080.

---

## 6. Archivos de datos

`tools/data/*.json` son los **datos del Mock Server**, cargados por
`node` al arrancar:

| Archivo | Alimenta |
| --- | --- |
| `airports.json` | `GET /v1/airports` |
| `promotions.json` | `GET /v1/promotions` |
| `destinations.json` | `GET /v1/destinations` |
| `flights.json` | Plantillas de vuelos y tarifas de `GET /v1/flights/search` |
| `users.json` | Usuarios semilla de `/v1/auth/*` |
| `insights.json` | `GET /v1/insights/community` |
| `reservations.json` | Reservas semilla de `GET /v1/reservations` |

> **No son assets de Flutter.** No están declarados en `pubspec.yaml` y
> la app **nunca** los lee: Flutter solo ve el JSON que llega por HTTP.
> Para cambiar datos visibles en la app en modo real, edita estos
> archivos y reinicia el servidor.

### Cuenta de prueba

```text
email:    demo@royalairlines.com
password: Demo2026!
```

### Estado en memoria

Usuarios registrados, vuelos generados y reservas creadas en runtime
**viven solo mientras dura el proceso**. Al reiniciar el servidor vuelven
los datos de `tools/data/*.json`. No se escribe nada en disco.

---

## 7. Limitaciones conocidas

- **Nivel de tarifa no viaja en el contrato.** `POST /v1/bookings` solo
  envía `fareType` (clase de viaje), no `tierName`. El servidor calcula
  `totalPrice` con la tarifa más económica de esa clase + los `extras`
  (asientos, equipaje, servicios) que envía la app, y ese `totalPrice`
  es el monto autoritativo: el pago (`amount` en
  `POST /v1/payments/confirm`) debe ser igual o el mock lo rechaza.
- **No hay HTTPS ni persistencia** (es un mock de desarrollo).
- Los usuarios se guardan con la contraseña en claro en memoria: solo
  para pruebas locales, nunca exponer esto en un entorno real.
