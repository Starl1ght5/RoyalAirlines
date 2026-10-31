"""Lectura de MongoDB. El recomendador solo LEE estas colecciones.

Esquema actual (el del backup 2026-10-29, esquema recortado del MVP):
  Destinations: cityName, iataCode, tags{etiqueta: peso 0-1}, bestMonths[1-12],
                cheapestPrice, rating + ratingCount (rating se ignora si ratingCount es 0),
                featured, status ('ACTIVE'/'HIDDEN')
  Flights:      departureLocationID, arrivalLocationID, ticketPrice, departureDate,
                discounted, discountPercentage, status
  Booking:      userID, bookedFlightID, bookingDate, totalPrice, ticketCount, status
  UserPreferences: interests[], budgetMax (COP), preferredMonths[1-12],
                   travelCompany, excludedLocationIds[]; el _id ES el userID

Los campos previos al recorte (activities, bestDate, climate) ya no se usan:
el backup garantiza bestMonths, tags, ratingCount y travelerFit en todos los
destinos, así que no hay red que mantener.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass

import pandas as pd
from pymongo import MongoClient
from pymongo.database import Database

from .config import Settings
from .seasons import months_from_value

log = logging.getLogger(__name__)

# Solo las reservas pagadas cuentan como gusto del usuario. PENDING puede
# expirar a los 15 minutos y CANCELED es una señal distinta.
POSITIVE_STATUSES = ("CONFIRMED",)

DEST_COLS = ["location_id", "city", "iata", "tags", "best_months", "cheapest_price",
             "rating", "rating_count", "featured", "traveler_fit"]
FLIGHT_COLS = ["flight_id", "dep_id", "arr_id", "price", "departure",
               "discounted", "discount_pct", "active"]
BOOKING_COLS = ["booking_id", "user_id", "flight_id", "booking_date",
                "total_price", "ticket_count"]


@dataclass
class Dataset:
    destinations: pd.DataFrame
    flights: pd.DataFrame
    bookings: pd.DataFrame     # reservas confirmadas, con dest_id y ticket_price
    preferences: dict[str, dict]


def connect(settings: Settings) -> Database:
    return MongoClient(settings.mongo_uri, serverSelectionTimeoutMS=5000)[settings.mongo_db]


def _s(value) -> str | None:
    return None if value is None else str(value)


def load_destinations(db: Database) -> pd.DataFrame:
    rows = []
    for d in db["Destinations"].find({}):
        if str(d.get("status", "")).upper() == "HIDDEN":
            continue
        rows.append({
            "location_id": _s(d["_id"]),
            "city": d.get("cityName", ""),
            "iata": d.get("iataCode", ""),
            # tags es siempre un mapa {etiqueta: peso 0-1} en el esquema actual.
            "tags": {str(tag): float(weight) for tag, weight in (d.get("tags") or {}).items()},
            "best_months": sorted(months_from_value(d.get("bestMonths"))),
            "cheapest_price": float(d.get("cheapestPrice") or 0),
            "rating": float(d.get("rating") or 0),
            # Con ratingCount = 0 el rating es un valor por defecto (MAD, LHR, JFK):
            # se trata como 0 para que no infle la popularidad de nadie.
            "rating_count": int(d.get("ratingCount") or 0),
            "featured": bool(d.get("featured", False)),
            "traveler_fit": {str(k): float(v) for k, v in (d.get("travelerFit") or {}).items()},
        })
    return pd.DataFrame(rows, columns=DEST_COLS)


def load_flights(db: Database) -> pd.DataFrame:
    rows = []
    for f in db["Flights"].find({}):
        rows.append({
            "flight_id": _s(f["_id"]),
            "dep_id": _s(f.get("departureLocationID")),
            "arr_id": _s(f.get("arrivalLocationID")),
            "price": float(f.get("ticketPrice") or 0),
            "departure": f.get("departureDate"),
            "discounted": bool(f.get("discounted", False)),
            "discount_pct": float(f.get("discountPercentage") or 0),
            "active": str(f.get("status", "ACTIVE")).upper() == "ACTIVE",
        })
    df = pd.DataFrame(rows, columns=FLIGHT_COLS)
    df["departure"] = pd.to_datetime(df["departure"], errors="coerce")
    return df


def load_bookings(db: Database, flights: pd.DataFrame) -> pd.DataFrame:
    """Reservas confirmadas unidas a su vuelo para saber el destino y el precio."""
    rows = []
    for b in db["Booking"].find({"status": {"$in": list(POSITIVE_STATUSES)}}):
        rows.append({
            "booking_id": _s(b["_id"]),
            "user_id": _s(b.get("userID")),
            "flight_id": _s(b.get("bookedFlightID")),
            "booking_date": b.get("bookingDate"),
            "total_price": float(b.get("totalPrice") or 0),
            "ticket_count": int(b.get("ticketCount") or 1),
        })
    df = pd.DataFrame(rows, columns=BOOKING_COLS)
    df["booking_date"] = pd.to_datetime(df["booking_date"], errors="coerce")

    df = df.merge(flights[["flight_id", "arr_id", "price"]], on="flight_id", how="left")
    before = len(df)
    df = df.dropna(subset=["user_id", "arr_id", "booking_date"])
    if len(df) < before:
        log.warning("%d reservas descartadas (sin usuario, vuelo o fecha válidos)", before - len(df))

    df = df.rename(columns={"arr_id": "dest_id", "price": "ticket_price"})
    per_ticket = df["total_price"] / df["ticket_count"].clip(lower=1)
    df["ticket_price"] = df["ticket_price"].where(df["ticket_price"] > 0, per_ticket)
    return df.sort_values("booking_date").reset_index(drop=True)


def load_preferences(db: Database, collection: str, cop_usd_rate: float = 4000.0) -> dict[str, dict]:
    """Preferencias declaradas (UserPreferences). Si no existe la colección devuelve {}.

    El _id del documento ES el userID (el mismo @Id de la entidad Java); no hay
    campo userId separado. El presupuesto llega en COP y se pasa a USD porque el
    resto del pipeline —ticketPrice, cheapestPrice— está en dólares.
    """
    if collection not in db.list_collection_names():
        return {}
    prefs: dict[str, dict] = {}
    for p in db[collection].find({}):
        uid = _s(p["_id"])
        budget_cop = p.get("budgetMax")
        prefs[uid] = {
            "interests": [str(i) for i in (p.get("interests") or [])],
            "budget_usd": (float(budget_cop) / cop_usd_rate) if budget_cop else None,
            "preferred_months": [int(m) for m in (p.get("preferredMonths") or [])],
            "travel_company": str(p.get("travelCompany") or "") or None,
            "excluded_location_ids": [str(x) for x in (p.get("excludedLocationIds") or [])],
        }
    return prefs


def load_dataset(db: Database, settings: Settings) -> Dataset:
    flights = load_flights(db)
    return Dataset(
        destinations=load_destinations(db),
        flights=flights,
        bookings=load_bookings(db, flights),
        preferences=load_preferences(db, settings.prefs_collection, settings.cop_usd_rate),
    )
