# royal_scraper.py explicado paso a paso

> Proyecto: Royal Airlines · Objetivo: llenar `Destinations` y `Flights` con datos realistas.
> Esta guía sigue el archivo en el mismo orden (secciones 1 a 11 del código).

---

## Conceptos antes de empezar

**Web scraping.** Descargar una página web y sacar de su HTML los datos que te interesan. El HTML es un árbol de etiquetas (`<table>`, `<tr>`, `<td>`, `<a>`…); "scrapear" es recorrer ese árbol buscando lo que necesitas.

**API de MediaWiki.** Wikipedia y Wikivoyage usan el mismo software (MediaWiki), y este trae una API en `https://<sitio>/w/api.php`. Con `action=parse` te devuelve el HTML del artículo dentro de un JSON. Es la forma permitida y recomendada: no cargas la página completa (menús, scripts) y la fundación lo prefiere a que les pidas la página "como navegador".

**BeautifulSoup.** Librería de Python que convierte el HTML en un objeto que puedes recorrer: `soup.find_all("table")` te da todas las tablas, `fila.find_all("td")` las celdas, `celda.get_text()` el texto. `lxml` es el motor que hace la lectura (rápido).

**User-Agent.** Encabezado HTTP donde el cliente dice quién es. Wikimedia exige que los scripts pongan un nombre y una forma de contacto; si no, pueden bloquearte. Por eso `--contacto` es obligatorio.

**Caché.** Guardar en disco lo que ya descargaste para no volver a pedirlo. Es más rápido para ti y más respetuoso con el servidor.

**Rate limiting / pausa.** Esperar entre peticiones (aquí 1 s) para no saturar el sitio. Si el servidor responde 429 ("demasiadas peticiones") o 5xx (error del servidor), el script espera y reintenta.

**IATA.** Código de 3 letras de un aeropuerto (CTG, BOG, JFK). Es lo que une todas las fuentes.

**Haversine.** Fórmula para calcular la distancia entre dos puntos de la Tierra a partir de su latitud y longitud, teniendo en cuenta que es (casi) una esfera.

**ObjectId.** El tipo de `_id` que usa MongoDB por defecto: 12 bytes que se escriben como 24 caracteres hexadecimales. Los primeros 4 bytes son la fecha de creación.

**Extended JSON.** JSON normal no tiene tipos de fecha ni ObjectId. MongoDB usa una convención: `{"$oid": "..."}` para un ObjectId y `{"$date": "2026-11-02T06:30:00Z"}` para una fecha. `mongoimport` la entiende y guarda los tipos correctos.

**Upsert.** "Update o insert": si el documento existe, se actualiza; si no, se crea. El script lo hace a mano para conservar los `_id` que ya existan.

**CC BY-SA 4.0.** Licencia de Wikipedia/Wikivoyage: puedes reutilizar el contenido si das crédito y compartes bajo la misma licencia. Por eso cada destino guarda `sources`.

---

## Encabezado e imports

- La documentación del inicio (docstring) resume fuentes y lo que es estimado. Es lo primero que lee quien abre el archivo.
- `from __future__ import annotations` permite escribir tipos como `list[str] | None` en versiones de Python algo viejas.
- Imports de la librería estándar: `argparse` (opciones de línea de comandos), `csv`, `json`, `hashlib` (nombres de archivo de caché), `math`, `random`, `re` (expresiones regulares), `unicodedata` (quitar tildes), `datetime`, `pathlib.Path` (rutas que funcionan en Windows y Linux), `urllib.parse` (armar y desarmar URLs).
- Imports externos: `requests` (HTTP) y `bs4` (BeautifulSoup).
- `SOURCE_TAG = "royal_scraper"` se escribe en cada documento. Así sabemos cuáles creó el script y podemos borrarlos sin tocar los hechos a mano.
- Las constantes de URL dejan todas las fuentes en un solo lugar.

## 1. Destinos semilla (`Seed`, `DEFAULT_SEEDS`)

El script no adivina qué ciudades quieres: parte de una lista. `Seed` es una `dataclass` (una clase que solo guarda datos; Python le crea el constructor solo).

- `city`: nombre en español, el que verá el usuario.
- `iata`: aeropuerto principal → será `Location.iataCode`.
- `wiki` / `voyage`: título del artículo en Wikipedia y en Wikivoyage, en inglés porque esas versiones tienen las tablas más completas.
- `extra_airports`: otros aeropuertos de la misma ciudad. Si la tabla de Bogotá dice "New York–LaGuardia", igual cuenta como Nueva York.
- `aliases`: nombres alternos con los que aparece la ciudad en las tablas.
- `all_aliases()` arma la lista de alias juntando el título de Wikipedia sin ", Colombia", el de Wikivoyage sin "(Colombia)", el nombre en español y los alias manuales. `dict.fromkeys(...)` quita duplicados conservando el orden.

`DEFAULT_SEEDS` son las 21 ciudades del `TravelDestinationsDataset.arff` del backend (allí "Narino" corresponde a Pasto) más Cartagena y Madrid. `COUNTRY_ES` traduce los códigos de país; si falta uno, se usa el nombre en inglés de OurAirports.

## 2. Cliente HTTP (`Http`, `Wiki`, `yearly_pageviews`)

### `Http.get`
1. Arma una **clave** con la URL y los parámetros ordenados (el orden no debe cambiar la clave).
2. Calcula el SHA-1 de la clave: así el nombre del archivo de caché es corto y válido en cualquier sistema.
3. Si el archivo existe (y no pediste `--refrescar`), devuelve su contenido sin ir a internet.
4. Si estás en `--offline` y no está en caché, lanza `CacheMiss`.
5. Si toca descargar: espera lo que falte para cumplir la pausa, hace la petición y, si recibe 429/500/502/503/504, espera (`Retry-After` si el servidor lo indica, si no 2, 4, 8, 16 s) y reintenta hasta 4 veces. Esa espera creciente se llama *backoff exponencial*.
6. `raise_for_status()` convierte otros errores (404, 403) en excepciones.
7. Guarda la respuesta en caché y la devuelve.

`time.monotonic()` es un reloj que nunca va hacia atrás (a diferencia de la hora del sistema), ideal para medir pausas.

### `Wiki.parse`
Pide `action=parse` con:
- `redirects=1`: si "Bogota" redirige a "Bogotá", la sigue.
- `formatversion=2`: JSON más simple (`data["parse"]["text"]` es directamente el HTML).
- `disableeditsection` / `disabletoc`: quita los enlaces "[editar]" y el índice, que ensuciarían el texto.

Si el artículo no existe (`missingtitle`), usa `search()` (la API `opensearch`, la misma del buscador) y prueba con el primer resultado una sola vez (`search_fallback=False` evita un ciclo infinito). Devuelve `(título_real, html)`.

### `yearly_pageviews`
Pide a la API de Wikimedia las visitas mensuales del artículo de la ciudad en los últimos 12 meses completos y las suma. Es una aproximación de "qué tan popular es el destino". Si falla, devuelve 0 y deja un aviso.

## 3. Utilidades

- `norm()`: deja el texto comparable. `unicodedata.normalize("NFKD", ...)` separa cada letra de su tilde (á → a + ´) y luego se descartan las tildes. Pasa a minúsculas y convierte todos los tipos de guion (–, —, -) en `-` sin espacios. Así "Medellín – JMC" y "medellin-jmc" son iguales.
- `haversine_km()`: la fórmula del haversine con radio terrestre 6371 km. Convierte grados a radianes porque las funciones trigonométricas de Python trabajan en radianes.
- `numbers_in()`: con la expresión regular `-?\d[\d,]*(?:\.\d+)?` saca todos los números de un texto ("1,073.8 (42.28)" → `[1073.8, 42.28]`). Antes cambia el signo menos tipográfico `−` (el que usa Wikipedia) por `-`, si no "−3.2" se leería como 3.2.
- `new_object_id()`: arma un ObjectId válido (8 hex de tiempo + 16 hex aleatorios) sin necesitar pymongo instalado.

## 4. Aeropuertos (`load_airports`)

OurAirports publica un CSV con todos los aeropuertos del mundo. `csv.DictReader` lee cada fila como diccionario (`r["iata_code"]`, `r["latitude_deg"]`…).

- Se descartan filas sin IATA de 3 letras y los aeropuertos cerrados.
- Si un IATA se repite, gana el que tiene `scheduled_service = yes` (vuelos regulares).
- `wiki_title_from_url()` convierte el enlace a Wikipedia en el título del artículo: `.../wiki/El_Dorado_International_Airport` → "El Dorado International Airport". `unquote` decodifica `%C3%BA` → "ú". Solo acepta Wikipedia en inglés.

## 5. Rutas reales (`parse_airline_routes`, `SeedMatcher`, `airline_code`)

Cada artículo de aeropuerto tiene una tabla con dos columnas: **Airlines** y **Destinations**. En la celda de destinos cada ciudad es un enlace, y puede venir la palabra "Seasonal:" antes de las rutas que solo operan en temporada.

`parse_airline_routes`:
1. Borra todos los `<sup>` (las notas [12], [a]) para que no ensucien nombres.
2. Recorre todas las tablas y se queda con las que en la primera fila tienen "airlines" y "destinations".
3. `table.find_previous(["h2","h3","h4"])` busca el título de sección anterior a la tabla; si dice "Cargo", la salta (son vuelos de carga).
4. Por cada fila toma el nombre de la aerolínea y llama a `_destination_links`.

`_destination_links` recorre la celda **en orden** (`cell.descendants`). Cuando encuentra un texto que contiene "seasonal" o "charter", activa la bandera; cada enlace `<a href="/wiki/...">` posterior queda marcado como estacional. Es un *generador* (`yield`): va entregando resultados uno por uno.

`SeedMatcher` decide si un enlace es uno de nuestros destinos:
1. Primero por el **título del artículo** al que apunta el enlace (atributo `title`), comparado con los títulos de OurAirports. Es lo más preciso.
2. Si no, por el **texto** del enlace contra los alias: coincide si es igual ("bogota") o si empieza por el alias seguido de guion ("new york-jfk"). Los alias largos se prueban primero para que "los angeles" no lo atrape un alias más corto.

`airline_code` saca el código de 2 letras para armar el número de vuelo (Avianca → AV). Si la aerolínea no está en la tabla, usa las iniciales.

## 6. Clima (`parse_climate`, `best_months`, `climate_type`, `months_text`)

Los artículos de ciudades tienen una tabla "Climate data for…" con filas por métrica y 12 columnas (una por mes) más el año.

El detalle importante: **cada celda trae dos unidades** y el orden cambia según el país. Cartagena: `Daily mean °C (°F)` → "26.9 (80.4)". Chicago: `Daily mean °F (°C)` → "26.2 (−3.2)". `_pick_metric` mira en qué orden aparecen las unidades en el encabezado de la fila y elige el número correcto. Si solo hay unidades imperiales, convierte (°F → °C: `(F − 32) × 5/9`; pulgadas → mm: `× 25.4`).

- Filas que se leen: temperatura media diaria (o, si no está, el promedio de máxima y mínima) y precipitación en mm. Se ignoran las de "días" de lluvia.
- Si el artículo de la ciudad no tiene la tabla, se prueba el artículo "Climate of …".

`best_months` da a cada mes un puntaje:
- Temperatura (60 %): 1 si está entre 18 y 28 °C; baja de forma lineal cuanto más se aleja.
- Lluvia (40 %): 1 menos la lluvia del mes dividida por la del mes más lluvioso.

Se eligen los meses que quedan a menos de 0,12 del mejor (mínimo 3). Con los datos reales, Cartagena da dic–abr (temporada seca) y Chicago jun–sep (verano). `months_text` lo escribe bonito y entiende que la temporada puede cruzar el año ("dic, ene, feb…").

`climate_type` traduce esa misma tabla al enum `ClimateType` del backend (no se guarda texto libre): usa la elevación del aeropuerto (`HIGHLAND_COLD`), la temperatura media (`TROPICAL_HUMID`/`TROPICAL_DRY`, `SUBTROPICAL`) y el régimen de lluvias (`MEDITERRANEAN`, `OCEANIC`, `CONTINENTAL`, `TEMPERATE`). `months_text` sigue disponible como utilidad, pero el documento ya no guarda `bestDate`.

## 7. Actividades y tags (`TAG_KEYWORDS`, `article_sections`, `tags_from_counts`, `canonical_tags`, `traveler_fit`)

`TAG_KEYWORDS` relaciona cada tag scrapeado (Playa, Buceo, Snorkel, Historia, Museos, Gastronomía…) con una expresión regular de palabras en inglés. `\b` significa "borde de palabra", para que "art" no cuente dentro de "start". Se compilan una sola vez (`_TAG_RE`) porque se usan muchas veces.

`article_sections` divide el artículo por sus títulos `h2`. Funciona con el HTML nuevo de MediaWiki (el `h2` va dentro de `<div class="mw-heading mw-heading2">`) y con el viejo. Solo se cuentan *Understand, See, Do, Buy, Eat, Drink*: "Get in" (cómo llegar) o "Sleep" hablarían de playas o bares que no son la razón de ir.

`tags_from_counts`:
- Ignora tags con menos de 2 menciones (ruido).
- Calcula el peso con logaritmo relativo al tag más mencionado del mismo destino: `log(1+c) / log(1+max)`. El logaritmo evita que un tag con 80 menciones aplaste a uno con 15. Comparar dentro del mismo destino hace que ciudades con artículos cortos (Londres o París reparten el contenido en artículos por barrio) no salgan con pesos bajos en todo.
- Se queda con los 6 mejores con peso ≥ 0,3.

`canonical_tags` traduce esos nombres al **vocabulario controlado del backend** (minúsculas, sin tildes, sin espacios): `Playa → playa`, `Gastronomía → gastronomia`, `Vida Nocturna → vida_nocturna`, `Museos → cultura`, `Buceo/Snorkel/Deportes Acuáticos → deportes`, etc. Si dos tags caen en la misma clave, conserva el peso mayor. Es el formato `{etiqueta: peso 0-1}` que valida `LocationCreationDTO`.

`traveler_fit` NO viene de una página: es una regla sobre los tags canónicos. Para cada tipo de viaje (`familia`, `pareja`, `amigos`, `solo`) hay tags que le encajan con un peso; el resultado va de 0,4 a 1,0.

## 8. Precios y duración (`base_price_usd`, `flight_minutes`, `pick_aircraft`, `sold_seats`)

Tarifa económica aproximada por tramos de distancia (valores razonables, no medidos): Cartagena–Bogotá (~660 km) ≈ 105 USD, Bogotá–Miami ≈ 275 USD, Bogotá–Madrid ≈ 700 USD. Están en dólares porque el recomendador trabaja `ticketPrice` en USD. La duración supone 820 km/h más 35 min de rodaje, despegue y aterrizaje.

`pick_aircraft` elige un avión coherente con el tramo (corto, medio o largo) y `sold_seats` genera `takenSeats` con códigos válidos de `SeatCatalog` (`1A`…`15F`) y su `seatsLeft = 90 − len(takenSeats)`.

## 9. Orquestación (`build_dataset`)

Es la función que une todo:

1. Carga aeropuertos y descarta semillas cuyo IATA no exista.
2. **Rutas:** para cada destino lee la tabla de su aeropuerto, traduce cada enlace a uno de nuestros IATA y guarda `(origen, destino, aerolínea)` en ambos sentidos (las aerolíneas operan ida y vuelta). La expresión `routes.get(key, True) and m.seasonal` hace que una ruta solo quede como estacional si **todas** sus menciones lo son.
3. **Destinos:** arma el documento con los campos de `Location` (schemaVersion 3): nombres, `status`, `rating`, `featured`, `tags`, `travelerFit`, `bestMonths`, `climateType`, `costLevel`, `visaPolicy`, `entryNote`, `ratingCount`, `imageUrl`, `updatedAt`, `cheapestPrice` y `_class`. `costLevel`, `visaPolicy` y `entryNote` salen de `COUNTRY_POLICY` (mismos valores que el catálogo del backend). Conserva `source` y `sources` como metadatos.
4. **Popularidad:** convierte las visitas en `rating` entre 3,8 y 4,8 (escala logarítmica, porque una ciudad como Londres tiene muchísimas más visitas que Montería) y `ratingCount = visitas / 2000`. Los 5 más visitados quedan `featured`.
5. **Vuelos:** por cada ruta decide cuántos días a la semana opera (7 si es corta, 5 o 4 si es larga, 2 si es estacional), en qué días (`rng.sample`) y a qué horas; las rutas cortas regulares tienen 2 vuelos al día. Luego recorre los días de la ventana y crea cada vuelo con los campos de `Flight` (schemaVersion 1): `basePrice` original, `ticketPrice` final (ya con descuento), `discountPercentage`, `aircraft`, `scales`, `durationMinutes`, `availableFareIDs`, `takenSeats`, `seatsLeft`, `offerValidUntil` (solo si hay descuento), `priceUpdatedAt`, `updatedAt` y `_class`. El precio es precio base × un factor aleatorio (0,85–1,25) × 1,15 en temporada alta (mejores meses del destino, diciembre y enero) × 1,05 viernes y domingo. 15 % de los vuelos tienen descuento y 1 % salen cancelados.
6. `cheapestPrice` de cada destino = el `ticketPrice` más bajo que llega allí, con la misma regla que `LocationService.updateAllCheapestPrices` (todos los vuelos, ya descontados).

Todo lo aleatorio usa `rng = random.Random(semilla)`: con la misma semilla salen exactamente los mismos datos, útil para que todo el equipo tenga la misma base.

## 10. Salida (`to_extended_json`, `write_json`, `push_to_mongo`)

- `to_extended_json` convierte `_id` a `{"$oid": …}` y las fechas a `{"$date": …}` con el mismo ajuste de zona horaria que usa Spring (`to_store`).
- `write_json` crea `destinations.json`, `flights.json` y `rutas.csv`, sin añadir campos que no existan en las entidades.
- `push_to_mongo` (solo con `--mongo`):
  - Importa pymongo **dentro** de la función: si no usas `--mongo`, no necesitas tenerlo instalado.
  - Por cada destino busca uno con el mismo `iataCode`. Si existe, actualiza solo `DATA_FIELDS` (no toca nombre ni `_id`) y borra con `$unset` los campos viejos del scraper. Si no existe, lo inserta. Anota en `remap` que el `_id` nuevo debe cambiarse por el viejo.
  - Borra los vuelos anteriores del scraper (`source: royal_scraper`) e inserta los nuevos en lotes de 1000, cambiando antes los IDs de origen/destino con `remap` para que apunten a los destinos que ya existían.
  - Con `--mongo` lee la colección `Fares` para llenar `availableFareIDs`; sin `--mongo` puedes pasarlos con `--tarifas`.

## 11. Línea de comandos (`main`)

`argparse` define las opciones (`--dias`, `--solo`, `--mongo`…) y genera solo el `--help`. `main` configura los logs, valida que haya contacto, filtra las semillas si pediste `--solo`, ejecuta `build_dataset`, escribe los archivos, imprime el resumen y los avisos y, si pediste `--mongo`, escribe en la base. `if __name__ == "__main__":` hace que `main()` solo corra cuando ejecutas el archivo, no cuando otro archivo (como las pruebas) lo importa.

---

## Las pruebas (`test_royal_scraper.py`)

No usan internet. `FakeHttp` reemplaza a `Http` y responde con HTML escrito a mano con la **misma estructura** que las páginas reales (los valores de clima de Cartagena y Chicago son los reales). Se prueba cada pieza por separado y una ejecución completa:

- La tabla de rutas detecta "Seasonal:", quita las notas [3] y salta la tabla de carga.
- El clima funciona con °C primero y con °F primero, y `climate_type` devuelve enums válidos.
- Los tags solo cuentan las secciones útiles y `canonical_tags` los deja en el vocabulario del backend.
- Precios y duraciones están en rangos razonables.
- De punta a punta: rutas de ida y vuelta, IDs consistentes, fechas válidas, campos de `Location`/`Flight` (schemaVersion, enums, asientos, tarifas), JSON en formato de `mongoimport` y que la misma semilla da los mismos vuelos.
