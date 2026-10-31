"""Vectores de destinos (etiquetas ponderadas con IDF) y perfil del usuario.

`Location.tags` es un mapa {etiqueta: peso 0-1} en todo el catálogo actual.
"""
from __future__ import annotations

from datetime import datetime

import numpy as np

from .utils import normalize_tag


def unit(v: np.ndarray) -> np.ndarray | None:
    """Normaliza a longitud 1; None si el vector es todo ceros (sin señal)."""
    norm = float(np.linalg.norm(v))
    return v / norm if norm > 0 else None


class TagSpace:
    """Matriz destino x etiqueta con los pesos declarados en cada destino.

    Se pondera con IDF: una etiqueta que casi todos los destinos tienen
    (p. ej. «Gastronomía») distingue poco, y una rara (p. ej. «Buceo») mucho.
    Cada fila queda normalizada, así que el producto punto con un perfil
    unitario es directamente la similitud coseno.
    """

    def __init__(self, tags_per_item: list[dict[str, float]]):
        index: dict[str, int] = {}
        row_weights: list[dict[int, float]] = []

        for tags in tags_per_item:
            weights: dict[int, float] = {}
            for tag, weight in tags.items():
                if not tag or weight is None:
                    continue
                j = index.setdefault(normalize_tag(str(tag)), len(index))
                weights[j] = max(weights.get(j, 0.0), float(weight))  # repetida: gana la mayor
            row_weights.append(weights)

        n_items, n_terms = len(row_weights), len(index)
        binary = np.zeros((n_items, n_terms), dtype=float)
        df = np.zeros(n_terms, dtype=float)

        for i, weights in enumerate(row_weights):
            for j, weight in weights.items():
                binary[i, j] = weight
                df[j] += 1

        idf = np.log((1.0 + n_items) / (1.0 + df)) + 1.0
        weighted = binary * idf

        # Cada fila a longitud 1: el producto punto con un perfil unitario es
        # directamente la similitud coseno (0..1), y una fila sin etiquetas queda en ceros.
        norms = np.linalg.norm(weighted, axis=1, keepdims=True)
        norms[norms == 0] = 1.0
        self.matrix = weighted / norms

        self.idf = idf
        self.tags: list[str | None] = [None] * n_terms
        for tag, j in index.items():
            self.tags[j] = tag
        self.rows = [{self.tags[j]: w for j, w in weights.items()} for weights in row_weights]

    # ----------------------------------------------------------------- perfil

    def profile_from_history(self, indexed: list[tuple[int, datetime]],
                             as_of: datetime, half_life_days: float) -> np.ndarray | None:
        """Suma las filas de lo reservado, con decaimiento exponencial por antigüedad."""
        profile = np.zeros(self.matrix.shape[1], dtype=float)
        for i, when in indexed:
            age_days = max((as_of - when).days, 0)
            weight = 0.5 ** (age_days / half_life_days)
            profile += weight * self.matrix[i]
        return unit(profile)

    def profile_from_interests(self, interests: list[str]) -> np.ndarray | None:
        """Perfil a partir de intereses declarados que estén en el vocabulario."""
        profile = np.zeros(self.matrix.shape[1], dtype=float)
        vocabulary = {tag: j for j, tag in enumerate(self.tags)}
        for interest in interests:
            j = vocabulary.get(normalize_tag(interest))
            if j is not None:
                profile[j] += 1.0
        return unit(profile) if profile.any() else None

    def matched_tags(self, profile: np.ndarray | None, i: int, limit: int = 3) -> list[str]:
        """Etiquetas del destino que más aportan al perfil del usuario."""
        if profile is None:
            return []
        contribution = self.matrix[i] * profile
        order = np.argsort(-contribution, kind="stable")
        return [self.tags[j] for j in order[:limit]
                if contribution[j] > 0 and self.tags[j] is not None]
