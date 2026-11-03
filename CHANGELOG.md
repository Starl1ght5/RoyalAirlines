# Changelog

Los cambios relevantes del proyecto se documentan aquí.

## v1.1.0 — Limpieza y correcciones (2026-10-20)

### Correcciones

- El historial de reservas se sincroniza correctamente al iniciar sesión desde
  modo invitado (antes solo cargaba al arrancar la app).
- Los errores de pago (`PaymentException`, `ApiException`) muestran su mensaje
  real al usuario (antes se reemplazaba por uno genérico).
- Las promociones inactivas (`active: false`) se filtran del slider de Home.
- `GET /flights/search` envía `returnDate` y `passengers` al backend.
- La creación de la reserva envía `birthDate` en formato `yyyy-MM-dd` y
  `extras`.

### Limpieza de código muerto

- Eliminados: `BookingScreen`, `BookingController`, `success_view.dart`,
  `checkout_button.dart`, `ApiContractNotes`, `AppEnvironment`,
  `app_assets.dart`, `payment_service.dart`.
- Eliminados los parámetros `userId` innecesarios en `AuthService`.

### Nuevos módulos

- Recomendaciones de destinos (`lib/features/recommendations/`).
- Preferencias del viajero (`lib/features/traveler_profile/`).
- Login social con Google y Apple Sign-In.
- Mock Server y verificación E2E (`tools/`).

### Documentación

- `docs/api-contract.md` con formatos de fecha, enums, ejemplos JSON y CORS.
- README con endpoints, estructura y guía de conexión.
