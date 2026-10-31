"""Escritura de resultados: vía Spring (bulk interno) o directa en MongoDB.

Es lo único que el recomendador escribe; el resto de colecciones solo se leen.
"""
from __future__ import annotations

import json
import logging
from datetime import date, datetime
from urllib import request as urlrequest

from bson import ObjectId
from pymongo.database import Database

from .config import Settings

log = logging.getLogger(__name__)


def mongo_id(value: str):
    """`_id` canónico de UserRecommendations.

    Spring Data guarda Y consulta hex de 24 caracteres como ObjectId
    (así funciona UserPreferences pese a `@Id String`): si Python
    guarda el id como string puro, el `findById` de Spring no matchea
    el documento y sirve `__popular__`. Los ids no-hex (p. ej.
    `__popular__`) se quedan como string.
    """
    return ObjectId(value) if ObjectId.is_valid(value) else value


def save_recommendations(db: Database, collection: str, docs: list[dict]) -> int:
    """Reemplaza (o crea) un documento por usuario. Idempotente: repetir el job no duplica nada.

    Un `replace_one` por documento es suficiente para un job nocturno con miles de
    usuarios. Si llegas a cientos de miles, cámbialo por `bulk_write` con `ReplaceOne`.
    """
    col = db[collection]
    for doc in docs:
        col.replace_one({"_id": doc["_id"]}, doc, upsert=True)
        # Gemelo string legado (antes de guardar ids como ObjectId):
        # sin retirarlo convivirían dos docs y Spring vería solo este.
        if not isinstance(doc["_id"], str):
            col.delete_one({"_id": str(doc["_id"])})
    return len(docs)


def push_recommendations(settings: Settings, docs: list[dict]) -> int:
    """Envía las listas a `POST /internal/recommendations/bulk` con X-API-Key.

    Es la opción 1 del contrato: Python no toca MongoDB, solo Spring escribe.
    Los datetimes van como ISO-8601, que es como los parsea el DTO de Java.
    """
    body = json.dumps(docs, default=_iso).encode("utf-8")
    call = urlrequest.Request(
        f"{settings.spring_internal_url}/internal/recommendations/bulk",
        data=body,
        headers={
            "Content-Type": "application/json",
            "X-API-Key": settings.internal_api_key,
        },
        method="POST",
    )
    try:
        with urlrequest.urlopen(call, timeout=60) as response:
            result = json.loads(response.read().decode("utf-8"))
    except OSError as error:
        raise RuntimeError(
            f"Spring rechazó el bulk ({error}); revisa SPRING_INTERNAL_URL e INTERNAL_API_KEY"
        ) from error

    saved = int(result.get("saved", len(docs)))
    log.info("Bulk enviado a Spring: %d listas guardadas", saved)
    return saved


def _iso(value):
    """Serializador para json.dumps: fechas como ISO-8601, como espera Java."""
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return str(value)
