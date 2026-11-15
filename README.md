# royal_scraper — datos realistas para Royal Airlines

Script que llena las colecciones **`Destinations`** y **`Flights`** de MongoDB con datos sacados de páginas públicas, usando **exactamente los campos de las entidades del backend** (`Location` schemaVersion 3 y `Flight` schemaVersion 1, en `Models/Entities`).

## Qué sale de dónde

| Campo | Fuente | ¿Real o estimado? |
|---|---|---|
| `iataCode`, `airportName`, `countryName`, coordenadas | [OurAirports](https://ourairports.com/data/) (dominio público) | Real |
| Rutas y aerolíneas (`airline`, origen → destino) | Tabla *Airlines / Destinations* del artículo de cada aeropuerto en Wikipedia | Real |
| `bestMonths`, `climateType` | Tabla *Climate data for…* del artículo de la ciudad en Wikipedia | Real (cálculo propio; `climateType` es el enum del backend) |
| `tags` | Secciones *Understand / See / Do / Buy / Eat / Drink* de Wikivoyage | Real (conteo de palabras clave, vocabulario controlado del backend) |
| `rating`, `ratingCount`, `featured` | Visitas del artículo de la ciudad en Wikipedia ([Pageviews API](https://doc.wikimedia.org/generated-data-platform/aqs/analytics-api/)) | Aproximación de popularidad |
| `travelerFit` | Regla fija a partir de los tags | Derivado |
| `costLevel`, `visaPolicy`, `entryNote` | Ficha del país (mismos valores que `scripts/expand_destinations.py`) | Derivado |
| `ticketPrice`, `basePrice`, `discountPercentage`, horarios, `flightNumber`, `aircraft` | Distancia real entre aeropuertos + temporada | **Estimado** |
| `availableFareIDs` | Colección `Fares` (con `--mongo`) o `--tarifas` | Real (IDs de la base) |
| `takenSeats`, `seatsLeft` | Generados con el catálogo de 90 asientos de `SeatCatalog` | Estimado |
| `cheapestPrice` | Vuelo más barato que llega al destino (misma regla que `LocationService`) | Derivado |
| `source`, `sources` | Metadatos del scraper (Spring los ignora) | — |

**¿Por qué no Despegar, Google Flights o Airbnb?** Sus términos prohíben el scraping y bloquean bots (captchas, huella del navegador). Para un proyecto académico es más honesto y estable usar fuentes abiertas y estimar el precio por distancia.

## Instalación y uso

```bash
python -m venv .venv
.venv\Scripts\activate            # Windows  (en Linux/Mac: source .venv/bin/activate)
pip install -r requirements.txt

# 1) Generar los JSON (no toca ninguna base de datos)
python royal_scraper.py --contacto "tu-correo@ejemplo.com"

# 2a) Importarlos con mongoimport ...
mongoimport --uri "%DB_URI%" --db royal_airlines --collection Destinations --jsonArray --file salida/destinations.json
mongoimport --uri "%DB_URI%" --db royal_airlines --collection Flights      --jsonArray --file salida/flights.json

# 2b) ... o escribir directo (usa las mismas variables que Spring)
set DB_URI=mongodb+srv://...
set DB_DATABASE=royal_airlines
python royal_scraper.py --contacto "tu-correo@ejemplo.com" --mongo
```

La primera ejecución tarda unos minutos (hay una pausa de 1 s entre peticiones, como pide Wikimedia). Todo queda en `.cache_scraper/`, así que las siguientes son instantáneas y puedes usar `--offline`.

| Opción | Para qué |
|---|---|
| `--contacto` | Correo o URL que va en el User-Agent (obligatorio, lo exige [la política de Wikimedia](https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_User-Agent_Policy)) |
| `--dias 30` / `--desde 2026-11-15` | Ventana de vuelos a generar |
| `--solo CTG BOG MIA` | Probar con pocos destinos |
| `--destinos mis_destinos.json` | Tu propia lista (mismos campos que `Seed`) |
| `--tarifas ID1,ID2` | IDs de `Fares` para `availableFareIDs` cuando generas solo JSON |
| `--semilla 42` | Misma semilla = mismos vuelos y precios |
| `--refrescar` / `--offline` | Ignorar la caché / usar solo la caché |
| `--mongo` | Escribir en MongoDB en vez de solo generar JSON (lee los IDs de `Fares`) |

Además de los JSON se crea `salida/rutas.csv` con todas las rutas encontradas, útil para revisar.

## Cómo se comporta `--mongo`

- **Destinos:** si ya existe uno con el mismo `iataCode`, conserva su `_id`, nombre, país e `imageUrl`, y actualiza los campos de datos (`tags`, `bestMonths`, `climateType`, `visaPolicy`, `rating`, `cheapestPrice`…). También elimina los campos viejos del scraper (`activities`, `climate`, `bestDate`, `avgTempC`, `avgPrecipMm`, `secret`). Si no existe, lo crea con `schemaVersion: 3` y `_class`.
- **Vuelos:** borra los vuelos que generó el script antes (`source: "royal_scraper"`) e inserta los nuevos (con asientos, tarifas, `basePrice` y `schemaVersion: 1`). Los vuelos creados a mano no se tocan.
- Ojo: si ya hay reservas apuntando a vuelos del scraper, volver a correrlo con `--mongo` deja esas reservas apuntando a vuelos que ya no existen.

## Limitaciones conocidas

- Si generas solo JSON sin `--tarifas`, `availableFareIDs` queda vacío y el front no podrá reservar esos vuelos hasta que importes la colección `Fares` o uses `--mongo`.
- La llegada se calcula sumando la duración a la salida; no se ajusta la zona horaria del destino.
- Solo se lee la tabla del aeropuerto principal de cada ciudad; las rutas de JFK sí aparecen, pero las que solo existen desde LaGuardia o Newark no.
- Un destino sin ninguna ruta real hacia otro destino del catálogo queda con `cheapestPrice = 0` y aparece en los avisos.
- Wikipedia cambia: si una tabla cambia de formato, el aviso lo dirá y habrá que ajustar el parser.


## Licencias

El contenido de Wikipedia y Wikivoyage es **CC BY-SA 4.0**; por eso cada destino guarda en `sources` las URLs de donde salió. Si se muestra en la app, conviene citar "Datos: Wikipedia, Wikivoyage, OurAirports".

## Pruebas

```bash
python -m pytest -q
```

Las pruebas no usan internet: imitan el HTML de las páginas reales.
