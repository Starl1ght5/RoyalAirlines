"""Job que recalcula las recomendaciones de todos los usuarios con señal.

    python -m recommender.batch --dry-run        # calcula y muestra, no escribe
    python -m recommender.batch                  # calcula y guarda

Escribe un documento por usuario con historial o preferencias, más uno
especial con _id '__popular__'. Spring lee primero el del usuario y, si no
existe, el '__popular__'.

Escritura según el contrato elegido (opciones 1 y 2 del documento de
reestructuración):
  - sin SPRING_INTERNAL_URL (opción 2): escritura directa en la colección
    UserRecommendations con el usuario de Mongo del .env (solo lectura en el
    resto, escritura aquí);
  - con SPRING_INTERNAL_URL (opción 1): las listas se empujan a
    POST /internal/recommendations/bulk con X-API-Key y Python no toca la base.
"""
from __future__ import annotations

import argparse
import json
import logging
from datetime import datetime

import pandas as pd
from pymongo.database import Database

from .config import Settings
from .data import connect, load_dataset
from .scoring import Recommender, UserContext, new_recommendation_id
from .utils import utcnow
from .writer import mongo_id, push_recommendations, save_recommendations

log = logging.getLogger(__name__)
POPULAR_ID = "__popular__"


def build_context(bookings: pd.DataFrame, prefs: dict[str, dict], uid: str,
                  as_of: datetime) -> UserContext | None:
    """Contexto de UN usuario; None si no tiene ni reservas ni preferencias.

    Compartida por el job completo y por el recálculo on-demand
    (POST /recomendaciones/{user_id}) que dispara Spring al actualizar preferencias.
    """
    declared = prefs.get(uid, {})
    g = bookings[(bookings["user_id"] == uid) & (bookings["booking_date"] <= as_of)]
    if g.empty and not declared:
        return None
    history = list(zip(g["dest_id"], g["booking_date"])) if not g.empty else []
    prices = g["ticket_price"][g["ticket_price"] > 0] if not g.empty else []
    ref = float(prices.median()) if len(prices) else declared.get("budget_usd")
    return UserContext(
        history=history,
        interests=declared.get("interests", []),
        ref_price=ref,
        preferred_months=declared.get("preferred_months", []),
        travel_company=declared.get("travel_company"),
        excluded=set(declared.get("excluded_location_ids", [])),
        as_of=as_of,
    )


def build_contexts(bookings: pd.DataFrame, prefs: dict[str, dict], as_of: datetime) -> dict[str, UserContext]:
    """Un UserContext por cada usuario que tenga reservas o preferencias declaradas."""
    uids = set(bookings["user_id"].dropna().unique()) | set(prefs)
    contexts: dict[str, UserContext] = {}
    for uid in uids:
        ctx = build_context(bookings, prefs, uid, as_of)
        if ctx is not None:
            contexts[uid] = ctx
    return contexts


def make_doc(user_id: str, strategy: str, items: list[dict], as_of: datetime, settings: Settings) -> dict:
    return {
        "_id": mongo_id(user_id),
        "strategy": strategy,
        "modelVersion": settings.model_version,
        "recommendationID": new_recommendation_id(),
        "generatedAt": utcnow(),
        "asOf": as_of,
        "items": items,
    }


def run(settings: Settings, db: Database | None = None, as_of: datetime | None = None,
        limit: int | None = None, dry_run: bool = False) -> dict:
    db = db if db is not None else connect(settings)
    as_of = as_of or utcnow()

    data = load_dataset(db, settings)
    rec = Recommender(data.destinations, data.flights, data.bookings, settings)
    log.info("Destinos: %d | vuelos: %d | reservas confirmadas: %d",
             len(rec.ids), len(data.flights), len(data.bookings))

    strategy, items = rec.recommend(UserContext(as_of=as_of))
    docs = [make_doc(POPULAR_ID, strategy, items, as_of, settings)]

    contexts = build_contexts(data.bookings, data.preferences, as_of)
    for uid in sorted(contexts)[:limit]:
        strategy, items = rec.recommend(contexts[uid])
        if strategy == "popular":      # sin señal propia: le sirve el documento __popular__
            continue
        docs.append(make_doc(uid, strategy, items, as_of, settings))

    if dry_run:
        written = 0
    elif settings.spring_internal_url:
        written = push_recommendations(settings, docs)
    else:
        written = save_recommendations(db, settings.out_collection, docs)
    return {"destinations": len(rec.ids), "personalized_users": len(docs) - 1,
            "written": written, "dry_run": dry_run, "docs": docs}


def main() -> None:
    parser = argparse.ArgumentParser(description="Recalcula las recomendaciones")
    parser.add_argument("--dry-run", action="store_true", help="calcula y muestra, sin escribir")
    parser.add_argument("--limit", type=int, help="procesa solo N usuarios")
    parser.add_argument("--as-of", help="fecha de referencia YYYY-MM-DD (por defecto, ahora)")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    as_of = datetime.strptime(args.as_of, "%Y-%m-%d") if args.as_of else None
    result = run(Settings.from_env(), as_of=as_of, limit=args.limit, dry_run=args.dry_run)

    docs = result.pop("docs")
    log.info("Resumen: %s", result)
    if args.dry_run:
        print(json.dumps(docs[:2], default=str, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
