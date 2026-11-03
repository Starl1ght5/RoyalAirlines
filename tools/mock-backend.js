#!/usr/bin/env node
/**
 * Royal Airlines - Mock Server
 * ----------------------------
 * Doble de prueba local del backend Spring Boot descrito en
 * `docs/api-contract.md`. Implementa EXACTAMENTE los 18 endpoints del
 * contrato (bajo el prefijo /v1) y nada más.
 *
 * Dependencias: NINGUNA. Solo módulos nativos de Node (http, fs, path,
 * crypto). Se ejecuta con:
 *
 *     node tools/mock-backend.js
 *
 * Variables opcionales:
 *     PORT=8080      Puerto de escucha
 *     HOST=0.0.0.0   Interface de escucha (0.0.0.0 para el emulador)
 *
 * Comportamiento:
 *  - Estado en memoria: los usuarios registrados, los vuelos generados
 *    y las reservas creadas viven mientras dure el proceso. Al
 *    reiniciar vuelve a los datos semilla de tools/data/*.json.
 *  - CORS habilitado (por si se prueba desde web/Postman).
 *  - Cada petición se imprime en consola: esa es la evidencia de que
 *    Flutter está haciendo HTTP de verdad.
 */
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = Number(process.env.PORT || 8080);
const HOST = process.env.HOST || '0.0.0.0';
const API_PREFIX = '/v1';
const DATA_DIR = path.join(__dirname, 'data');

/* ------------------------------------------------------------------ */
/* Datos semilla                                                       */
/* ------------------------------------------------------------------ */

function readJson(name) {
  const file = path.join(DATA_DIR, name);
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    console.error(`No se pudo leer tools/data/${name}: ${error.message}`);
    process.exit(1);
  }
}

const airports = readJson('airports.json');
const promotions = readJson('promotions.json');
const destinations = readJson('destinations.json');
const flightCatalog = readJson('flights.json'); // { templates, fareTiers }
const insights = readJson('insights.json');

/** Estado en memoria (se reconstruye de los JSON en cada arranque). */
const users = readJson('users.json').map((u) => ({ ...u }));
const reservations = readJson('reservations.json').map((r) => ({ ...r }));

const tokens = new Map(); // token -> userId
const flightRegistry = new Map(); // flightId -> flight
const pendingBookings = new Map(); // bookingId -> booking

/** Arranca los contadores por encima de los IDs de la semilla para que
 *  una reserva creada en runtime nunca colisione con un RSV_xxxx
 *  incluido en tools/data/reservations.json. */
function counterAfter(prefix, list) {
  let max = 1000;
  for (const item of list) {
    const match = new RegExp(`^${prefix}_(\\d+)$`).exec(String(item.id || ''));
    if (match) max = Math.max(max, Number(match[1]));
  }
  return max;
}

const counters = {
  booking: 1000,
  reservation: counterAfter('RSV', reservations),
  payment: 1000,
};

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
  });
  res.end(body);
}

function ok(res, data, message = 'Operation completed', status = 200) {
  sendJson(res, status, { success: true, message, data });
}

function fail(res, status, message) {
  sendJson(res, status, { success: false, message, errors: {} });
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw.trim()) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

/** Fecha/hora local SIN sufijo Z: Flutter la parsea como hora local. */
function localIso(date) {
  const p = (n) => String(n).padStart(2, '0');
  return (
    `${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}` +
    `T${p(date.getHours())}:${p(date.getMinutes())}:${p(date.getSeconds())}.000`
  );
}

function normalizeDate(value) {
  const raw = String(value || '').trim();
  const match = /^(\d{4}-\d{2}-\d{2})/.exec(raw);
  if (match) return match[1];
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) return null;
  const p = (n) => String(n).padStart(2, '0');
  return `${parsed.getFullYear()}-${p(parsed.getMonth() + 1)}-${p(parsed.getDate())}`;
}

function publicUser(user) {
  return {
    id: user.id,
    fullName: user.fullName,
    email: user.email,
    avatarUrl: user.avatarUrl == null ? null : user.avatarUrl,
  };
}

/** Quita el campo interno userId antes de responder (no está en el contrato). */
function publicReservation(reservation) {
  const copy = { ...reservation };
  delete copy.userId;
  return copy;
}

function getUserId(req) {
  const header = String(req.headers.authorization || '');
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  if (!match) return null;
  return tokens.get(match[1]) || null;
}

function issueToken(userId) {
  const token = `mock_${crypto.randomBytes(24).toString('hex')}`;
  tokens.set(token, userId);
  return token;
}

/** Decodifica el payload de un JWT sin verificar la firma. */
function decodeJwtPayload(token) {
  const parts = String(token).split('.');
  if (parts.length < 3) return null; // header.payload.signature
  try {
    const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(Buffer.from(payload, 'base64').toString('utf8'));
  } catch (error) {
    return null;
  }
}

function generateConfirmationCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.randomBytes(7);
  let out = '';
  for (let i = 0; i < 7; i++) out += chars[bytes[i] % chars.length];
  return out;
}

function airportByCode(code) {
  const key = String(code || '').toUpperCase();
  return airports.find((a) => a.code === key) || null;
}

function airportOrFallback(code) {
  return (
    airportByCode(code) || {
      code: String(code || '').toUpperCase(),
      city: String(code || '').toUpperCase(),
      country: '',
      airportName: String(code || '').toUpperCase(),
    }
  );
}

/* ------------------------------------------------------------------ */
/* Vuelos                                                              */
/* ------------------------------------------------------------------ */

function buildFares(basePrice) {
  return flightCatalog.fareTiers.map((tier) => ({
    travelClass: tier.travelClass, // "economy" | "premiumEconomy" (nombre del enum)
    tierName: tier.tierName,
    price: Math.round(basePrice * tier.priceMultiplier),
    seatsAvailable: tier.seatsAvailable,
    benefits: [...tier.benefits],
  }));
}

function buildFlight(template, origin, destination, dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  const departure = new Date(y, m - 1, d, template.departureHour, template.departureMinute, 0, 0);
  const durationMs = (template.durationHours * 60 + template.durationMinutes) * 60000;
  const arrival = new Date(departure.getTime() + durationMs);
  const id = `FL_${origin.code}_${destination.code}_${dateStr.replace(/-/g, '')}_${template.index}`;

  const flight = {
    id,
    airline: template.airline,
    flightNumber: template.flightNumber,
    aircraft: template.aircraft,
    origin,
    destination,
    departureTime: localIso(departure),
    arrivalTime: localIso(arrival),
    stops: template.stops,
    fares: buildFares(template.basePrice),
  };
  flightRegistry.set(id, flight);
  return flight;
}

function searchFlights(originCode, destinationCode, dateStr) {
  const origin = airportOrFallback(originCode);
  const destination = airportOrFallback(destinationCode);
  return flightCatalog.templates.map((template) =>
    buildFlight(template, origin, destination, dateStr)
  );
}

/** Recupera un vuelo por id. Si el proceso se reinició (o nunca hubo
 *  búsqueda), lo regenera a partir del propio id, que es autoexplicativo:
 *  FL_<ORIGEN>_<DESTINO>_<AAAAMMDD>_<INDICE>. */
function resolveFlight(flightId) {
  const id = String(flightId || '');
  if (flightRegistry.has(id)) return flightRegistry.get(id);

  const parts = id.split('_');
  if (parts.length !== 5 || parts[0] !== 'FL') return null;

  const [, originCode, destinationCode, compactDate, indexStr] = parts;
  if (!/^\d{8}$/.test(compactDate)) return null;

  const template = flightCatalog.templates.find(
    (t) => String(t.index) === indexStr
  );
  if (!template) return null;

  const dateStr = `${compactDate.slice(0, 4)}-${compactDate.slice(4, 6)}-${compactDate.slice(6, 8)}`;
  return buildFlight(template, airportOrFallback(originCode), airportOrFallback(destinationCode), dateStr);
}

/**
 * El contrato solo envía `fareType` (clase de viaje), no el nivel de
 * tarifa (Basic/Light/Full). Ante esa limitación del contrato este
 * mock elige la tarifa más económica de esa clase. El TOTAL se calcula
 * con esa tarifa × pasajeros + los `extras` (asientos/equipaje/servicios)
 * que la app envía en POST /bookings, y se devuelve como `totalPrice`.
 */
function pickFare(flight, fareType) {
  const key = String(fareType || '').toLowerCase();
  const matching = flight.fares.filter((f) => String(f.travelClass).toLowerCase() === key);
  const pool = matching.length > 0 ? matching : flight.fares;
  return pool.reduce((min, f) => (f.price < min.price ? f : min), pool[0]);
}

/** Forma de `flight` dentro de una reserva: SIEMPRE incluye `fares`
 *  (plural), igual que GET /flights/search. El `fare` (singular) de la
 *  reserva es la tarifa elegida y vive a nivel reserva, no dentro de
 *  flight. */
function reservationFlight(flight) {
  return {
    id: flight.id,
    airline: flight.airline,
    flightNumber: flight.flightNumber,
    aircraft: flight.aircraft,
    origin: flight.origin,
    destination: flight.destination,
    departureTime: flight.departureTime,
    arrivalTime: flight.arrivalTime,
    stops: flight.stops,
    fares: flight.fares,
  };
}

/** Total autoritativo de una reserva: tarifa × pasajeros + extras
 *  (asientos, equipaje y servicios) enviados por la app en
 *  POST /bookings. El mismo total se exige como `amount` en el pago. */
function computeBookingTotal(fare, passengers, extras) {
  let total = fare.price * passengers.length;
  if (extras && typeof extras === 'object') {
    const seats = Array.isArray(extras.selectedSeats) ? extras.selectedSeats : [];
    for (const seat of seats) total += Number(seat && seat.price) || 0;
    if (extras.baggage && typeof extras.baggage === 'object') {
      total += Number(extras.baggage.price) || 0;
    }
    const services = Array.isArray(extras.services) ? extras.services : [];
    for (const service of services) total += Number(service && service.price) || 0;
  }
  return total;
}

/* ------------------------------------------------------------------ */
/* Endpoints                                                           */
/* ------------------------------------------------------------------ */

async function handle(req, res, pathname, searchParams) {
  const route = pathname.slice(API_PREFIX.length) || '/';
  const method = req.method || 'GET';

  /* --- Auth ------------------------------------------------------- */

  if (route === '/auth/register' && method === 'POST') {
    const body = await readBody(req);
    const fullName = String(body.fullName || '').trim();
    const email = String(body.email || '').trim().toLowerCase();
    const password = String(body.password || '');
    if (!fullName || !email || !password) {
      return fail(res, 400, 'fullName, email y password son obligatorios');
    }
    if (users.some((u) => u.email === email)) {
      return fail(res, 409, 'Ese correo ya está registrado');
    }
    const user = {
      id: `usr_${Date.now().toString(36)}`,
      fullName,
      email,
      password,
      avatarUrl: null,
    };
    users.push(user);
    return ok(res, { token: issueToken(user.id), user: publicUser(user) }, 'User created', 201);
  }

  if (route === '/auth/login' && method === 'POST') {
    const body = await readBody(req);
    const email = String(body.email || '').trim().toLowerCase();
    const password = String(body.password || '');
    const user = users.find((u) => u.email === email && u.password === password);
    if (!user) return fail(res, 401, 'Correo o contraseña incorrectos');
    return ok(res, { token: issueToken(user.id), user: publicUser(user) }, 'Login exitoso');
  }

  if (route === '/users/me') {
    const userId = getUserId(req);
    if (!userId) return fail(res, 401, 'Token de sesión ausente o inválido');

    const user = users.find((u) => u.id === userId);
    if (!user) return fail(res, 404, 'Usuario no encontrado');

    if (method === 'GET') return ok(res, { user: publicUser(user) });

    if (method === 'PUT') {
      const body = await readBody(req);
      const fullName = String(body.fullName || user.fullName).trim();
      const email = String(body.email || user.email).trim().toLowerCase();
      const taken = users.some((u) => u.email === email && u.id !== user.id);
      if (taken) return fail(res, 409, 'Ese correo ya está en uso por otra cuenta');
      user.fullName = fullName;
      user.email = email;
      return ok(res, { user: publicUser(user) }, 'Perfil actualizado');
    }

    return fail(res, 405, 'Método no permitido');
  }

  if (route === '/auth/change-password' && method === 'POST') {
    const userId = getUserId(req);
    if (!userId) return fail(res, 401, 'Token de sesión ausente o inválido');
    const body = await readBody(req);
    const user = users.find((u) => u.id === userId);
    if (!user) return fail(res, 404, 'Usuario no encontrado');
    if (user.password == null) {
      return fail(res, 400, 'Tu cuenta usa inicio de sesión con Google/Apple y no tiene contraseña propia');
    }
    if (user.password !== String(body.currentPassword || '')) {
      return fail(res, 400, 'La contraseña actual no es correcta');
    }
    const next = String(body.newPassword || '');
    if (next.length < 8) return fail(res, 400, 'La nueva contraseña debe tener al menos 8 caracteres');
    user.password = next;
    return ok(res, null, 'Contraseña actualizada');
  }

  if (route === '/auth/forgot-password' && method === 'POST') {
    const body = await readBody(req);
    const email = String(body.email || '').trim().toLowerCase();
    if (!email) return fail(res, 400, 'El correo es obligatorio');
    // Siempre responde 200 aunque el correo no exista, para no filtrar
    // qué correos están registrados.
    const user = users.find((u) => u.email === email);
    if (user) {
      const code = String(Math.floor(Math.random() * 1_000_000)).padStart(6, '0');
      user.resetCode = code;
      user.resetExpires = Date.now() + 30 * 60 * 1000;
      console.log(`[mock] Código de recuperación para ${email}: ${code}`);
    }
    return ok(res, null, 'Si el correo existe, recibirás instrucciones');
  }

  if (route === '/auth/reset-password' && method === 'POST') {
    const body = await readBody(req);
    const email = String(body.email || '').trim().toLowerCase();
    const code = String(body.code || '').trim();
    const newPassword = String(body.newPassword || '');
    const user = users.find((u) => u.email === email);
    if (
      !user ||
      user.resetCode !== code ||
      !user.resetExpires ||
      user.resetExpires < Date.now()
    ) {
      return fail(res, 400, 'El código es inválido o ha expirado');
    }
    if (newPassword.length < 8) {
      return fail(res, 400, 'La nueva contraseña debe tener al menos 8 caracteres');
    }
    user.password = newPassword;
    delete user.resetCode;
    delete user.resetExpires;
    return ok(res, null, 'Contraseña actualizada');
  }

  /* --- Catálogo --------------------------------------------------- */

  /* --- Login social ---------------------------------------------- */

  if ((route === '/auth/google' || route === '/auth/apple') && method === 'POST') {
    const provider = route === '/auth/google' ? 'google' : 'apple';
    const body = await readBody(req);
    const identityToken = String(body.identityToken || '').trim();
    if (!identityToken) return fail(res, 400, 'identityToken es obligatorio');

    // El backend REAL (Spring Boot) verifica la firma del JWT con las
    // llaves públicas de Google/Apple; este doble solo decodifica el
    // payload para simular esa verificación en local.
    const claims = decodeJwtPayload(identityToken);
    if (!claims || !claims.sub) {
      return fail(res, 401, `Token de ${provider} inválido`);
    }

    const providerId = String(claims.sub);
    // Fallback de email: se usa el sub completo saneado (no los primeros
    // 10 chars) para que dos tokens distintos no colisionen en el mismo
    // correo y terminen compartiendo cuenta.
    const safeSub = providerId.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 40);
    const email = String(
      claims.email || `${provider}_${safeSub || 'user'}@example.com`
    )
      .trim()
      .toLowerCase();
    const fullName = String(
      body.fullName ||
        claims.name ||
        (provider === 'google' ? 'Usuario Google' : 'Usuario Apple')
    );

    let user =
      users.find((u) => u.provider === provider && u.providerId === providerId) ||
      users.find((u) => u.email === email);

    if (!user) {
      user = {
        // id con aleatorio: Date.now() solo puede repetir si dos
        // usuarios se crean en el mismo milisegundo.
        id: `usr_${Date.now().toString(36)}_${crypto.randomBytes(3).toString('hex')}`,
        fullName,
        email,
        password: null,
        avatarUrl: null,
        provider,
        providerId,
      };
      users.push(user);
    } else if (!user.provider) {
      // Cuenta existente con el mismo correo: se vincula al proveedor.
      user.provider = provider;
      user.providerId = providerId;
    }

    return ok(res, { token: issueToken(user.id), user: publicUser(user) }, 'Login exitoso');
  }

  if (route === '/airports' && method === 'GET') {
    return ok(res, airports);
  }

  if (route === '/promotions' && method === 'GET') {
    return ok(res, promotions);
  }

  if (route === '/destinations' && method === 'GET') {
    return ok(res, destinations);
  }

  /* --- Vuelos ----------------------------------------------------- */

  if (route === '/flights/search' && method === 'GET') {
    const origin = searchParams.get('origin');
    const destination = searchParams.get('destination');
    if (!origin || !destination) {
      return fail(res, 400, 'Los parámetros origin y destination son obligatorios');
    }
    const dateStr = normalizeDate(searchParams.get('departureDate'));
    if (!dateStr) return fail(res, 400, 'El parámetro departureDate no es una fecha válida');
    return ok(res, searchFlights(origin, destination, dateStr));
  }

  if (route.startsWith('/flights/') && method === 'GET') {
    const flightId = decodeURIComponent(route.slice('/flights/'.length));
    const flight = resolveFlight(flightId);
    if (!flight) return fail(res, 404, 'Vuelo no encontrado');
    return ok(res, flight);
  }

  /* --- Reserva y pago --------------------------------------------- */

  if (route === '/bookings' && method === 'POST') {
    const userId = getUserId(req);
    if (!userId) return fail(res, 401, 'Token de sesión ausente o inválido');

    const body = await readBody(req);
    const flight = resolveFlight(body.flightId);
    if (!flight) return fail(res, 404, 'Vuelo no encontrado');

    const passengers = Array.isArray(body.passengers) ? body.passengers : [];
    const seats = Array.isArray(body.seats) ? body.seats : [];
    if (passengers.length === 0) return fail(res, 400, 'La reserva debe incluir al menos un pasajero');
    if (seats.length !== passengers.length) {
      return fail(res, 400, 'La cantidad de asientos debe coincidir con la de pasajeros');
    }

    const fare = pickFare(flight, body.fareType);
    const extras = body.extras && typeof body.extras === 'object' ? body.extras : null;
    const totalPrice = computeBookingTotal(fare, passengers, extras);
    const bookingId = `BK_${++counters.booking}`;
    pendingBookings.set(bookingId, {
      bookingId,
      userId,
      flight,
      fare,
      passengers,
      seats,
      totalPrice,
    });

    return ok(
      res,
      {
        bookingId,
        status: 'pending_payment',
        totalPrice,
      },
      'Booking created',
      201
    );
  }

  if (route === '/payments/confirm' && method === 'POST') {
    const userId = getUserId(req);
    if (!userId) return fail(res, 401, 'Token de sesión ausente o inválido');

    const body = await readBody(req);
    const booking = pendingBookings.get(String(body.bookingId || ''));
    if (!booking) return fail(res, 404, 'Reserva no encontrada o ya pagada');

    const amount = Number(body.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return fail(res, 400, 'El monto del pago no es válido');
    }
    if (
      Number.isFinite(booking.totalPrice) &&
      Math.abs(amount - booking.totalPrice) > 0.5
    ) {
      return fail(
        res,
        400,
        `El amount (${amount}) no coincide con el totalPrice de la reserva (${booking.totalPrice})`
      );
    }

    const lastFour = String(body.cardLastFour || '').replace(/\D/g, '');
    const reservationId = `RSV_${++counters.reservation}`;
    const confirmationCode = generateConfirmationCode();

    reservations.push({
      id: reservationId,
      confirmationCode,
      userId: booking.userId,
      flight: reservationFlight(booking.flight),
      fare: booking.fare,
      seats: booking.seats,
      passengers: booking.passengers,
      payment: {
        cardHolderName: String(body.cardHolderName || ''),
        maskedCardNumber: lastFour
          ? `•••• •••• •••• ${lastFour}`
          : '•••• •••• •••• ••••',
        expiry: String(body.expiry || ''),
      },
      totalPrice: amount,
      bookedAt: localIso(new Date()),
    });

    pendingBookings.delete(booking.bookingId);

    return ok(res, {
      paymentId: `PAY_${++counters.payment}`,
      status: 'approved',
      reservationId,
      confirmationCode,
    });
  }

  /* --- Historial -------------------------------------------------- */

  if (route === '/reservations' && method === 'GET') {
    const userId = getUserId(req);
    if (!userId) return fail(res, 401, 'Token de sesión ausente o inválido');
    const mine = reservations.filter((r) => r.userId === userId);
    return ok(res, mine.map(publicReservation));
  }

  if (route.startsWith('/reservations/') && method === 'GET') {
    const userId = getUserId(req);
    if (!userId) return fail(res, 401, 'Token de sesión ausente o inválido');
    const reservationId = decodeURIComponent(route.slice('/reservations/'.length));
    const found = reservations.find((r) => r.id === reservationId && r.userId === userId);
    if (!found) return fail(res, 404, 'Reserva no encontrada');
    return ok(res, publicReservation(found));
  }

  /* --- Minería de datos (agregado de comunidad) -------------------- */

  if (route === '/insights/community' && method === 'GET') {
    const userId = getUserId(req);
    if (!userId) return fail(res, 401, 'Token de sesión ausente o inválido');
    return ok(res, insights);
  }

  return fail(res, 404, `Ruta no encontrada: ${method} ${route}`);
}

/* ------------------------------------------------------------------ */
/* Servidor                                                            */
/* ------------------------------------------------------------------ */

const server = http.createServer(async (req, res) => {
  const started = Date.now();

  res.on('finish', () => {
    const ms = Date.now() - started;
    const stamp = new Date().toTimeString().slice(0, 8);
    console.log(`[${stamp}] ${req.method} ${req.url} -> ${res.statusCode} (${ms}ms)`);
  });

  let url;
  try {
    url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  } catch (_) {
    return fail(res, 400, 'URL inválida');
  }

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
    });
    return res.end();
  }

  let pathname = url.pathname;
  if (pathname.length > 1 && pathname.endsWith('/')) pathname = pathname.slice(0, -1);

  if (pathname === '/health') {
    return ok(res, { status: 'up', endpoints: 19 }, 'Mock server activo');
  }

  if (!pathname.startsWith(API_PREFIX)) {
    return fail(res, 404, `Ruta no encontrada: ${pathname} (las rutas válidas empiezan con ${API_PREFIX})`);
  }

  try {
    await handle(req, res, pathname, url.searchParams);
  } catch (error) {
    if (!res.headersSent) fail(res, 400, `Error procesando la petición: ${error.message}`);
  }
});

server.listen(PORT, HOST, () => {
  console.log('======================================================');
  console.log(' Royal Airlines - Mock Server');
  console.log(` Escuchando en http://localhost:${PORT}${API_PREFIX}`);
  console.log(` Interface: ${HOST} (0.0.0.0 permite el emulador via 10.0.2.2)`);
  console.log('------------------------------------------------------');
  console.log(' 19 endpoints de docs/api-contract.md:');
  console.log('   POST   /v1/auth/register');
  console.log('   POST   /v1/auth/login');
  console.log('   POST   /v1/auth/google');
  console.log('   POST   /v1/auth/apple');
  console.log('   GET    /v1/users/me');
  console.log('   PUT    /v1/users/me');
  console.log('   POST   /v1/auth/change-password');
  console.log('   POST   /v1/auth/forgot-password');
  console.log('   POST   /v1/auth/reset-password');
  console.log('   GET    /v1/airports');
  console.log('   GET    /v1/promotions');
  console.log('   GET    /v1/destinations');
  console.log('   GET    /v1/flights/search');
  console.log('   GET    /v1/flights/{flightId}');
  console.log('   POST   /v1/bookings');
  console.log('   POST   /v1/payments/confirm');
  console.log('   GET    /v1/reservations');
  console.log('   GET    /v1/reservations/{reservationId}');
  console.log('   GET    /v1/insights/community');
  console.log('------------------------------------------------------');
  console.log(' Cada peticion recibida se imprimira abajo.');
  console.log(' Detener: Ctrl+C');
  console.log('======================================================');
});

server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.error(`El puerto ${PORT} ya esta en uso. Ejecuta: PORT=8081 node tools/mock-backend.js`);
  } else {
    console.error(error);
  }
  process.exit(1);
});
