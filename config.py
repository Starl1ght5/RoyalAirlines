"""Configuración del recomendador.

Las credenciales salen de variables de entorno (las mismas que usa Spring);
los hiperparámetros del modelo son campos con valor por defecto que se pueden
sobrescribir al crear `Settings(...)`, por ejemplo en las pruebas.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv

# Carga recommender/.env sin importar desde qué carpeta ejecutes el comando.
# override=False: si una variable ya está exportada en la terminal, esa gana.
load_dotenv(Path(__file__).resolve().parent / ".env", override=False)

@dataclass(frozen=True)
class Settings:
    mongo_uri: str = "mongodb://localhost:27017"
    mongo_db: str = "royal_airlines"
    out_collection: str = "UserRecommendations"
    prefs_collection: str = "UserPreferences"
    internal_api_key: str = ""

    # Si se define (p. ej. http://localhost:8080), las listas se empujan a
    # POST /internal/recommendations/bulk con X-API-Key en vez de escribir MongoDB
    # directamente. Vacío = escritura directa (opción 2 del contrato).
    spring_internal_url: str = ""

    # Tasa del backend (MoneyExchange.COP_EXCHANGE_RATE): UserPreferences.budgetMax
    # está en COP y el puntaje de presupuesto trabaja en USD, como Flight.ticketPrice.
    cop_usd_rate: float = 4000.0

    model_version: str = "content-v1"
    top_k: int = 10

    # Peso de cada componente del puntaje (suman 1).
    weights: dict[str, float] = field(
        default_factory=lambda: {"affinity": 0.5, "budget": 0.2, "season": 0.2, "offer": 0.1}
    )
    # Multiplicador final por encaje destino-compañía (Location.travelerFit con el
    # travelCompany declarado): no entra en los pesos, ajusta el puntaje total.
    companion_weight: float = 0.15
    half_life_days: float = 365.0   # una reserva pierde la mitad de su peso en un año
    lead_days: int = 45             # con cuánta anticipación se supone que viaja el usuario
    repeat_penalty: float = 0.7     # multiplicador para destinos que el usuario ya visitó
    interest_weight: float = 0.3    # peso de los intereses declarados frente al historial

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            mongo_uri=os.getenv("DB_URI", "mongodb://localhost:27017"),
            mongo_db=os.getenv("DB_DATABASE", "royal_airlines"),
            out_collection=os.getenv("RECS_COLLECTION", "UserRecommendations"),
            prefs_collection=os.getenv("PREFS_COLLECTION", "UserPreferences"),
            internal_api_key=os.getenv("INTERNAL_API_KEY", ""),
            spring_internal_url=os.getenv("SPRING_INTERNAL_URL", "").rstrip("/"),
            cop_usd_rate=float(os.getenv("COP_USD_RATE", "4000")),
        )
