"""Pruebas sin red: usan mongomock y datos sintéticos con la misma forma que los reales."""
from datetime import datetime, timedelta

import mongomock
import pytest
from bson import ObjectId

from recommender import api
from recommender.batch import POPULAR_ID, run
from recommender.config import Settings
from recommender.data import load_dataset, load_preferences
from recommender.evaluate import evaluate
from recommender.scoring import Recommender
from recommender.seasons import months_from_value, season_score

NOW = datetime(2026, 10, 28)
BEACHES = ["Playa Uno", "Playa Dos", "Playa Tres", "Playa Cuatro"]
CULTURE = ["Cultura Uno", "Cultura Dos", "Cultura Tres", "Cultura Cuatro"]
OTHER = ["Monte Uno", "Monte Dos"]

# Mismos pesos que el catálogo real (Location.tags es {etiqueta: peso 0-1}).
BEACH_TAGS = {"Playa": 0.95, "Buceo": 0.8, "Vida Nocturna": 0.7}
CULTURE_TAGS = {"Historia": 0.85, "Museos": 0.8, "Arte": 0.9}
OTHER_TAGS = {"Senderismo": 0.9, "Naturaleza": 0.85}


def make_db():
    db = mongomock.MongoClient()["test"]
    ids = {}
    spec = (
        [(n, BEACH_TAGS, [12, 1, 2, 3], {"pareja": 0.9, "familia": 0.6}) for n in BEACHES]
        + [(n, CULTURE_TAGS, list(range(1, 13)), {"familia": 0.9, "pareja": 0.7}) for n in CULTURE]
        + [(n, OTHER_TAGS, [6, 7, 8], {"amigos": 0.85, "solo": 0.8}) for n in OTHER]
    )
    for name, tags, months, fit in spec:
        ids[name] = ObjectId()
        db["Destinations"].insert_one({
            "_id": ids[name], "cityName": name, "iataCode": name[:3].upper(),
            "tags": tags, "bestMonths": months,
            "travelerFit": fit, "cheapestPrice": 100.0, "rating": 4.0,
            "ratingCount": 30, "featured": False, "status": "ACTIVE",
        })
    ids["Oculto"] = ObjectId()
    db["Destinations"].insert_one({"_id": ids["Oculto"], "cityName": "Oculto", "iataCode": "OCU",
                                   "tags": {"Playa": 1.0}, "bestMonths": [], "ratingCount": 0,
                                   "status": "HIDDEN"})

    flights = {}
    for name in ids:
        flights[name] = ObjectId()
        db["Flights"].insert_one({
            "_id": flights[name], "arrivalLocationID": str(ids[name]), "departureLocationID": "origen",
            "ticketPrice": 100.0, "departureDate": datetime(2027, 1, 15), "status": "ACTIVE",
            "discounted": False, "discountPercentage": 0,
        })

    def book(user, dest, days_ago):
        db["Booking"].insert_one({
            "userID": user, "bookedFlightID": str(flights[dest]), "status": "CONFIRMED",
            "bookingDate": NOW - timedelta(days=days_ago), "totalPrice": 100.0, "ticketCount": 1,
        })

    for u in range(8):                      # amantes de playa: 3 playas distintas cada uno
        for k in range(3):
            book(f"beach{u}", BEACHES[(u + k) % 4], 300 - 100 * k)
    for u in range(8):                      # amantes de cultura
        for k in range(3):
            book(f"culture{u}", CULTURE[(u + k) % 4], 300 - 100 * k)
    db["Booking"].insert_one({"userID": "x", "bookedFlightID": str(flights["Playa Uno"]),
                              "status": "PENDING", "bookingDate": NOW, "totalPrice": 1, "ticketCount": 1})

    # Preferencias declaradas (UserPreferences): el _id ES el userID (igual que la
    # base real, donde el @Id de la entidad Java es el _id del documento).
    db["UserPreferences"].insert_one({
        "_id": "pref0", "interests": ["Playa", "Buceo"], "budgetMax": 800_000,
        "preferredMonths": [6, 7, 8], "travelCompany": "pareja",
        "excludedLocationIds": [str(ids["Playa Uno"])],
    })
    db["UserPreferences"].insert_one({
        "_id": "fit1", "interests": ["Senderismo"], "travelCompany": "amigos",
    })
    return db, ids


def test_months_from_value_esquema_v3():
    assert months_from_value([12, 1, 2, 3]) == {12, 1, 2, 3}
    assert months_from_value([]) == set()
    assert months_from_value(None) == set()
    assert months_from_value([0, 13, 5]) == {5}         # fuera de rango se ignora


def test_season_score():
    assert season_score({12, 1, 2, 3}, 12) == 1.0
    assert season_score({12, 1, 2, 3}, 4) == 0.5     # mes contiguo
    assert season_score({12, 1, 2, 3}, 7) == 0.0
    assert season_score(set(), 7) == 0.5             # sin dato: neutro


def test_presupuesto_cop_se_pasa_a_usd():
    db, _ = make_db()
    prefs = load_preferences(db, "UserPreferences", cop_usd_rate=4000.0)
    assert prefs["pref0"]["budget_usd"] == pytest.approx(200.0)     # 800.000 COP / 4000
    assert prefs["pref0"]["travel_company"] == "pareja"
    assert prefs["pref0"]["preferred_months"] == [6, 7, 8]
    assert prefs["fit1"]["budget_usd"] is None


def test_batch_personaliza_y_guarda_popular():
    db, ids = make_db()
    result = run(Settings(), db=db, as_of=NOW)
    assert result["personalized_users"] == 18    # 8 beach + 8 culture + pref0 + fit1
    assert db["UserRecommendations"].find_one({"_id": POPULAR_ID}) is not None

    beach_ids = {str(ids[n]) for n in BEACHES}
    culture_ids = {str(ids[n]) for n in CULTURE}
    top_beach = db["UserRecommendations"].find_one({"_id": "beach0"})["items"][0]
    top_culture = db["UserRecommendations"].find_one({"_id": "culture0"})["items"][0]
    assert top_beach["locationID"] in beach_ids
    assert top_culture["locationID"] in culture_ids
    assert "TAG_MATCH" in top_beach["reasons"]
    assert "fit" in top_beach["components"]


def test_destino_excluido_nunca_se_recomienda():
    db, ids = make_db()
    run(Settings(), db=db, as_of=NOW)
    doc = db["UserRecommendations"].find_one({"_id": "pref0"})
    assert doc is not None
    assert str(ids["Playa Uno"]) not in {i["locationID"] for i in doc["items"]}


def test_companion_fit_explica_el_encaje():
    db, _ = make_db()
    run(Settings(), db=db, as_of=NOW)
    # fit1 viaja con amigos: los Monte tienen amigos=0.85 y llevan la razón.
    top = db["UserRecommendations"].find_one({"_id": "fit1"})["items"][0]
    assert "COMPANION_FIT" in top["reasons"]
    # beach0 no declaró compañía: nunca explica encaje.
    for item in db["UserRecommendations"].find_one({"_id": "beach0"})["items"]:
        assert "COMPANION_FIT" not in item["reasons"]


def test_rating_count_cero_no_infla_populares():
    db = mongomock.MongoClient()["test"]
    # Sin reservas: la popularidad sale del rating, y el 3.0 con ratingCount 0 no cuenta.
    for name, rating, votes in (("Sin Votos", 3.0, 0), ("Con Votos", 4.5, 12)):
        oid = ObjectId()
        db["Destinations"].insert_one({
            "_id": oid, "cityName": name, "iataCode": name[:3].upper(),
            "tags": {"Playa": 1.0}, "bestMonths": list(range(1, 13)), "travelerFit": {},
            "cheapestPrice": 100.0, "rating": rating, "ratingCount": votes,
            "featured": False, "status": "ACTIVE",
        })
        db["Flights"].insert_one({
            "_id": ObjectId(), "arrivalLocationID": str(oid), "departureLocationID": "origen",
            "ticketPrice": 100.0, "departureDate": datetime(2027, 1, 15), "status": "ACTIVE",
            "discounted": False, "discountPercentage": 0,
        })
    run(Settings(), db=db, as_of=NOW)
    items = db["UserRecommendations"].find_one({"_id": POPULAR_ID})["items"]
    assert [i["cityName"] for i in items] == ["Con Votos", "Sin Votos"]


def test_lista_ordenada_por_puntaje_mostrado():
    db, _ = make_db()
    run(Settings(), db=db, as_of=NOW)
    for doc in db["UserRecommendations"].find({}):
        scores = [i["score"] for i in doc["items"]]
        assert scores == sorted(scores, reverse=True), doc["_id"]


def test_puntajes_normalizados_entre_0_y_1():
    """La afinidad es coseno (matriz con filas unitarias): ningún puntaje puede pasar de 1."""
    db, _ = make_db()
    run(Settings(), db=db, as_of=NOW)
    for doc in db["UserRecommendations"].find({}):
        for item in doc["items"]:
            assert 0.0 <= item["score"] <= 1.0, (doc["_id"], item)


def test_destino_oculto_nunca_se_recomienda():
    db, ids = make_db()
    run(Settings(), db=db, as_of=NOW)
    for doc in db["UserRecommendations"].find({}):
        assert str(ids["Oculto"]) not in {i["locationID"] for i in doc["items"]}


def test_ejecutar_dos_veces_no_duplica():
    db, _ = make_db()
    run(Settings(), db=db, as_of=NOW)
    first = db["UserRecommendations"].count_documents({})
    run(Settings(), db=db, as_of=NOW)
    assert db["UserRecommendations"].count_documents({}) == first


def test_dry_run_no_escribe():
    db, _ = make_db()
    run(Settings(), db=db, as_of=NOW, dry_run=True)
    assert db["UserRecommendations"].count_documents({}) == 0


def test_modelo_supera_a_populares():
    db, _ = make_db()
    s = Settings()
    data = load_dataset(db, s)
    rec = Recommender(data.destinations, data.flights, data.bookings, s)
    result = evaluate(rec, data.bookings)
    assert result["model"]["n"] == 16
    assert result["model"]["hit@3"] >= 0.9
    assert result["model"]["hit@3"] > result["popular_baseline"]["hit@3"]


def test_api_exige_clave(monkeypatch):
    from fastapi.testclient import TestClient
    monkeypatch.setattr(api, "settings", Settings(internal_api_key="secreta"))
    monkeypatch.setattr(api, "_job", lambda: None)
    client = TestClient(api.app)
    assert client.get("/health").json() == {"status": "ok"}
    assert client.post("/recalcular").status_code == 401
    assert client.post("/recalcular", headers={"X-API-Key": "secreta"}).status_code == 202


def test_api_recalcula_un_usuario_al_vuelo(monkeypatch):
    """El recálculo on-demand guarda la lista nueva y borra la obsoleta si ya no hay señal."""
    from fastapi.testclient import TestClient
    db, ids = make_db()
    monkeypatch.setattr(api, "settings", Settings(internal_api_key="secreta"))
    monkeypatch.setattr(api, "_db", lambda: db)
    client = TestClient(api.app)
    headers = {"X-API-Key": "secreta"}

    # beach0 tiene historial: recalcula al vuelo y guarda con sus intereses actuales.
    res = client.post("/recomendaciones/beach0", headers=headers)
    assert res.status_code == 200
    body = res.json()
    assert body["saved"] is True
    assert body["doc"]["_id"] == "beach0"
    assert db["UserRecommendations"].find_one({"_id": "beach0"}) is not None

    # Borrar sus preferencias (simula el PUT del backend) deja la lista obsoleta; al
    # recalcular a popular, el endpoint la elimina para que sirva __popular__.
    db["UserPreferences"].delete_one({"_id": "fit1"})
    res = client.post("/recomendaciones/fit1", headers=headers)
    assert res.json()["saved"] is False
    assert db["UserRecommendations"].find_one({"_id": "fit1"}) is None

    # Un usuario sin nada (ni reservas ni preferencias) también queda en popular.
    res = client.post("/recomendaciones/nadie", headers=headers)
    assert res.json() == {"saved": False, "strategy": "popular"}
