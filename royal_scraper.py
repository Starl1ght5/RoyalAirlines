#!/usr/bin/env python3
"""
royal_scraper.py — Datos realistas para Royal Airlines.

Genera las colecciones `Destinations` y `Flights` con el mismo esquema que usan
el backend (Spring + MongoDB) y el recomendador de la rama Python, a partir de
fuentes públicas:

  * OurAirports (dominio público) ......... aeropuertos: nombre, IATA, coordenadas
  * Wikipedia (CC BY-SA 4.0) ............... rutas reales: tabla "Airlines / Destinations"
                                            de cada aeropuerto + tabla de clima de cada ciudad
  * Wikivoyage (CC BY-SA 4.0) .............. qué se hace en cada ciudad -> tags
  * Wikimedia Pageviews (CC0) .............. popularidad -> rating / ratingCount / featured

Lo que NO sale de una página (y por qué):
  * ticketPrice: Despegar, Google Flights, etc. prohíben el scraping en sus términos y
    bloquean bots, así que el precio se ESTIMA con la distancia real entre aeropuertos.
  * travelerFit: se deriva de los tags con una regla fija (ver TRAVELER_FIT_RULES).
  * climateType, costLevel, visaPolicy y entryNote: se derivan del clima real y de la
    ficha del país; son los enums que valida el backend.
  * Horarios y números de vuelo: se generan; las rutas y aerolíneas sí son reales.

Los documentos salen con los campos exactos de las entidades del backend
(`Location` schemaVersion 3 y `Flight` schemaVersion 1), salvo `source`/`sources`,
que se conservan como metadatos del scraper (Spring los ignora).

Uso rápido:
    pip install -r requirements.txt
    python royal_scraper.py --contacto "tu-correo@ejemplo.com"
    # -> salida/destinations.json y salida/flights.json (listos para mongoimport)

    python royal_scraper.py --contacto "..." --mongo   # escribe directo en MongoDB (DB_URI / DB_DATABASE)
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import logging
import math
import os
import random
import re
import sys
import time
import unicodedata
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import quote, unquote, urlencode, urlparse

import requests
from bs4 import BeautifulSoup, NavigableString, Tag

log = logging.getLogger("royal_scraper")

SOURCE_TAG = "royal_scraper"  # se guarda en cada documento para poder borrarlos o re-generarlos

# Entidades del backend: Spring Data necesita `_class` para reconstruir el documento.
LOCATION_CLASS = "com.stellargear.royal_airlines.Models.Entities.Location"
FLIGHT_CLASS = "com.stellargear.royal_airlines.Models.Entities.Flight"
LOCATION_SCHEMA_VERSION = 3
FLIGHT_SCHEMA_VERSION = 1
CAPACITY = 90  # SeatCatalog: 15 filas x 6 columnas

# Spring guarda LocalDateTime como instante UTC en la zona del sistema. Estas dos
# funciones hacen el mismo ajuste que scripts/seed_flights.py del backend.
LOCAL_OFFSET = datetime.now().astimezone().utcoffset()

AIRPORTS_CSV = "https://davidmegginson.github.io/ourairports-data/airports.csv"
COUNTRIES_CSV = "https://davidmegginson.github.io/ourairports-data/countries.csv"
WIKIPEDIA = "en.wikipedia.org"
WIKIVOYAGE = "en.wikivoyage.org"
PAGEVIEWS = "https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article"


# ---------------------------------------------------------------------------
# 1. Destinos semilla
# ---------------------------------------------------------------------------
@dataclass
class Seed:
    """Un destino que queremos en el catálogo.

    city   -> nombre que muestra la app (en español)
    iata   -> aeropuerto principal (Location.iataCode)
    wiki   -> título del artículo de la ciudad en en.wikipedia (para el clima)
    voyage -> título del artículo en en.wikivoyage (para las actividades)
    extra_airports -> otros aeropuertos de la misma ciudad (JFK/LGA/EWR son "Nueva York")
    aliases -> cómo aparece la ciudad en las tablas de destinos ("New York–JFK" empieza por "New York")
    """
    city: str
    iata: str
    wiki: str
    voyage: str
    extra_airports: list[str] = field(default_factory=list)
    aliases: list[str] = field(default_factory=list)

    def all_codes(self) -> list[str]:
        return [self.iata, *self.extra_airports]

    def all_aliases(self) -> list[str]:
        base = [self.wiki.split(",")[0], self.voyage.split(" (")[0], self.city]
        return [a for a in dict.fromkeys(base + self.aliases) if a]


# Las 21 ciudades del dataset TravelDestinationsDataset.arff del backend
# ('Narino' es Pasto) + Cartagena y Madrid.
DEFAULT_SEEDS: list[Seed] = [
    Seed("Bogotá", "BOG", "Bogotá", "Bogotá"),
    Seed("Medellín", "MDE", "Medellín", "Medellín", ["EOH"]),
    Seed("Cali", "CLO", "Cali", "Cali"),
    Seed("Barranquilla", "BAQ", "Barranquilla", "Barranquilla"),
    Seed("Cartagena", "CTG", "Cartagena, Colombia", "Cartagena (Colombia)", aliases=["Cartagena"]),
    Seed("Bucaramanga", "BGA", "Bucaramanga", "Bucaramanga"),
    Seed("Pereira", "PEI", "Pereira, Colombia", "Pereira"),
    Seed("Armenia", "AXM", "Armenia, Colombia", "Armenia (Colombia)", aliases=["Armenia"]),
    Seed("Montería", "MTR", "Montería", "Montería"),
    Seed("Pasto", "PSO", "Pasto, Colombia", "Pasto"),
    Seed("Nueva York", "JFK", "New York City", "New York City", ["LGA", "EWR"], ["New York"]),
    Seed("Chicago", "ORD", "Chicago", "Chicago", ["MDW"]),
    Seed("Miami", "MIA", "Miami", "Miami"),
    Seed("Los Ángeles", "LAX", "Los Angeles", "Los Angeles"),
    Seed("Londres", "LHR", "London", "London", ["LGW", "STN", "LCY", "LTN"]),
    Seed("Manchester", "MAN", "Manchester", "Manchester"),
    Seed("Edimburgo", "EDI", "Edinburgh", "Edinburgh"),
    Seed("Cancún", "CUN", "Cancún", "Cancún"),
    Seed("Ottawa", "YOW", "Ottawa", "Ottawa"),
    Seed("París", "CDG", "Paris", "Paris", ["ORY"]),
    Seed("Roma", "FCO", "Rome", "Rome", ["CIA"]),
    Seed("Sídney", "SYD", "Sydney", "Sydney"),
    Seed("Madrid", "MAD", "Madrid", "Madrid"),
]

COUNTRY_ES = {
    "CO": "Colombia", "US": "Estados Unidos", "GB": "Reino Unido", "MX": "México",
    "CA": "Canadá", "FR": "Francia", "IT": "Italia", "AU": "Australia", "ES": "España",
    "PA": "Panamá", "PE": "Perú", "EC": "Ecuador", "BR": "Brasil", "AR": "Argentina",
    "CL": "Chile", "DE": "Alemania", "NL": "Países Bajos", "PT": "Portugal", "DO": "República Dominicana",
    "CR": "Costa Rica", "SV": "El Salvador", "GT": "Guatemala", "CU": "Cuba", "PR": "Puerto Rico",
    "VE": "Venezuela", "CH": "Suiza", "AT": "Austria", "DK": "Dinamarca", "IE": "Irlanda",
    "TR": "Turquía", "AE": "Emiratos Árabes Unidos", "JP": "Japón", "KR": "Corea del Sur",
}

# Textos de entryNote que usa el backend (scripts/expand_destinations.py).
ENTRY_NOTES = {
    "ue": "Sin visa para estancias cortas; ETIAS pendiente de entrada en vigor.",
    "eeuu": "Visa B1/B2 obligatoria para pasaporte colombiano; no aplica ESTA.",
    "canada": "Visa de visitante obligatoria para pasaporte colombiano; la eTA solo aplica con visa vigente.",
    "irlanda": "Visa de visitante obligatoria; Irlanda no forma parte del espacio Schengen.",
    "cuba": "Tarjeta de turista obligatoria junto con seguro médico de viaje.",
    "turquia": "e-Visa obligatoria; se solicita en línea antes del viaje.",
    "emiratos": "e-Visa obligatoria para pasaporte colombiano; se solicita en línea.",
    "japon": "Visa de turista obligatoria para pasaporte colombiano; se tramita en el consulado.",
    "corea": "Visa de turista obligatoria para pasaporte colombiano; se tramita en el consulado.",
    "reino": "Visa de visitante obligatoria para pasaporte colombiano; se tramita en línea o en el consulado.",
    "australia": "Visa de visitante (subclase 600) obligatoria para pasaporte colombiano; se solicita en línea.",
}

# (costLevel, visaPolicy, clave de ENTRY_NOTES) por país ISO, para pasaporte colombiano.
# Sigue los valores que ya usa el catálogo del backend (expand_destinations.py).
COUNTRY_POLICY: dict[str, tuple[int, str, str | None]] = {
    "CO": (1, "NOT_APPLICABLE", None),
    # Latinoamérica y Caribe: entrada sin visa para turismo corto.
    "MX": (2, "NOT_APPLICABLE", None), "PA": (3, "NOT_APPLICABLE", None),
    "CR": (2, "NOT_APPLICABLE", None), "SV": (1, "NOT_APPLICABLE", None),
    "GT": (1, "NOT_APPLICABLE", None), "PR": (3, "VISA_REQUIRED", "eeuu"),
    "DO": (3, "NOT_APPLICABLE", None), "EC": (1, "NOT_APPLICABLE", None),
    "PE": (2, "NOT_APPLICABLE", None), "AR": (2, "NOT_APPLICABLE", None),
    "CL": (3, "NOT_APPLICABLE", None), "BR": (2, "NOT_APPLICABLE", None),
    "VE": (1, "NOT_APPLICABLE", None), "CU": (2, "ELECTRONIC_AUTH", "cuba"),
    # Norteamérica.
    "US": (3, "VISA_REQUIRED", "eeuu"), "CA": (3, "VISA_REQUIRED", "canada"),
    # Europa: Schengen sin visa, con ETIAS pendiente.
    "ES": (3, "NOT_REQUIRED", "ue"), "FR": (3, "NOT_REQUIRED", "ue"),
    "IT": (3, "NOT_REQUIRED", "ue"), "DE": (3, "NOT_REQUIRED", "ue"),
    "NL": (4, "NOT_REQUIRED", "ue"), "PT": (3, "NOT_REQUIRED", "ue"),
    "CH": (4, "NOT_REQUIRED", "ue"), "AT": (3, "NOT_REQUIRED", "ue"),
    "DK": (4, "NOT_REQUIRED", "ue"), "IE": (3, "VISA_REQUIRED", "irlanda"),
    "GB": (3, "VISA_REQUIRED", "reino"),
    # Resto del catálogo.
    "TR": (2, "ELECTRONIC_AUTH", "turquia"), "AE": (4, "ELECTRONIC_AUTH", "emiratos"),
    "JP": (4, "VISA_REQUIRED", "japon"), "KR": (3, "VISA_REQUIRED", "corea"),
    "AU": (3, "VISA_REQUIRED", "australia"),
}
DEFAULT_COUNTRY_POLICY = (2, "NOT_REQUIRED", None)

MONTHS_ES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]


# ---------------------------------------------------------------------------
# 2. Cliente HTTP educado: caché en disco, pausa entre peticiones y reintentos
# ---------------------------------------------------------------------------
class CacheMiss(RuntimeError):
    """Se pidió una URL en modo --offline y no estaba en la caché."""


class Http:
    def __init__(self, cache_dir: Path, contact: str, delay: float = 1.0,
                 refresh: bool = False, offline: bool = False):
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.delay = delay
        self.refresh = refresh
        self.offline = offline
        self._last = 0.0
        self.session = requests.Session()
        # Wikimedia exige un User-Agent que identifique el script y una forma de contacto.
        self.session.headers["User-Agent"] = (
            f"RoyalAirlinesScraper/1.0 (proyecto academico universitario; {contact}) "
            f"python-requests/{requests.__version__}"
        )

    def get(self, url: str, params: dict | None = None) -> str:
        key = url + ("?" + urlencode(sorted(params.items())) if params else "")
        path = self.cache_dir / (hashlib.sha1(key.encode()).hexdigest() + ".txt")
        if path.exists() and not self.refresh:
            return path.read_text(encoding="utf-8")
        if self.offline:
            raise CacheMiss(key)

        for attempt in range(4):
            wait = self.delay - (time.monotonic() - self._last)
            if wait > 0:
                time.sleep(wait)
            self._last = time.monotonic()
            log.debug("GET %s", key)
            resp = self.session.get(url, params=params, timeout=40)
            if resp.status_code in (429, 500, 502, 503, 504):
                pause = float(resp.headers.get("Retry-After") or 2 ** (attempt + 1))
                log.warning("HTTP %s en %s; reintento en %.0fs", resp.status_code, url, pause)
                time.sleep(pause)
                continue
            resp.raise_for_status()
            resp.encoding = "utf-8"
            path.write_text(resp.text, encoding="utf-8")
            return resp.text
        raise RuntimeError(f"No se pudo descargar {key} tras varios intentos")


class Wiki:
    """Acceso a un sitio MediaWiki (Wikipedia o Wikivoyage) mediante su API oficial."""

    def __init__(self, http: Http, host: str):
        self.http = http
        self.host = host
        self.api = f"https://{host}/w/api.php"

    def parse(self, title: str, search_fallback: bool = True) -> tuple[str, str] | None:
        """Devuelve (título_real, html) del artículo, siguiendo redirecciones."""
        raw = self.http.get(self.api, {
            "action": "parse", "page": title, "prop": "text", "redirects": 1,
            "format": "json", "formatversion": 2,
            "disableeditsection": 1, "disabletoc": 1,
        })
        data = json.loads(raw)
        if "error" in data:
            if search_fallback and data["error"].get("code") == "missingtitle":
                alt = self.search(title)
                if alt and alt != title:
                    log.info("[%s] '%s' no existe; uso '%s'", self.host, title, alt)
                    return self.parse(alt, search_fallback=False)
            log.warning("[%s] no se pudo leer '%s': %s", self.host, title, data["error"].get("info"))
            return None
        return data["parse"]["title"], data["parse"]["text"]

    def search(self, query: str) -> str | None:
        raw = self.http.get(self.api, {"action": "opensearch", "search": query,
                                       "limit": 1, "namespace": 0, "format": "json"})
        titles = json.loads(raw)[1]
        return titles[0] if titles else None

    def page_url(self, title: str) -> str:
        return f"https://{self.host}/wiki/{quote(title.replace(' ', '_'))}"


def yearly_pageviews(http: Http, title: str, today: date) -> int:
    """Visitas del artículo en Wikipedia durante los últimos 12 meses completos."""
    end = today.replace(day=1) - timedelta(days=1)                 # último día del mes pasado
    start = (end.replace(day=1) - timedelta(days=330)).replace(day=1)
    article = quote(title.replace(" ", "_"), safe="")
    url = (f"{PAGEVIEWS}/en.wikipedia/all-access/user/{article}/monthly/"
           f"{start:%Y%m%d}00/{end:%Y%m%d}00")
    try:
        items = json.loads(http.get(url)).get("items", [])
    except (requests.HTTPError, CacheMiss, json.JSONDecodeError) as exc:
        log.warning("Sin pageviews para %s (%s)", title, exc)
        return 0
    return sum(int(i.get("views", 0)) for i in items)


# ---------------------------------------------------------------------------
# 3. Utilidades de texto y geografía
# ---------------------------------------------------------------------------
def norm(text: str) -> str:
    """Minúsculas, sin tildes, guiones unificados: 'Medellín – JMC' -> 'medellin-jmc'."""
    text = unicodedata.normalize("NFKD", text or "")
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.lower().replace("_", " ")
    text = re.sub(r"\s*[‐‑‒–—-]\s*", "-", text)
    return re.sub(r"\s+", " ", text).strip()


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distancia en km sobre la superficie de la Tierra (fórmula del haversine)."""
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


_NUM = re.compile(r"-?\d[\d,]*(?:\.\d+)?")


def numbers_in(text: str) -> list[float]:
    """Todos los números de un texto ('−3.2 (26.2)' -> [-3.2, 26.2]); maneja el signo − Unicode."""
    text = text.replace("−", "-").replace("–", "-")
    return [float(n.replace(",", "")) for n in _NUM.findall(text)]


def new_object_id() -> str:
    """ObjectId de MongoDB (24 hex) sin depender de pymongo: 4 bytes de tiempo + 8 aleatorios."""
    return f"{int(time.time()):08x}" + os.urandom(8).hex()


def to_store(local_wall: datetime) -> datetime:
    """Convierte una fecha-hora local (la que verá el API) al instante que guarda Spring."""
    return local_wall - LOCAL_OFFSET


def country_policy(iso: str) -> tuple[int, str, str | None]:
    """(costLevel, visaPolicy, entryNote) para un país ISO; coherente con el catálogo del backend."""
    cost, visa, note_key = COUNTRY_POLICY.get((iso or "").upper(), DEFAULT_COUNTRY_POLICY)
    return cost, visa, ENTRY_NOTES.get(note_key) if note_key else None


# ---------------------------------------------------------------------------
# 4. Aeropuertos (OurAirports)
# ---------------------------------------------------------------------------
def wiki_title_from_url(url: str) -> str | None:
    parsed = urlparse(url or "")
    if not parsed.netloc.startswith("en.") or "/wiki/" not in parsed.path:
        return None
    return unquote(parsed.path.split("/wiki/", 1)[1]).replace("_", " ")


def load_airports(http: Http) -> dict[str, dict]:
    """{IATA: {name, lat, lon, elevation_m, country, iso, wiki_title}} de aeropuertos con código IATA."""
    countries = {r["code"]: r["name"] for r in csv.DictReader(io.StringIO(http.get(COUNTRIES_CSV)))}
    out: dict[str, dict] = {}
    for r in csv.DictReader(io.StringIO(http.get(AIRPORTS_CSV))):
        code = (r.get("iata_code") or "").strip().upper()
        if len(code) != 3 or r.get("type") == "closed":
            continue
        scheduled = r.get("scheduled_service") == "yes"
        if code in out and out[code]["scheduled"] and not scheduled:
            continue  # si un IATA aparece dos veces, gana el que tiene vuelos regulares
        iso = r.get("iso_country", "")
        try:
            elevation_m = float(r.get("elevation_ft") or 0) * 0.3048
        except ValueError:
            elevation_m = 0.0
        out[code] = {
            "name": r["name"],
            "lat": float(r["latitude_deg"]),
            "lon": float(r["longitude_deg"]),
            "elevation_m": elevation_m,
            "iso": iso,
            "country": COUNTRY_ES.get(iso, countries.get(iso, iso)),
            "wiki_title": wiki_title_from_url(r.get("wikipedia_link", "")),
            "scheduled": scheduled,
        }
    log.info("OurAirports: %d aeropuertos con código IATA", len(out))
    return out


# ---------------------------------------------------------------------------
# 5. Rutas reales: tabla "Airlines | Destinations" del artículo del aeropuerto
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class RouteMention:
    airline: str
    text: str      # texto del enlace, p. ej. "New York–JFK"
    title: str     # artículo al que apunta el enlace, p. ej. "John F. Kennedy International Airport"
    seasonal: bool


def _clean_airline(name: str) -> str:
    name = re.sub(r"\[[^\]]*\]", "", name)          # quita marcas tipo [12]
    return re.sub(r"\s+", " ", name).strip(" ,;")


def _destination_links(cell: Tag):
    """Recorre la celda en orden; todo lo que viene después de 'Seasonal:' o 'Charter:' es estacional."""
    seasonal = False
    for node in cell.descendants:
        if isinstance(node, NavigableString):
            low = node.lower()
            if "seasonal" in low or "charter" in low:
                seasonal = True
        elif isinstance(node, Tag) and node.name == "a" and node.get("href", "").startswith("/wiki/"):
            yield node.get_text(" ", strip=True), node.get("title", ""), seasonal


def parse_airline_routes(html: str) -> list[RouteMention]:
    soup = BeautifulSoup(html, "lxml")
    for sup in soup.find_all("sup"):                  # notas al pie [1], [a]...
        sup.decompose()
    mentions: list[RouteMention] = []
    for table in soup.find_all("table"):
        header_row = table.find("tr")
        if not header_row:
            continue
        headers = [norm(th.get_text(" ", strip=True)) for th in header_row.find_all(["th", "td"])]
        if "airlines" not in headers or "destinations" not in headers:
            continue
        heading = table.find_previous(["h2", "h3", "h4"])
        if heading and "cargo" in heading.get_text().lower():
            continue                                  # vuelos de carga: no nos sirven
        i_air, i_dest = headers.index("airlines"), headers.index("destinations")
        for tr in table.find_all("tr")[1:]:
            cells = tr.find_all(["td", "th"])
            if len(cells) <= max(i_air, i_dest):
                continue
            airline = _clean_airline(cells[i_air].get_text(" ", strip=True))
            if not airline:
                continue
            for text, title, seasonal in _destination_links(cells[i_dest]):
                mentions.append(RouteMention(airline, text, title, seasonal))
    return mentions


class SeedMatcher:
    """Traduce un enlace de la tabla de destinos al IATA principal de uno de nuestros destinos."""

    def __init__(self, seeds: list[Seed], airports: dict[str, dict]):
        self.by_title: dict[str, str] = {}
        self.by_alias: dict[str, str] = {}
        for s in seeds:
            for code in s.all_codes():
                title = airports.get(code, {}).get("wiki_title")
                if title:
                    self.by_title[norm(title)] = s.iata
            for alias in s.all_aliases():
                self.by_alias[norm(alias)] = s.iata
        # alias largos primero: "los angeles" antes que "los"
        self._aliases = sorted(self.by_alias.items(), key=lambda kv: -len(kv[0]))

    def match(self, text: str, title: str) -> str | None:
        if title and norm(title) in self.by_title:
            return self.by_title[norm(title)]
        t = norm(text)
        for alias, code in self._aliases:
            if t == alias or t.startswith(alias + "-"):
                return code
        return None


AIRLINE_CODES = {
    "avianca": "AV", "latam": "LA", "wingo": "P5", "jetsmart": "JA", "copa": "CM",
    "american airlines": "AA", "united airlines": "UA", "delta": "DL", "jetblue": "B6",
    "spirit": "NK", "iberia": "IB", "air europa": "UX", "air france": "AF", "klm": "KL",
    "lufthansa": "LH", "british airways": "BA", "aeromexico": "AM", "volaris": "Y4",
    "viva aerobus": "VB", "air canada": "AC", "satena": "9R", "clic": "VE", "easyfly": "VE",
    "arajet": "DM", "qantas": "QF", "ita airways": "AZ", "easyjet": "U2", "ryanair": "FR",
    "alaska": "AS", "southwest": "WN", "frontier": "F9", "virgin atlantic": "VS",
    "virgin australia": "VA", "air new zealand": "NZ", "emirates": "EK", "qatar": "QR",
    "turkish": "TK", "aer lingus": "EI", "loganair": "LM", "vueling": "VY", "tap": "TP",
    "westjet": "WS", "porter": "PD", "sky high": "DO", "plus ultra": "PU", "conviasa": "V0",
}


def airline_code(airline: str) -> str:
    low = norm(airline)
    for name, code in AIRLINE_CODES.items():
        if low.startswith(name):
            return code
    letters = [w[0] for w in re.findall(r"[A-Za-z]+", airline)]
    return ("".join(letters) + "XX")[:2].upper()


# ---------------------------------------------------------------------------
# 6. Clima: tabla "Climate data for ..." del artículo de la ciudad
# ---------------------------------------------------------------------------
def _pick_metric(values: list[float], label: str, metric: str, imperial: str) -> float | None:
    """Las celdas traen dos unidades ('26.9 (80.4)'); elige la métrica según el orden del encabezado."""
    if not values:
        return None
    low = label.lower()
    has_m, has_i = metric in low, imperial in low
    if has_m and has_i:
        if low.index(metric) < low.index(imperial):    # "°C (°F)": la métrica va primero
            return values[0]
        return values[1] if len(values) > 1 else None  # "°F (°C)": va entre paréntesis
    if has_m:
        return values[0]
    return None  # solo unidades imperiales: se convierte afuera


def parse_climate(html: str) -> dict | None:
    """Devuelve {'temp': [12 medias °C], 'precip': [12 mm] | None, 'caption': str} o None."""
    soup = BeautifulSoup(html, "lxml")
    for sup in soup.find_all("sup"):
        sup.decompose()
    for table in soup.find_all("table"):
        first = table.find("tr")
        title = (table.caption.get_text(" ", strip=True) if table.caption else "") + " " + \
                (first.get_text(" ", strip=True) if first else "")
        if "climate data for" not in title.lower():
            continue
        rows: dict[str, list[float | None]] = {}
        for tr in table.find_all("tr"):
            th, tds = tr.find("th"), tr.find_all("td")
            if not th or len(tds) < 12:
                continue
            label = th.get_text(" ", strip=True)
            low = label.lower()
            if low.startswith(("daily mean", "mean daily maximum", "average high",
                               "mean daily minimum", "average low")):
                kind = ("mean" if low.startswith("daily mean") else
                        "max" if ("maximum" in low or "high" in low) else "min")
                if kind in rows:
                    continue
                vals = []
                for td in tds[:12]:
                    nums = numbers_in(td.get_text(" ", strip=True))
                    v = _pick_metric(nums, label, "°c", "°f")
                    if v is None and nums and "°f" in low:
                        v = (nums[0] - 32) * 5 / 9
                    vals.append(v)
                rows[kind] = vals
            elif (("precipitation" in low or "rainfall" in low) and "days" not in low
                  and "precip" not in rows):
                if "mm" not in low and "inch" not in low:
                    continue
                vals = []
                for td in tds[:12]:
                    nums = numbers_in(td.get_text(" ", strip=True))
                    v = _pick_metric(nums, label, "mm", "inch")
                    if v is None and nums and "inch" in low:
                        v = nums[0] * 25.4
                    vals.append(v if v is not None else 0.0)   # 'trace' -> 0
                rows["precip"] = vals

        temp = rows.get("mean")
        if not temp or any(v is None for v in temp):
            if rows.get("max") and rows.get("min") and None not in rows["max"] + rows["min"]:
                temp = [(a + b) / 2 for a, b in zip(rows["max"], rows["min"])]
            else:
                continue
        return {"temp": [round(v, 1) for v in temp],
                "precip": [round(v, 1) for v in rows["precip"]] if "precip" in rows else None,
                "caption": title.strip()[:160]}
    return None


def best_months(temp: list[float], precip: list[float] | None) -> list[int]:
    """Meses con mejor combinación de temperatura agradable (18-28 °C) y pocas lluvias."""
    pmax = max(precip) if precip and max(precip) > 0 else None
    scores = []
    for i, t in enumerate(temp):
        if 18 <= t <= 28:
            ts = 1.0
        elif t < 18:
            ts = max(0.0, 1 - (18 - t) / 10)
        else:
            ts = max(0.0, 1 - (t - 28) / 8)
        rs = 1 - precip[i] / pmax if pmax else 0.5
        scores.append(0.6 * ts + 0.4 * rs)
    top = max(scores)
    months = [i + 1 for i, s in enumerate(scores) if s >= top - 0.12]
    if len(months) < 3:
        months = sorted(sorted(range(12), key=lambda i: -scores[i])[:3])
        months = [m + 1 for m in months]
    return sorted(months)


def climate_type(temp: list[float], precip: list[float] | None,
                 elevation_m: float = 0.0, latitude: float = 0.0) -> str:
    """Traduce la tabla de clima al enum ClimateType del backend (8 valores exactos)."""
    mean = sum(temp) / 12
    annual = sum(precip) if precip else None
    amplitude = max(temp) - min(temp)

    if elevation_m >= 1500 and mean <= 21:
        return "HIGHLAND_COLD"
    if mean >= 24:
        return "TROPICAL_HUMID" if annual and annual >= 1500 else "TROPICAL_DRY"
    if mean >= 18:
        return "SUBTROPICAL"
    if mean >= 10:
        if precip:
            summer = [5, 6, 7] if latitude >= 0 else [11, 0, 1]
            winter = [11, 0, 1] if latitude >= 0 else [5, 6, 7]
            summer_mm = sum(precip[i] for i in summer)
            winter_mm = sum(precip[i] for i in winter)
            if winter_mm > 0 and summer_mm < 0.4 * winter_mm:
                return "MEDITERRANEAN"
        if amplitude >= 18:
            return "CONTINENTAL"
        if annual and annual >= 600:
            return "OCEANIC"
        return "TEMPERATE"
    return "CONTINENTAL"


def months_text(months: list[int]) -> str:
    """[12, 1, 2, 3] -> 'dic, ene, feb, mar' (en orden de calendario de la temporada)."""
    if len(months) == 12:
        return "Todo el año"
    ms = sorted(months)
    # si la temporada cruza el año (dic-ene), empieza después del "hueco" más grande
    gaps = [(ms[(i + 1) % len(ms)] - ms[i]) % 12 for i in range(len(ms))]
    start = (gaps.index(max(gaps)) + 1) % len(ms)
    ordered = ms[start:] + ms[:start]
    return ", ".join(MONTHS_ES[m - 1] for m in ordered)


# ---------------------------------------------------------------------------
# 7. Actividades / tags: palabras clave en Wikivoyage
# ---------------------------------------------------------------------------
TAG_KEYWORDS: dict[str, str] = {
    "Playa": r"beach(?:es)?|seaside|seafront",
    "Buceo": r"scuba|diving|dive sites?",
    "Snorkel": r"snorkel(?:l?ing)?",
    "Deportes Acuáticos": r"surf(?:ing)?|kayak(?:ing)?|sailing|kitesurf(?:ing)?|windsurf(?:ing)?|jet ?ski",
    "Cultura": r"cultur(?:e|al)|festivals?|theat(?:re|er)s?|concerts?|carnival",
    "Historia": r"histor(?:y|ic|ical)|colonial|fortress(?:es)?|forts?|cathedrals?|castles?|palaces?|monuments?",
    "Museos": r"museums?",
    "Arqueología": r"archaeolog\w*|ruins|pre-columbian|mayan?|pyramids?",
    "Naturaleza": r"nature|national parks?|wildlife|waterfalls?|botanical|nature reserves?|lakes?|jungle",
    "Senderismo": r"hik(?:e|es|ing)|trek(?:king)?|trails?",
    "Deportes": r"stadiums?|football|baseball|basketball|golf|cycling|climbing",
    "Gastronomía": r"cuisine|gastronom\w*|street food|food markets?|local dishes|foodies?",
    "Vida Nocturna": r"nightlife|night ?clubs?|clubs|bars|pubs|salsa|dancing",
    "Arte": r"art galler(?:y|ies)|galler(?:y|ies)|street art|murals?|artists?",
    "Compras": r"shopping|malls?|boutiques?|markets?",
}
_TAG_RE = {tag: re.compile(rf"\b(?:{pat})\b", re.IGNORECASE) for tag, pat in TAG_KEYWORDS.items()}
VOYAGE_SECTIONS = {"understand", "see", "do", "buy", "eat", "drink"}


def article_sections(html: str) -> dict[str, str]:
    """Separa un artículo MediaWiki por títulos h2: {'see': 'texto...', 'do': ...}."""
    soup = BeautifulSoup(html, "lxml")
    root = soup.select_one(".mw-parser-output") or soup.body or soup
    sections: dict[str, list[str]] = {}
    current = "intro"
    for child in root.children:
        if not isinstance(child, Tag):
            continue
        h2 = child if child.name == "h2" else (
            child.find("h2") if "mw-heading2" in (child.get("class") or []) else None)
        if h2 is not None:
            current = norm(h2.get_text(" ", strip=True))
            continue
        sections.setdefault(current, []).append(child.get_text(" ", strip=True))
    return {k: " ".join(v) for k, v in sections.items()}


def count_tags(text: str) -> dict[str, int]:
    return {tag: len(rx.findall(text)) for tag, rx in _TAG_RE.items()}


def tags_from_counts(counts: dict[str, int], max_tags: int = 6) -> dict[str, float]:
    """Pesos 0-1 relativos dentro del mismo destino (log para que 'restaurant' no aplaste todo)."""
    useful = {t: c for t, c in counts.items() if c >= 2}
    if not useful:
        return {}
    top = max(useful.values())
    weights = {t: round(math.log1p(c) / math.log1p(top), 2) for t, c in useful.items()}
    best = sorted(weights.items(), key=lambda kv: -kv[1])[:max_tags]
    return {t: w for t, w in best if w >= 0.3}


TRAVELER_FIT_RULES: dict[str, dict[str, float]] = {
    "familia": {"playa": .30, "naturaleza": .25, "cultura": .20, "historia": .15, "deportes": .10},
    "pareja": {"playa": .25, "gastronomia": .25, "vida_nocturna": .20, "arte": .15, "historia": .15},
    "amigos": {"vida_nocturna": .35, "deportes": .35, "playa": .15, "gastronomia": .15},
    "solo": {"aventura": .25, "cultura": .40, "naturaleza": .20, "historia": .15},
}

# El backend (LocationService.normalizeTags) solo admite llaves en minúsculas, sin
# tildes, sin puntos y sin espacios. Este mapa traduce los tags scrapeados al
# vocabulario controlado que ya usan los destinos de la base.
TAG_MAP: dict[str, str] = {
    "Playa": "playa",
    "Buceo": "deportes",
    "Snorkel": "deportes",
    "Deportes Acuáticos": "deportes",
    "Cultura": "cultura",
    "Historia": "historia",
    "Museos": "cultura",
    "Arqueología": "historia",
    "Naturaleza": "naturaleza",
    "Senderismo": "aventura",
    "Deportes": "deportes",
    "Gastronomía": "gastronomia",
    "Vida Nocturna": "vida_nocturna",
    "Arte": "arte",
    "Compras": "compras",
}
# Orden estable para que el JSON no cambie de una corrida a otra.
TAG_ORDER = ["naturaleza", "gastronomia", "descanso", "aventura", "cultura", "historia",
             "festivales", "playa", "romance", "ciudad", "arte", "compras",
             "vida_nocturna", "deportes", "baile"]


def canonical_tags(tags: dict[str, float]) -> dict[str, float]:
    """Traduce los tags scrapeados al vocabulario del backend y fusiona los que coinciden."""
    merged: dict[str, float] = {}
    for raw, weight in tags.items():
        key = TAG_MAP.get(raw) or norm(raw).replace(" ", "_")
        merged[key] = max(merged.get(key, 0.0), min(1.0, float(weight)))
    ordered = [key for key in TAG_ORDER if key in merged]
    ordered += [key for key in merged if key not in TAG_ORDER]
    return {key: merged[key] for key in ordered}


def traveler_fit(tags: dict[str, float]) -> dict[str, float]:
    """0.4 base + hasta 0.6 según cuánto coinciden los tags con el tipo de viaje."""
    return {who: round(min(1.0, 0.4 + 0.6 * sum(w * tags.get(t, 0) for t, w in rule.items())), 2)
            for who, rule in TRAVELER_FIT_RULES.items()}


# ---------------------------------------------------------------------------
# 8. Precios y horarios (estimados)
# ---------------------------------------------------------------------------
def base_price_usd(km: float) -> float:
    """Tarifa económica típica en USD según la distancia (aproximada; ajusta los números si tienen precios de referencia)."""
    if km < 800:
        return 45 + 0.09 * km
    if km < 3000:
        return 70 + 0.085 * km
    return 180 + 0.065 * km


def flight_minutes(km: float) -> int:
    """~820 km/h de crucero + 35 min de rodaje, despegue y aterrizaje."""
    return int(round(km / 820 * 60 + 35))


SHORT_HAUL = ["Airbus A320neo", "Boeing 737-800", "Airbus A319", "Embraer E190"]
MEDIUM_HAUL = ["Airbus A330-200", "Airbus A330-300", "Boeing 787-8"]
LONG_HAUL = ["Boeing 787-9", "Airbus A350-900", "Boeing 777-300ER"]


def pick_aircraft(km: float, rng: random.Random) -> str:
    """Avión coherente con la duración del tramo (mismo catálogo que seed_flights.py)."""
    if km < 3000:
        return rng.choice(SHORT_HAUL)
    if km < 8000:
        return rng.choice(MEDIUM_HAUL)
    return rng.choice(LONG_HAUL)


def sold_seats(rng: random.Random) -> tuple[list[str], int]:
    """Asientos ocupados válidos de SeatCatalog y su contador (seatsLeft)."""
    if rng.random() >= 0.4:
        return [], CAPACITY
    codes = [f"{row}{col}" for row in range(1, 16) for col in "ABCDEF"]
    taken = sorted(rng.sample(codes, rng.randint(3, 48)), key=lambda c: (int(c[:-1]), c[-1]))
    return taken, CAPACITY - len(taken)


# ---------------------------------------------------------------------------
# 9. Orquestación
# ---------------------------------------------------------------------------
@dataclass
class Result:
    destinations: list[dict]
    flights: list[dict]
    routes: list[tuple[str, str, str, bool]]
    warnings: list[str]


def build_dataset(http: Http, seeds: list[Seed], start: date, days: int,
                  rng: random.Random, today: date | None = None,
                  fare_ids: list[str] | None = None) -> Result:
    today = today or date.today()
    now = datetime.now()
    fare_ids = list(fare_ids or [])
    wp, wv = Wiki(http, WIKIPEDIA), Wiki(http, WIKIVOYAGE)
    airports = load_airports(http)
    warnings: list[str] = []

    for s in seeds:
        if s.iata not in airports:
            warnings.append(f"{s.iata}: no está en OurAirports, se omite")
    seeds = [s for s in seeds if s.iata in airports]
    matcher = SeedMatcher(seeds, airports)

    # --- Rutas reales ---------------------------------------------------
    routes: dict[tuple[str, str, str], bool] = {}     # (origen, destino, aerolínea) -> estacional
    for s in seeds:
        ap = airports[s.iata]
        page = wp.parse(ap["wiki_title"] or ap["name"])
        if not page:
            warnings.append(f"{s.iata}: sin artículo del aeropuerto")
            continue
        mentions = parse_airline_routes(page[1])
        found = 0
        for m in mentions:
            dest = matcher.match(m.text, m.title)
            if not dest or dest == s.iata:
                continue
            for key in ((s.iata, dest, m.airline), (dest, s.iata, m.airline)):   # ida y vuelta
                routes[key] = routes.get(key, True) and m.seasonal
            found += 1
        log.info("%s: %d enlaces en la tabla, %d hacia destinos del catálogo", s.iata, len(mentions), found)

    # --- Destinos ----------------------------------------------------------
    destinations: list[dict] = []
    views: dict[str, int] = {}
    for s in seeds:
        ap = airports[s.iata]
        cost_level, visa_policy, entry_note = country_policy(ap["iso"])
        doc: dict = {
            "_id": new_object_id(),
            "cityName": s.city,
            "countryName": ap["country"],
            "iataCode": s.iata,
            "airportName": ap["name"],
            "status": "ACTIVE",
            "tags": {},
            "travelerFit": {},
            "bestMonths": [],
            "climateType": None,
            "costLevel": cost_level,
            "visaPolicy": visa_policy,
            "entryNote": entry_note,
            "rating": 0.0,
            "ratingCount": 0,
            "featured": False,
            "imageUrl": None,
            "schemaVersion": LOCATION_SCHEMA_VERSION,
            "updatedAt": now,
            "cheapestPrice": 0.0,
            "_class": LOCATION_CLASS,
            "source": SOURCE_TAG,
            "sources": ["https://ourairports.com/data/"],
        }
        # Clima (Wikipedia)
        city_page = wp.parse(s.wiki)
        climate = None
        wiki_text = ""
        if city_page:
            doc["sources"].append(wp.page_url(city_page[0]))
            climate = parse_climate(city_page[1])
            wiki_text = " ".join(article_sections(city_page[1]).values())
            if not climate:
                alt = wp.parse(f"Climate of {city_page[0]}", search_fallback=False)
                if alt:
                    climate = parse_climate(alt[1])
                    if climate:
                        doc["sources"].append(wp.page_url(alt[0]))
            views[s.iata] = yearly_pageviews(http, city_page[0], today)
        if climate:
            doc["bestMonths"] = best_months(climate["temp"], climate["precip"])
            doc["climateType"] = climate_type(climate["temp"], climate["precip"],
                                              ap.get("elevation_m", 0.0), ap["lat"])
        else:
            warnings.append(f"{s.iata}: no se encontró tabla de clima")

        # Actividades (Wikivoyage; si el artículo es corto, se suma el de Wikipedia)
        counts = {t: 0 for t in TAG_KEYWORDS}
        vpage = wv.parse(s.voyage)
        if vpage:
            doc["sources"].append(wv.page_url(vpage[0]))
            secs = article_sections(vpage[1])
            text = " ".join(v for k, v in secs.items() if k in VOYAGE_SECTIONS) or " ".join(secs.values())
            counts = count_tags(text)
        if sum(counts.values()) < 15 and wiki_text:
            extra = count_tags(wiki_text)
            counts = {t: counts[t] + extra[t] for t in counts}
        tags = canonical_tags(tags_from_counts(counts))
        if not tags:
            warnings.append(f"{s.iata}: sin actividades detectadas")
        doc["tags"] = tags
        doc["travelerFit"] = traveler_fit(tags)
        destinations.append(doc)

    # Popularidad -> rating, ratingCount y featured
    positive = [v for v in views.values() if v > 0]
    lo, hi = (math.log(min(positive)), math.log(max(positive))) if positive else (0, 1)
    for d in destinations:
        v = views.get(d["iataCode"], 0)
        if v > 0:
            rel = (math.log(v) - lo) / (hi - lo) if hi > lo else 0.5
            d["rating"] = round(3.8 + rel + rng.uniform(-0.1, 0.1), 1)
            d["ratingCount"] = max(5, int(v / 2000))
        else:
            d["rating"], d["ratingCount"] = 0.0, 0
        d["rating"] = min(5.0, max(0.0, d["rating"]))
    top5 = sorted((d for d in destinations if views.get(d["iataCode"], 0) > 0),
                  key=lambda d: -views[d["iataCode"]])[:5]
    for d in destinations:
        d["featured"] = d in top5

    # --- Vuelos ------------------------------------------------------------
    by_iata = {d["iataCode"]: d for d in destinations}
    flights: list[dict] = []
    numbers: dict[str, int] = {}
    for (o, a, airline), seasonal in sorted(routes.items()):
        ao, aa = airports[o], airports[a]
        km = haversine_km(ao["lat"], ao["lon"], aa["lat"], aa["lon"])
        per_week = 2 if seasonal else 7 if km < 2500 else 5 if km < 6000 else 4
        weekdays = set(rng.sample(range(7), per_week))
        slots = 2 if (km < 1200 and not seasonal) else 1
        code = airline_code(airline)
        times = []
        for _ in range(slots):
            numbers[code] = numbers.get(code, rng.randint(100, 400)) + rng.randint(1, 9)
            times.append((rng.randint(5, 21), rng.choice([0, 10, 15, 25, 30, 40, 45, 55]), numbers[code]))
        best = set(by_iata[a].get("bestMonths") or [])
        aircraft = pick_aircraft(km, rng)
        duration = flight_minutes(km)
        for offset in range(days):
            day = start + timedelta(days=offset)
            if day.weekday() not in weekdays:
                continue
            for hour, minute, number in times:
                dep = datetime(day.year, day.month, day.day, hour, minute)
                factor = rng.uniform(0.85, 1.25)
                if day.month in best or day.month in (12, 1):
                    factor *= 1.15                         # temporada alta
                if day.weekday() in (4, 6):
                    factor *= 1.05                         # viernes y domingo
                base_price = round(base_price_usd(km) * factor, 2)
                discounted = rng.random() < 0.15
                discount = float(rng.choice([10, 15, 20, 25, 30])) if discounted else 0.0
                ticket_price = round(base_price * (1 - discount / 100), 2) if discounted else base_price
                taken, seats_left = sold_seats(rng)
                flights.append({
                    "_id": new_object_id(),
                    "airline": airline,
                    "ticketPrice": ticket_price,
                    "flightNumber": f"{code}{number}",
                    "aircraft": aircraft,
                    "scales": 0,                       # las rutas de Wikipedia son directas
                    "departureLocationID": by_iata[o]["_id"],
                    "arrivalLocationID": by_iata[a]["_id"],
                    "departureDate": dep,
                    "arrivalDate": dep + timedelta(minutes=duration),
                    "availableFareIDs": list(fare_ids),
                    "discounted": discounted,
                    "discountPercentage": discount,
                    "offerValidUntil": dep - timedelta(hours=6) if discounted else None,
                    "status": "CANCELED" if rng.random() < 0.01 else "ACTIVE",
                    "basePrice": base_price,
                    "durationMinutes": duration,
                    "seatsLeft": seats_left,
                    "takenSeats": taken,
                    "priceUpdatedAt": now,
                    "schemaVersion": FLIGHT_SCHEMA_VERSION,
                    "updatedAt": now,
                    "_class": FLIGHT_CLASS,
                    "source": SOURCE_TAG,
                })
                if flights[-1]["offerValidUntil"] is None:
                    flights[-1].pop("offerValidUntil")

    # cheapestPrice = ticketPrice más bajo que llega al destino (misma regla que
    # LocationService.updateAllCheapestPrices: usa todos los vuelos, ya descontados).
    cheapest: dict[str, float] = {}
    for f in flights:
        price = f["ticketPrice"]
        cheapest[f["arrivalLocationID"]] = min(cheapest.get(f["arrivalLocationID"], math.inf), price)
    for d in destinations:
        if d["_id"] in cheapest:
            d["cheapestPrice"] = round(cheapest[d["_id"]], 2)
        else:
            d["cheapestPrice"] = 0.0
            warnings.append(f"{d['iataCode']}: ninguna ruta real hacia otro destino del catálogo")
    if flights and not fare_ids:
        warnings.append("availableFareIDs vacío: usa --mongo (lee Fares) o --tarifas con los IDs")

    route_list = [(o, a, al, s) for (o, a, al), s in sorted(routes.items())]
    return Result(destinations, flights, route_list, warnings)


# ---------------------------------------------------------------------------
# 10. Salida: JSON (mongoimport) o escritura directa en MongoDB
# ---------------------------------------------------------------------------
def to_extended_json(doc: dict) -> dict:
    """_id -> {'$oid'}, fechas -> {'$date'}: formato que entiende mongoimport y Spring."""
    out = {}
    for k, v in doc.items():
        if k == "_id":
            out[k] = {"$oid": v}
        elif isinstance(v, datetime):
            stored = to_store(v)
            out[k] = {"$date": stored.replace(tzinfo=timezone.utc).isoformat().replace("+00:00", "Z")}
        else:
            out[k] = v
    return out


def write_json(result: Result, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, docs in (("destinations", result.destinations), ("flights", result.flights)):
        payload = [to_extended_json(d) for d in docs]
        (out_dir / f"{name}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    with open(out_dir / "rutas.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["origen", "destino", "aerolinea", "estacional"])
        w.writerows(result.routes)


# Campos de Location que se actualizan en un destino que YA existe (no se tocan
# nombres, IATA ni IDs). Los campos viejos del scraper se eliminan con $unset.
DATA_FIELDS = ["tags", "travelerFit", "bestMonths", "climateType", "costLevel", "visaPolicy",
               "entryNote", "rating", "ratingCount", "featured", "schemaVersion",
               "updatedAt", "cheapestPrice", "sources", "_class"]
LEGACY_DESTINATION_FIELDS = ["secret", "activities", "climate", "bestDate", "avgTempC", "avgPrecipMm"]


def _stored(doc: dict) -> dict:
    """Convierte las fechas locales de un documento al instante que guarda Spring."""
    return {k: to_store(v) if isinstance(v, datetime) else v for k, v in doc.items()}


def push_to_mongo(result: Result, uri: str, db_name: str) -> None:
    from bson import ObjectId
    from pymongo import MongoClient

    db = MongoClient(uri, serverSelectionTimeoutMS=8000)[db_name]
    remap: dict[str, str] = {}
    created = updated = 0
    for d in result.destinations:
        existing = db["Destinations"].find_one({"iataCode": d["iataCode"]}, {"_id": 1})
        if existing:
            update = _stored({k: d[k] for k in DATA_FIELDS if k in d})
            db["Destinations"].update_one({"_id": existing["_id"]},
                                          {"$set": update,
                                           "$unset": {k: "" for k in LEGACY_DESTINATION_FIELDS}})
            remap[d["_id"]] = str(existing["_id"])
            updated += 1
        else:
            db["Destinations"].insert_one(_stored({**d, "_id": ObjectId(d["_id"])}))
            created += 1

    deleted = db["Flights"].delete_many({"source": SOURCE_TAG}).deleted_count
    docs = []
    for f in result.flights:
        doc = _stored({**f, "_id": ObjectId(f["_id"])})
        doc["departureLocationID"] = remap.get(f["departureLocationID"], f["departureLocationID"])
        doc["arrivalLocationID"] = remap.get(f["arrivalLocationID"], f["arrivalLocationID"])
        docs.append(doc)
    for i in range(0, len(docs), 1000):
        db["Flights"].insert_many(docs[i:i + 1000])
    log.info("MongoDB '%s': destinos %d nuevos / %d actualizados; vuelos %d borrados (del scraper) y %d insertados",
             db_name, created, updated, deleted, len(docs))


# ---------------------------------------------------------------------------
# 11. Línea de comandos
# ---------------------------------------------------------------------------
def load_seed_file(path: Path) -> list[Seed]:
    return [Seed(**item) for item in json.loads(path.read_text(encoding="utf-8"))]


def load_fare_ids(uri: str, db_name: str) -> list[str]:
    """IDs de la colección Fares, el valor que espera Flight.availableFareIDs."""
    from pymongo import MongoClient

    db = MongoClient(uri, serverSelectionTimeoutMS=8000)[db_name]
    return [str(f["_id"]) for f in db["Fares"].find({}, {"_id": 1}).sort("tierRank", 1)]


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Scraper de datos realistas para Royal Airlines")
    p.add_argument("--contacto", default=os.getenv("SCRAPER_CONTACT", ""),
                   help="correo o URL de contacto para el User-Agent (lo pide Wikimedia)")
    p.add_argument("--salida", type=Path, default=Path("salida"), help="carpeta de los JSON")
    p.add_argument("--cache", type=Path, default=Path(".cache_scraper"), help="carpeta de la caché")
    p.add_argument("--desde", type=date.fromisoformat, default=date.today() + timedelta(days=1),
                   help="primer día con vuelos (AAAA-MM-DD); por defecto mañana")
    p.add_argument("--dias", type=int, default=30, help="cuántos días de vuelos generar")
    p.add_argument("--semilla", type=int, default=42, help="semilla aleatoria (mismo valor = mismos datos)")
    p.add_argument("--solo", nargs="*", metavar="IATA", help="limitar a estos destinos (p. ej. CTG BOG MIA)")
    p.add_argument("--destinos", type=Path, help="JSON con tu propia lista de destinos")
    p.add_argument("--tarifas", help="IDs de Fares separados por coma para availableFareIDs (si no usas --mongo)")
    p.add_argument("--refrescar", action="store_true", help="ignorar la caché y descargar de nuevo")
    p.add_argument("--offline", action="store_true", help="usar solo la caché, sin internet")
    p.add_argument("--pausa", type=float, default=1.0, help="segundos entre peticiones")
    p.add_argument("--mongo", action="store_true", help="escribir en MongoDB usando DB_URI y DB_DATABASE")
    p.add_argument("-v", "--verbose", action="store_true")
    args = p.parse_args(argv)

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(levelname)-7s %(message)s")
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if not args.contacto and not args.offline:
        p.error("falta --contacto (o la variable SCRAPER_CONTACT): Wikimedia pide identificar quién hace las peticiones")

    mongo_conf = None
    if args.mongo:
        uri, name = os.getenv("DB_URI"), os.getenv("DB_DATABASE")
        if not uri or not name:
            p.error("--mongo necesita las variables de entorno DB_URI y DB_DATABASE")
        mongo_conf = (uri, name)

    fare_ids = [x.strip() for x in (args.tarifas or "").split(",") if x.strip()]
    if not fare_ids and mongo_conf:
        fare_ids = load_fare_ids(*mongo_conf)
        if not fare_ids:
            log.warning("La colección Fares está vacía: los vuelos quedarán sin availableFareIDs")

    seeds = load_seed_file(args.destinos) if args.destinos else DEFAULT_SEEDS
    if args.solo:
        wanted = {c.upper() for c in args.solo}
        seeds = [s for s in seeds if s.iata in wanted]

    http = Http(args.cache, args.contacto, args.pausa, args.refrescar, args.offline)
    result = build_dataset(http, seeds, args.desde, args.dias, random.Random(args.semilla),
                           fare_ids=fare_ids)
    write_json(result, args.salida)

    print(f"\nDestinos: {len(result.destinations)} | rutas reales: {len(result.routes)} "
          f"| vuelos generados: {len(result.flights)}")
    print(f"Archivos en: {args.salida.resolve()}")
    for w in result.warnings:
        print(f"  aviso: {w}")

    if mongo_conf:
        push_to_mongo(result, *mongo_conf)
    return 0


if __name__ == "__main__":
    sys.exit(main())
