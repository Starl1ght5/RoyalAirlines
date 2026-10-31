"""API mínima para operar el recomendador. Solo para uso interno (la llama Spring o un cron).

    uvicorn recommender.api:app --port 8001

GET  /health                       sin autenticación
POST /recalcular                   dispara el job en segundo plano (X-API-Key)
POST /recomendaciones/{user_id}    recalcula UN usuario al vuelo y guarda (X-API-Key);
                                   lo llama Spring cuando el usuario cambia sus preferencias
GET  /recomendaciones/{user_id}    lee lo guardado, para depurar (X-API-Key)
"""
from __future__ import annotations

import hmac
import logging
import threading
from functools import lru_cache

from fastapi import BackgroundTasks, Depends, FastAPI, Header, HTTPException
from fastapi.encoders import jsonable_encoder
from bson import ObjectId

from .batch import POPULAR_ID, build_context, make_doc, run
from .config import Settings
from .data import connect, load_dataset
from .scoring import Recommender
from .utils import utcnow
from .writer import mongo_id, save_recommendations

log = logging.getLogger(__name__)
settings = Settings.from_env()
app = FastAPI(title="Recomendador Royal Airlines")
_running = threading.Lock()


@lru_cache(maxsize=1)
def _db():
    return connect(settings)


def require_key(x_api_key: str = Header(default="")) -> None:
    if not settings.internal_api_key:
        raise HTTPException(503, "INTERNAL_API_KEY no está configurada")
    if not hmac.compare_digest(x_api_key.encode(), settings.internal_api_key.encode()):
        raise HTTPException(401, "API key inválida")


def _job() -> None:
    if not _running.acquire(blocking=False):
        log.warning("Ya hay un cálculo en curso; se ignora esta petición")
        return
    try:
        summary = run(settings)
        summary.pop("docs", None)
        log.info("Cálculo terminado: %s", summary)
    except Exception:
        log.exception("Falló el cálculo de recomendaciones")
    finally:
        _running.release()


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/recalcular", status_code=202, dependencies=[Depends(require_key)])
def recalcular(background: BackgroundTasks) -> dict:
    if _running.locked():
        raise HTTPException(409, "Ya hay un cálculo en curso")
    background.add_task(_job)
    return {"status": "aceptado"}


@app.post("/recomendaciones/{user_id}", dependencies=[Depends(require_key)])
def recalcular_usuario(user_id: str) -> dict:
    """Recalcula y guarda la lista de UN usuario con sus preferencias actuales.

    Spring lo llama después de actualizar o borrar UserPreferences (con un timeout
    corto); si este servicio no responde, la app sirve `__popular__` y el job
    nocturno lo arregla. Si el usuario queda sin señal propia, se borra su documento
    para que deje de servirse una lista desactualizada.
    """
    db = _db()
    as_of = utcnow()
    data = load_dataset(db, settings)
    rec = Recommender(data.destinations, data.flights, data.bookings, settings)

    ctx = build_context(data.bookings, data.preferences, user_id, as_of)
    strategy, items = (rec.recommend(ctx) if ctx is not None else ("popular", []))

    if strategy == "popular":
        # Borra ambas formas de _id (ObjectId nuevo y string legado).
        db[settings.out_collection].delete_many(
            {"_id": {"$in": [mongo_id(user_id), user_id]}}
        )
        log.info("Usuario %s sin señal propia: se sirve __popular__", user_id)
        return {"saved": False, "strategy": strategy}

    doc = make_doc(user_id, strategy, items, as_of, settings)
    save_recommendations(db, settings.out_collection, [doc])
    log.info("Usuario %s recalculado al vuelo: %d destinos (%s)", user_id, len(items), strategy)
    return {"saved": True, "doc": jsonable_encoder(doc, custom_encoder={ObjectId: str})}


@app.get("/recomendaciones/{user_id}", dependencies=[Depends(require_key)])
def ver(user_id: str) -> dict:
    col = _db()[settings.out_collection]
    # Preferencia al _id ObjectId (el que consulta Spring); el string
    # legado queda como respaldo mientras existan documentos viejos.
    doc = (col.find_one({"_id": mongo_id(user_id)})
           or col.find_one({"_id": user_id})
           or col.find_one({"_id": POPULAR_ID}))
    if doc is None:
        raise HTTPException(404, "Aún no hay recomendaciones calculadas")
    return jsonable_encoder(doc, custom_encoder={ObjectId: str})
