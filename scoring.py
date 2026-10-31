"""Puntaje y ranking de destinos para un usuario.

score = (w_afinidad*afinidad + w_presupuesto*presupuesto + w_temporada*temporada + w_oferta*oferta)
        * multiplicador_de_encaje

  afinidad     similitud coseno entre el perfil del usuario y las etiquetas del destino
  presupuesto  1 si el destino cuesta igual o menos que lo habitual del usuario; baja si es más caro
  temporada    1 si el mes de viaje (o uno de los meses preferidos) está en la mejor época
  oferta       descuento vigente o qué tan barato está hoy frente a lo normal en ese destino
  encaje       Location.travelerFit[travelCompany] declarado por el usuario, 1 si no hay dato

Sin historial ni intereses el usuario recibe el ranking de populares (con la
misma fórmula que usa el backend como respaldo).
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime

import numpy as np
import pandas as pd

from .config import Settings
from .features import TagSpace, unit
from .seasons import months_from_value, season_score, target_month
from .utils import utcnow


@dataclass
class UserContext:
    history: list[tuple[str, datetime]] = field(default_factory=list)  # (location_id, fecha de reserva)
    interests: list[str] = field(default_factory=list)
    ref_price: float | None = None        # precio habitual por pasaje del usuario (USD)
    preferred_months: list[int] = field(default_factory=list)   # UserPreferences.preferredMonths
    travel_company: str | None = None     # UserPreferences.travelCompany (solo|pareja|familia|amigos)
    excluded: set[str] = field(default_factory=set)             # UserPreferences.excludedLocationIds
    as_of: datetime = field(default_factory=utcnow)

    @property
    def visited(self) -> set[str]:
        return {dest_id for dest_id, _ in self.history}


class Recommender:
    def __init__(self, destinations: pd.DataFrame, flights: pd.DataFrame,
                 bookings: pd.DataFrame, settings: Settings):
        if destinations.empty:
            raise ValueError("No hay destinos visibles para recomendar")
        self.settings = settings
        self.dest = destinations.reset_index(drop=True)
        self.flights = flights
        self.ids: list[str] = self.dest["location_id"].tolist()
        self.index = {d: i for i, d in enumerate(self.ids)}
        self.space = TagSpace(self.dest["tags"].tolist())
        self.months = [months_from_value(m) for m in self.dest["best_months"]]
        self.prices = self.dest["cheapest_price"].to_numpy(dtype=float)
        self.booking_counts = self._count_bookings(bookings)
        top = self.booking_counts.max()
        # Sin reservas manda la valoración, pero solo de destinos con opiniones
        # reales: ratingCount = 0 significa «nadie ha valorado» (p. ej. MAD, LHR, JFK).
        if top > 0:
            self.popularity = self.booking_counts / top
        else:
            rating = self.dest["rating"].to_numpy(dtype=float)
            has_votes = self.dest["rating_count"].to_numpy(dtype=float) > 0
            self.popularity = np.where(has_votes, rating, 0.0) / 5.0
        self._offer_cache: dict = {}
        self._avail_cache: dict = {}

    # ------------------------------------------------------------------ datos

    def _count_bookings(self, bookings: pd.DataFrame) -> np.ndarray:
        counts = np.zeros(len(self.ids))
        if not bookings.empty:
            for dest_id, n in bookings["dest_id"].value_counts().items():
                if dest_id in self.index:
                    counts[self.index[dest_id]] = n
        return counts

    def available(self, as_of: datetime) -> np.ndarray:
        """Destinos con algún vuelo activo por venir (no sirve recomendar lo que no se puede reservar).

        Si no hay vuelos que cumplan se relaja a «cualquier vuelo activo», y si la
        tabla de vuelos está vacía no se filtra nada.
        """
        key = as_of.date()
        if key not in self._avail_cache:
            mask = np.ones(len(self.ids), dtype=bool)
            f = self.flights
            if not f.empty:
                active = f[f["active"]]
                for subset in (active[active["departure"] >= as_of], active):
                    arrival_ids = set(subset["arr_id"].dropna())
                    candidate = np.array([d in arrival_ids for d in self.ids])
                    if candidate.any():
                        mask = candidate
                        break
            self._avail_cache[key] = mask
        return self._avail_cache[key]

    def _offer_scores(self, as_of: datetime) -> np.ndarray:
        key = as_of.date()
        if key in self._offer_cache:
            return self._offer_cache[key]
        scores = np.zeros(len(self.ids))
        f = self.flights
        if not f.empty:
            f = f[f["active"] & (f["price"] > 0)]
            for dest_id, g in f.groupby("arr_id"):
                i = self.index.get(dest_id)
                if i is None:
                    continue
                upcoming = g[g["departure"] >= as_of]
                g = upcoming if not upcoming.empty else g
                discount = g.loc[g["discounted"], "discount_pct"].max() / 100.0 if g["discounted"].any() else 0.0
                median = g["price"].median()
                cheap = 1.0 - g["price"].min() / median if median > 0 else 0.0
                scores[i] = float(np.clip(max(discount, cheap), 0.0, 1.0))
        self._offer_cache[key] = scores
        return scores

    def _budget_scores(self, ref_price: float | None) -> np.ndarray:
        if not ref_price or ref_price <= 0:
            return np.full(len(self.ids), 0.5)      # sin referencia: neutro
        over = np.maximum((self.prices - ref_price) / ref_price, 0.0)
        scores = np.clip(1.0 - over, 0.0, 1.0)
        return np.where(self.prices <= 0, 0.5, scores)

    def _fit_scores(self, company: str | None) -> tuple[np.ndarray, np.ndarray]:
        """Encaje destino-compañía (Location.travelerFit) y máscara de los declarados.

        Si el usuario no declaró compañía, o el destino no declaró pesos, el
        encaje es neutro (1.0) y no se explica con COMPANION_FIT.
        """
        fit = np.ones(len(self.ids), dtype=float)
        declared = np.zeros(len(self.ids), dtype=bool)
        if company:
            for i, weights in enumerate(self.dest["traveler_fit"].tolist()):
                if company in weights:
                    fit[i] = float(weights[company])
                    declared[i] = True
        return fit, declared

    # ----------------------------------------------------------------- perfil

    def _profile(self, ctx: UserContext) -> tuple[np.ndarray | None, str]:
        s = self.settings
        indexed = [(self.index[d], t) for d, t in ctx.history if d in self.index]
        hist = self.space.profile_from_history(indexed, ctx.as_of, s.half_life_days) if indexed else None
        pref = self.space.profile_from_interests(ctx.interests) if ctx.interests else None
        if hist is not None and pref is not None:
            return unit((1 - s.interest_weight) * hist + s.interest_weight * pref), "content"
        if hist is not None:
            return hist, "content"
        if pref is not None:
            return pref, "preferences"
        return None, "popular"

    def _season_scores(self, ctx: UserContext) -> np.ndarray:
        """Temporada contra el mes estimado de viaje y, si declaró meses, contra esos."""
        targets = {target_month(ctx.as_of, self.settings.lead_days)}
        targets |= {int(m) for m in ctx.preferred_months if 1 <= int(m) <= 12}
        return np.array([max(season_score(m, t) for t in targets) for m in self.months])

    # ---------------------------------------------------------------- ranking

    def _score(self, ctx: UserContext):
        s = self.settings
        profile, strategy = self._profile(ctx)
        n = len(self.ids)
        season = self._season_scores(ctx)
        offer = self._offer_scores(ctx.as_of)
        fit, fit_declared = self._fit_scores(ctx.travel_company)
        # El encaje multiplica el total sin alterar los cuatro pesos que suman 1.
        multiplier = (1 - s.companion_weight) + s.companion_weight * fit

        if profile is None:
            featured = self.dest["featured"].to_numpy(dtype=float)
            base = 0.60 * self.popularity + 0.25 * season + 0.10 * offer + 0.05 * featured
            comps = {"affinity": np.zeros(n), "budget": np.full(n, 0.5),
                     "season": season, "offer": offer, "fit": fit}
        else:
            affinity = self.space.matrix @ profile
            budget = self._budget_scores(ctx.ref_price)
            w = s.weights
            base = (w["affinity"] * affinity + w["budget"] * budget
                    + w["season"] * season + w["offer"] * offer)
            comps = {"affinity": affinity, "budget": budget,
                     "season": season, "offer": offer, "fit": fit}
        return strategy, base * multiplier, comps, profile, fit_declared

    def _order(self, ctx: UserContext, scores: np.ndarray,
               exclude_visited: bool) -> tuple[list[int], np.ndarray]:
        """Ordena y devuelve también los puntajes YA penalizados, para que lo que se
        muestra coincida con el orden de la lista."""
        mask = self.available(ctx.as_of).copy()
        visited = [self.index[d] for d in ctx.visited if d in self.index]
        excluded = [self.index[d] for d in ctx.excluded if d in self.index]
        mask[excluded] = False          # veto explícito del usuario: nunca se recomienda
        scores = scores.copy()
        if exclude_visited:
            mask[visited] = False
        else:
            scores[visited] *= self.settings.repeat_penalty
        # La popularidad solo desempata (1e-6) para que el orden sea estable.
        order = np.argsort(-(scores + 1e-6 * self.popularity), kind="stable")
        return [int(i) for i in order if mask[i]], scores

    def rank_ids(self, ctx: UserContext, exclude_visited: bool = False) -> list[str]:
        """Todos los destinos disponibles, del mejor al peor. Lo usa la evaluación."""
        _, scores, _, _, _ = self._score(ctx)
        order, _ = self._order(ctx, scores, exclude_visited)
        return [self.ids[i] for i in order]

    def recommend(self, ctx: UserContext, k: int | None = None,
                  exclude_visited: bool = False) -> tuple[str, list[dict]]:
        """Devuelve (estrategia, top-k) listo para guardarse en MongoDB."""
        k = k or self.settings.top_k
        strategy, scores, comps, profile, fit_declared = self._score(ctx)
        order, adjusted = self._order(ctx, scores, exclude_visited)
        return strategy, [self._item(i, strategy, adjusted, comps, profile, fit_declared)
                          for i in order[:k]]

    def _item(self, i: int, strategy: str, scores: np.ndarray, comps: dict,
              profile: np.ndarray | None, fit_declared: np.ndarray) -> dict:
        matched = self.space.matched_tags(profile, i) if profile is not None else []
        reasons = []
        if strategy == "popular":
            reasons.append("POPULAR")
        if matched:
            reasons.append("TAG_MATCH")
        if comps["season"][i] >= 1.0:
            reasons.append("IN_SEASON")
        if comps["fit"][i] >= 0.8 and fit_declared[i]:
            reasons.append("COMPANION_FIT")
        if strategy != "popular" and comps["budget"][i] >= 1.0:
            reasons.append("PRICE_FITS")
        if comps["offer"][i] >= 0.15:
            reasons.append("OFFER")
        row = self.dest.iloc[i]
        return {
            "locationID": row["location_id"],
            "iataCode": row["iata"],
            "cityName": row["city"],
            "score": round(float(scores[i]), 4),
            "components": {name: round(float(vals[i]), 4) for name, vals in comps.items()},
            "matchedTags": matched,
            "reasons": reasons,
        }


def new_recommendation_id() -> str:
    """Identificador para atribuir después una reserva a la lista que la originó."""
    return uuid.uuid4().hex
