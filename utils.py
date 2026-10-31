"""Utilidades pequeñas compartidas por varios módulos."""
from __future__ import annotations

import re
import unicodedata
from datetime import datetime, timezone


def strip_accents(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn")


def normalize_tag(tag: str) -> str:
    """'Vida Nocturna' -> 'vida_nocturna'; 'Gastronomía' -> 'gastronomia'."""
    return re.sub(r"\s+", "_", strip_accents(tag).strip().lower())


def utcnow() -> datetime:
    """Fecha actual en UTC y sin zona horaria, igual que devuelve pymongo."""
    return datetime.now(timezone.utc).replace(tzinfo=None)
