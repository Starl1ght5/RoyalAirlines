"""Convierte `bestMonths` en meses y puntúa la temporada.

En el esquema actual `Location.bestMonths` es siempre una lista de números de
mes ([1..12]); no hay texto libre que parsear.
"""
from __future__ import annotations

from datetime import datetime, timedelta


def months_from_value(value) -> set[int]:
    """Normaliza `Location.bestMonths` a un conjunto de meses 1-12.

    Valores no numéricos o fuera de rango se ignoran; sin dato devuelve
    conjunto vacío (la temporada se trata como neutra).
    """
    if value is None:
        return set()
    return {int(m) for m in value if isinstance(m, (int, float)) and 1 <= int(m) <= 12}


def season_score(months: set[int], month: int) -> float:
    """1.0 si el mes está en temporada, 0.5 si es contiguo, 0.0 si no; 0.5 sin dato."""
    if not months:
        return 0.5
    if len(months) == 12 or month in months:
        return 1.0
    previous, following = (month - 2) % 12 + 1, month % 12 + 1
    return 0.5 if {previous, following} & months else 0.0


def target_month(as_of: datetime, lead_days: int) -> int:
    """Mes en el que se supone que el usuario viajará."""
    return (as_of + timedelta(days=lead_days)).month
