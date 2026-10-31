"""Evaluación offline: «dejar la última reserva fuera».

Para cada usuario con al menos 2 reservas confirmadas:
  1. se oculta su última reserva (el destino «correcto»);
  2. se construye su perfil solo con las anteriores y con la fecha de esa última reserva;
  3. se mira en qué posición del ranking aparece el destino oculto.

Se compara contra la línea base «los más populares» (con la reserva oculta descontada).
Si el modelo no supera a esa línea base, el problema está en los datos, no en el algoritmo.

    python -m recommender.evaluate

Limitación conocida: la popularidad usa reservas de otros usuarios posteriores a la
fecha oculta (una fuga menor). Con pocos datos los resultados son ruidosos.
"""
from __future__ import annotations

import logging
import math
from statistics import mean

import pandas as pd

from .config import Settings
from .data import connect, load_dataset
from .scoring import Recommender, UserContext

KS = (3, 5, 10)


def _metrics(ranks: list[int], ks: tuple[int, ...]) -> dict:
    if not ranks:
        return {"n": 0}
    out = {"n": len(ranks), "mrr": mean(1.0 / r for r in ranks)}
    for k in ks:
        out[f"hit@{k}"] = mean(1.0 if r <= k else 0.0 for r in ranks)
        out[f"ndcg@{k}"] = mean(1.0 / math.log2(r + 1) if r <= k else 0.0 for r in ranks)
    return out


def evaluate(rec: Recommender, bookings: pd.DataFrame, ks: tuple[int, ...] = KS,
             only_new: bool = True, min_bookings: int = 2) -> dict:
    """only_new=True evalúa solo usuarios cuyo destino oculto NO habían visitado antes."""
    model_ranks: list[int] = []
    popular_ranks: list[int] = []

    for _, g in bookings.groupby("user_id"):
        g = g.sort_values("booking_date")
        if len(g) < min_bookings:
            continue
        held, train = g.iloc[-1], g.iloc[:-1]
        held_id = held["dest_id"]
        if held_id not in rec.index or (only_new and held_id in set(train["dest_id"])):
            continue

        prices = train["ticket_price"][train["ticket_price"] > 0]
        ctx = UserContext(
            history=list(zip(train["dest_id"], train["booking_date"])),
            ref_price=float(prices.median()) if len(prices) else None,
            as_of=held["booking_date"].to_pydatetime(),
        )
        ranked = rec.rank_ids(ctx, exclude_visited=True)
        if held_id not in ranked:
            continue

        counts = rec.booking_counts.copy()
        counts[rec.index[held_id]] -= 1            # no dejar que la reserva oculta se «auto-recomiende»
        available = rec.available(ctx.as_of)
        baseline = sorted(
            (i for i in range(len(rec.ids)) if available[i] and rec.ids[i] not in ctx.visited),
            key=lambda i: (-counts[i], rec.ids[i]),
        )
        model_ranks.append(ranked.index(held_id) + 1)
        popular_ranks.append([rec.ids[i] for i in baseline].index(held_id) + 1)

    return {"model": _metrics(model_ranks, ks), "popular_baseline": _metrics(popular_ranks, ks)}


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    settings = Settings.from_env()
    data = load_dataset(connect(settings), settings)
    rec = Recommender(data.destinations, data.flights, data.bookings, settings)
    result = evaluate(rec, data.bookings)

    if result["model"]["n"] == 0:
        print("No hay usuarios con 2 o más reservas confirmadas a destinos distintos: "
              "todavía no se puede evaluar. Hace falta acumular historial.")
        return
    print(f"Usuarios evaluados: {result['model']['n']}\n")
    print(f"{'métrica':<10}{'modelo':>10}{'populares':>12}")
    for key in result["model"]:
        if key != "n":
            print(f"{key:<10}{result['model'][key]:>10.3f}{result['popular_baseline'][key]:>12.3f}")


if __name__ == "__main__":
    main()
