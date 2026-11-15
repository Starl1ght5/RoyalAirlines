"""Pruebas sin internet: el HTML imita el que devuelve la API de Wikipedia/Wikivoyage.

Ejecutar:  python -m pytest -q
"""
import json
import random
from datetime import date

import royal_scraper as rs

# --- HTML de ejemplo (misma estructura que las páginas reales) ---------------

AIRPORT_CTG = """
<div class="mw-parser-output">
<div class="mw-heading mw-heading2"><h2 id="Airlines_and_destinations">Airlines and destinations</h2></div>
<div class="mw-heading mw-heading3"><h3 id="Passenger">Passenger</h3></div>
<table class="wikitable sortable">
<tr><th>Airlines</th><th>Destinations</th><th>Refs</th></tr>
<tr><td><a href="/wiki/Avianca" title="Avianca">Avianca</a></td>
<td><a href="/wiki/El_Dorado_International_Airport" title="El Dorado International Airport">Bogotá</a>,
<a href="/wiki/Jos%C3%A9_Mar%C3%ADa_C%C3%B3rdova_International_Airport" title="José María Córdova International Airport">Medellín–JMC</a>
<br><b>Seasonal:</b> <a href="/wiki/Miami_International_Airport" title="Miami International Airport">Miami</a>,
<a href="/wiki/John_F._Kennedy_International_Airport" title="John F. Kennedy International Airport">New York–JFK</a></td>
<td><sup>[12]</sup></td></tr>
<tr><td><a href="/wiki/Air_Canada" title="Air Canada">Air Canada</a></td>
<td><b>Seasonal:</b> <a href="/wiki/Montr%C3%A9al%E2%80%93Trudeau" title="Montréal–Trudeau International Airport">Montréal–Trudeau</a></td><td></td></tr>
<tr><td>American Airlines<sup>[3]</sup></td>
<td><a href="/wiki/MIA" title="Miami International Airport">Miami</a></td><td></td></tr>
</table>
<div class="mw-heading mw-heading3"><h3 id="Cargo">Cargo</h3></div>
<table class="wikitable"><tr><th>Airlines</th><th>Destinations</th></tr>
<tr><td>Avianca Cargo</td><td><a href="/wiki/X" title="Madrid–Barajas Airport">Madrid</a></td></tr></table>
</div>"""

AIRPORT_BOG = """
<div class="mw-parser-output"><table class="wikitable">
<tr><th>Airlines</th><th>Destinations</th></tr>
<tr><td>Avianca</td><td><a href="/wiki/R" title="Rafael Núñez International Airport">Cartagena</a>,
<a href="/wiki/M" title="Madrid–Barajas Airport">Madrid</a></td></tr>
<tr><td>Iberia</td><td><a href="/wiki/M2" title="Adolfo Suárez Madrid–Barajas Airport">Madrid</a></td></tr>
</table></div>"""

AIRPORT_EMPTY = '<div class="mw-parser-output"><p>Sin tabla</p></div>'


def climate_table(caption, temp_label, temps, precip_label, precips):
    tds = lambda vals: "".join(f"<td>{v}</td>" for v in vals)
    return f"""<div class="mw-parser-output"><p>Texto.</p>
<table class="wikitable mw-collapsible">
<tr><th colspan="14">{caption}</th></tr>
<tr><th>Month</th><th>Jan</th><th>Feb</th><th>Mar</th><th>Apr</th><th>May</th><th>Jun</th><th>Jul</th><th>Aug</th><th>Sep</th><th>Oct</th><th>Nov</th><th>Dec</th><th>Year</th></tr>
<tr><th scope="row">Record high °C (°F)</th>{tds(['40.0 (104.0)'] * 13)}</tr>
<tr><th scope="row">{temp_label}</th>{tds(temps)}</tr>
<tr><th scope="row">{precip_label}</th>{tds(precips)}</tr>
<tr><th scope="row">Average precipitation days (≥ 1 mm)</th>{tds(['5'] * 13)}</tr>
</table></div>"""


CTG_TEMPS = ["26.9 (80.4)", "27.0 (80.6)", "27.3 (81.1)", "28.1 (82.6)", "28.6 (83.5)", "28.9 (84.0)",
             "28.6 (83.5)", "28.7 (83.7)", "28.6 (83.5)", "28.3 (82.9)", "28.1 (82.6)", "27.5 (81.5)", "28.0 (82.4)"]
CTG_PRECIP = ["0.5 (0.02)", "0.3 (0.01)", "3.2 (0.13)", "18.6 (0.73)", "117.4 (4.62)", "92.5 (3.64)",
              "121.1 (4.77)", "127.5 (5.02)", "133.1 (5.24)", "236.5 (9.31)", "178.3 (7.02)", "44.7 (1.76)",
              "1,073.8 (42.28)"]
CHI_TEMPS = ["26.2 (−3.2)", "29.9 (−1.2)", "39.9 (4.4)", "50.9 (10.5)", "61.9 (16.6)", "71.9 (22.2)",
             "76.7 (24.8)", "75.0 (23.9)", "67.8 (19.9)", "55.3 (12.9)", "42.4 (5.8)", "31.5 (−0.3)", "52.4 (11.3)"]
CHI_PRECIP = ["2.30 (58)", "2.12 (54)", "2.66 (68)", "4.15 (105)", "4.75 (121)", "4.53 (115)", "4.02 (102)",
              "4.10 (104)", "3.33 (85)", "3.86 (98)", "2.73 (69)", "2.33 (59)", "40.88 (1,038)"]

CTG_CITY = climate_table("Climate data for Cartagena (Rafael Núñez International Airport) 1991–2020",
                         "Daily mean °C (°F)", CTG_TEMPS, "Average precipitation mm (inches)", CTG_PRECIP)
CHI_CITY = climate_table("Climate data for Chicago (Midway International Airport), 1991–2020 normals",
                         "Daily mean °F (°C)", CHI_TEMPS, "Average precipitation inches (mm)", CHI_PRECIP)

VOYAGE_CTG = """<div class="mw-parser-output">
<p>Cartagena is a colonial city on the Caribbean coast.</p>
<div class="mw-heading mw-heading2"><h2 id="Understand">Understand</h2></div>
<p>The historic walled city, colonial history, the fortress and the cathedral. Festivals all year.</p>
<div class="mw-heading mw-heading2"><h2 id="Get_in">Get in</h2></div>
<p>Beach beach beach beach beach (no debe contar: sección ignorada).</p>
<div class="mw-heading mw-heading2"><h2 id="See">See</h2></div>
<ul><li><b>Castillo San Felipe</b> — a fortress, the biggest fort. Museum of history.</li>
<li><b>Museo del Oro</b> — museum. Another museum nearby.</li></ul>
<div class="mw-heading mw-heading2"><h2 id="Do">Do</h2></div>
<p>Go to the beach. Beaches of Rosario islands, scuba diving and diving trips, snorkeling, the beach again.</p>
<div class="mw-heading mw-heading2"><h2 id="Drink">Drink</h2></div>
<p>Nightlife in Getsemaní: bars, salsa clubs, bars and more bars.</p>
</div>"""

VOYAGE_GENERIC = """<div class="mw-parser-output">
<div class="mw-heading mw-heading2"><h2 id="See">See</h2></div>
<p>Museum, museums, art gallery, galleries, history, historic palace, parks and nature, lakes.</p>
<div class="mw-heading mw-heading2"><h2 id="Do">Do</h2></div>
<p>Hiking trails, hike, trekking. Stadium football. Shopping malls and markets.</p>
</div>"""

AIRPORTS_CSV = """"id","ident","type","name","latitude_deg","longitude_deg","elevation_ft","continent","iso_country","iso_region","municipality","scheduled_service","gps_code","iata_code","local_code","home_link","wikipedia_link","keywords"
1,"SKCG","large_airport","Rafael Nuñez International Airport",10.4424,-75.513,4,"SA","CO","CO-BOL","Cartagena","yes","SKCG","CTG","","","https://en.wikipedia.org/wiki/Rafael_N%C3%BA%C3%B1ez_International_Airport",""
2,"SKBO","large_airport","El Dorado International Airport",4.70159,-74.1469,8361,"SA","CO","CO-CUN","Bogotá","yes","SKBO","BOG","","","https://en.wikipedia.org/wiki/El_Dorado_International_Airport",""
3,"KMIA","large_airport","Miami International Airport",25.7932,-80.2906,8,"NA","US","US-FL","Miami","yes","KMIA","MIA","","","https://en.wikipedia.org/wiki/Miami_International_Airport",""
4,"LEMD","large_airport","Adolfo Suárez Madrid–Barajas Airport",40.4719,-3.56264,1998,"EU","ES","ES-M","Madrid","yes","LEMD","MAD","","","https://en.wikipedia.org/wiki/Adolfo_Su%C3%A1rez_Madrid%E2%80%93Barajas_Airport",""
5,"KORD","large_airport","Chicago O'Hare International Airport",41.9786,-87.9048,672,"NA","US","US-IL","Chicago","yes","KORD","ORD","","","https://en.wikipedia.org/wiki/O%27Hare_International_Airport",""
6,"XXXX","closed","Old Bogota",4.7,-74.1,0,"SA","CO","CO-CUN","Bogotá","no","","BOG","","","",""
"""
COUNTRIES_CSV = '"id","code","name","continent"\n1,"CO","Colombia","SA"\n2,"US","United States","NA"\n3,"ES","Spain","EU"\n'

PAGES = {
    ("en.wikipedia.org", "Rafael Núñez International Airport"): AIRPORT_CTG,
    ("en.wikipedia.org", "El Dorado International Airport"): AIRPORT_BOG,
    ("en.wikipedia.org", "Miami International Airport"): AIRPORT_EMPTY,
    ("en.wikipedia.org", "Adolfo Suárez Madrid–Barajas Airport"): AIRPORT_EMPTY,
    ("en.wikipedia.org", "O'Hare International Airport"): AIRPORT_EMPTY,
    ("en.wikipedia.org", "Cartagena, Colombia"): CTG_CITY,
    ("en.wikipedia.org", "Chicago"): CHI_CITY,
    ("en.wikipedia.org", "Bogotá"): '<div class="mw-parser-output"><p>Capital.</p></div>',
    ("en.wikivoyage.org", "Cartagena (Colombia)"): VOYAGE_CTG,
}
VIEWS = {"Cartagena%2C_Colombia": 900_000, "Chicago": 3_000_000, "Bogot%C3%A1": 1_500_000}


class FakeHttp:
    def __init__(self):
        self.calls = []

    def get(self, url, params=None):
        self.calls.append((url, params))
        if url == rs.AIRPORTS_CSV:
            return AIRPORTS_CSV
        if url == rs.COUNTRIES_CSV:
            return COUNTRIES_CSV
        if url.startswith(rs.PAGEVIEWS):
            article = url.split("/user/")[1].split("/")[0]
            if article not in VIEWS:
                raise rs.CacheMiss(url)
            return json.dumps({"items": [{"views": VIEWS[article] // 12}] * 12})
        host = url.split("/")[2]
        if params["action"] == "opensearch":
            return json.dumps([params["search"], []])
        html = PAGES.get((host, params["page"]))
        if html is None:
            return json.dumps({"error": {"code": "missingtitle", "info": "no existe"}})
        return json.dumps({"parse": {"title": params["page"], "text": html}})


SEEDS = [
    rs.Seed("Cartagena", "CTG", "Cartagena, Colombia", "Cartagena (Colombia)", aliases=["Cartagena"]),
    rs.Seed("Bogotá", "BOG", "Bogotá", "Bogotá"),
    rs.Seed("Miami", "MIA", "Miami", "Miami"),
    rs.Seed("Madrid", "MAD", "Madrid", "Madrid"),
    rs.Seed("Chicago", "ORD", "Chicago", "Chicago"),
    rs.Seed("Narnia", "ZZZ", "Narnia", "Narnia"),
]


# --- Pruebas de cada pieza ----------------------------------------------------

def test_parse_airline_routes_marks_seasonal_and_skips_cargo():
    mentions = rs.parse_airline_routes(AIRPORT_CTG)
    found = {(m.airline, m.text, m.seasonal) for m in mentions}
    assert ("Avianca", "Bogotá", False) in found
    assert ("Avianca", "Medellín–JMC", False) in found
    assert ("Avianca", "Miami", True) in found
    assert ("Air Canada", "Montréal–Trudeau", True) in found
    assert ("American Airlines", "Miami", False) in found       # [3] quitado del nombre
    assert not any(m.airline == "Avianca Cargo" for m in mentions)


def test_matcher_by_title_and_alias():
    airports = rs.load_airports(FakeHttp())
    m = rs.SeedMatcher(SEEDS[:5], airports)
    assert m.match("Bogotá", "El Dorado International Airport") == "BOG"
    assert m.match("Madrid", "Madrid–Barajas Airport") == "MAD"          # título viejo -> alias
    assert m.match("New York–JFK", "John F. Kennedy International Airport") is None
    assert m.match("Montréal–Trudeau", "x") is None


def test_load_airports_prefers_scheduled_and_spanish_country():
    airports = rs.load_airports(FakeHttp())
    assert airports["BOG"]["name"] == "El Dorado International Airport"
    assert airports["MAD"]["country"] == "España"
    assert airports["CTG"]["wiki_title"] == "Rafael Núñez International Airport"


def test_parse_climate_celsius_first():
    c = rs.parse_climate(CTG_CITY)
    assert c["temp"][0] == 26.9 and c["precip"][9] == 236.5
    assert rs.best_months(c["temp"], c["precip"]) == [1, 2, 3, 4, 12]
    assert rs.climate_type(c["temp"], c["precip"], elevation_m=2, latitude=10.4) == "TROPICAL_DRY"
    assert rs.climate_type([13.0] * 12, c["precip"], elevation_m=2550, latitude=4.7) == "HIGHLAND_COLD"


def test_parse_climate_fahrenheit_first():
    c = rs.parse_climate(CHI_CITY)
    assert c["temp"][0] == -3.2 and c["temp"][6] == 24.8
    assert c["precip"][0] == 58
    assert rs.best_months(c["temp"], c["precip"]) == [6, 7, 8, 9]


def test_months_text_wraps_year():
    assert rs.months_text([1, 2, 3, 4, 12]) == "dic, ene, feb, mar, abr"
    assert rs.months_text(list(range(1, 13))) == "Todo el año"


def test_voyage_tags_only_from_useful_sections():
    secs = rs.article_sections(VOYAGE_CTG)
    assert {"understand", "get in", "see", "do", "drink"} <= set(secs)
    text = " ".join(v for k, v in secs.items() if k in rs.VOYAGE_SECTIONS)
    counts = rs.count_tags(text)
    assert counts["Playa"] == 3           # las 5 de "Get in" no cuentan
    tags = rs.tags_from_counts(counts)
    assert {"Playa", "Historia", "Museos", "Vida Nocturna", "Buceo"} <= set(tags)
    assert max(tags.values()) == 1.0
    canonical = rs.canonical_tags(tags)
    assert {"playa", "historia", "cultura", "vida_nocturna", "deportes"} <= set(canonical)
    assert all(key == rs.norm(key).replace(" ", "_") for key in canonical)
    fit = rs.traveler_fit(canonical)
    assert set(fit) == {"familia", "pareja", "amigos", "solo"} and all(0.4 <= v <= 1 for v in fit.values())
    assert fit["amigos"] > fit["solo"]


def test_prices_and_durations_are_plausible():
    km = rs.haversine_km(10.4424, -75.513, 4.70159, -74.1469)       # CTG-BOG
    assert 640 < km < 680
    assert 90 < rs.base_price_usd(km) < 120
    assert 75 < rs.flight_minutes(km) < 90
    assert 600 < rs.base_price_usd(8000) < 800                         # BOG-MAD


def test_airline_code():
    assert rs.airline_code("Avianca") == "AV"
    assert rs.airline_code("LATAM Colombia") == "LA"
    assert rs.airline_code("Aeroméxico") == "AM"
    assert rs.airline_code("Some Unknown Air") == "SU"


# --- Prueba de punta a punta ------------------------------------------------------

def test_build_dataset_end_to_end(tmp_path):
    http = FakeHttp()
    result = rs.build_dataset(http, SEEDS, date(2026, 11, 2), 14, random.Random(1), today=date(2026, 10, 31))

    assert [d["iataCode"] for d in result.destinations] == ["CTG", "BOG", "MIA", "MAD", "ORD"]
    assert any("ZZZ" in w for w in result.warnings)
    routes = {(o, a, al): s for o, a, al, s in result.routes}
    assert routes[("CTG", "BOG", "Avianca")] is False
    assert routes[("BOG", "CTG", "Avianca")] is False                  # vuelta agregada
    assert routes[("CTG", "MIA", "Avianca")] is True                   # solo estacional
    assert routes[("CTG", "MIA", "American Airlines")] is False
    assert ("BOG", "MAD", "Iberia") in routes

    ctg = result.destinations[0]
    assert ctg["countryName"] == "Colombia" and ctg["bestMonths"] == [1, 2, 3, 4, 12]
    assert "playa" in ctg["tags"] and "cultura" in ctg["tags"]
    assert all(key == key.lower() and " " not in key and "." not in key for key in ctg["tags"])
    assert set(ctg["travelerFit"]) == {"familia", "pareja", "amigos", "solo"}
    assert ctg["climateType"] == "TROPICAL_DRY"
    assert ctg["costLevel"] == 1 and ctg["visaPolicy"] == "NOT_APPLICABLE" and ctg["entryNote"] is None
    assert ctg["schemaVersion"] == 3 and ctg["imageUrl"] is None
    assert ctg["_class"].endswith("Models.Entities.Location")
    assert ctg["cheapestPrice"] > 0 and ctg["ratingCount"] > 0
    chicago = result.destinations[4]
    assert chicago["cheapestPrice"] == 0.0                              # sin rutas en los ejemplos
    assert chicago["climateType"] == "CONTINENTAL"
    assert chicago["visaPolicy"] == "VISA_REQUIRED" and chicago["entryNote"]
    assert any("ORD: ninguna ruta" in w for w in result.warnings)
    assert chicago["featured"] is True                                  # el más visitado

    ids = {d["_id"] for d in result.destinations}
    assert result.flights and all(f["departureLocationID"] in ids for f in result.flights)
    assert all(f["arrivalDate"] > f["departureDate"] for f in result.flights)
    assert all(f["departureDate"].date() >= date(2026, 11, 2) for f in result.flights)
    assert all(f["schemaVersion"] == 1 and f["_class"].endswith("Models.Entities.Flight")
               for f in result.flights)
    assert all(f["seatsLeft"] == 90 - len(f["takenSeats"]) for f in result.flights)
    assert all(f["durationMinutes"] > 0 and f["scales"] == 0 and f["aircraft"] for f in result.flights)
    assert all(f["basePrice"] >= f["ticketPrice"] for f in result.flights)
    assert all(("offerValidUntil" in f) == f["discounted"] for f in result.flights)
    seasonal = [f for f in result.flights if f["airline"] == "Avianca" and
                f["arrivalLocationID"] == result.destinations[2]["_id"]]
    assert len(seasonal) == 4                                           # 2 por semana x 2 semanas

    rs.write_json(result, tmp_path)
    flights = json.loads((tmp_path / "flights.json").read_text(encoding="utf-8"))
    assert "$oid" in flights[0]["_id"] and flights[0]["departureDate"]["$date"].endswith("Z")
    assert "scrapedAt" not in flights[0]
    destinations = json.loads((tmp_path / "destinations.json").read_text(encoding="utf-8"))
    assert "secret" not in destinations[0] and "activities" not in destinations[0]
    assert destinations[0]["updatedAt"]["$date"].endswith("Z")
    assert (tmp_path / "rutas.csv").read_text(encoding="utf-8").startswith("origen,destino")


def test_same_seed_same_flights():
    a = rs.build_dataset(FakeHttp(), SEEDS[:2], date(2026, 11, 2), 7, random.Random(5), today=date(2026, 10, 31))
    b = rs.build_dataset(FakeHttp(), SEEDS[:2], date(2026, 11, 2), 7, random.Random(5), today=date(2026, 10, 31))
    strip = lambda fs: [(f["flightNumber"], f["ticketPrice"], f["departureDate"]) for f in fs]
    assert strip(a.flights) == strip(b.flights)
