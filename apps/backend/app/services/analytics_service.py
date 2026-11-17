"""[SUB-21-A] Agregaciones puras de analítica pedagógica por instrumento.

Las funciones de este módulo son **puras y deterministas** (no tocan la base de
datos): reciben muestras de sesiones y devuelven métricas agregadas. Así el
cálculo matemático —medias de precisión, tasa de finalización y percentiles de
deserción— queda cubierto por pruebas unitarias sin depender de PostgreSQL.

Nota honesta sobre "centavos por nota": la desviación en cents por nota se
calcula **on-device** y no se persiste a nivel de sesión. Por eso la *precisión*
se deriva del dato real almacenado: la proporción de notas acertadas
(`correct_notes / total_notes`).
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SessionSample:
    """Muestra mínima de una sesión de práctica para las agregaciones."""

    instrument: str
    lesson_id: str
    score: float
    correct_notes: int
    total_notes: int
    tempo_accuracy: float
    completed: bool


def note_precision(correct_notes: int, total_notes: int) -> float:
    """Precisión de notas en `[0, 1]`: aciertos / total (0 si no hubo notas)."""
    if total_notes <= 0:
        return 0.0
    return max(0.0, min(1.0, correct_notes / total_notes))


def _mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def summarize_instrument(samples: list[SessionSample]) -> dict:
    """Resumen agregado de las sesiones de un mismo instrumento.

    Devuelve una estructura con conteo de sesiones, puntaje medio, precisión
    media de notas, exactitud media de tempo y tasa de finalización. Con una
    lista vacía devuelve la misma estructura en ceros (nunca lanza).
    """
    if not samples:
        return {
            "sessions": 0,
            "avg_score": 0.0,
            "avg_note_precision": 0.0,
            "avg_tempo_accuracy": 0.0,
            "completion_rate": 0.0,
        }

    precisions = [note_precision(s.correct_notes, s.total_notes) for s in samples]
    completed = sum(1 for s in samples if s.completed)
    return {
        "sessions": len(samples),
        "avg_score": round(_mean([s.score for s in samples]), 2),
        "avg_note_precision": round(_mean(precisions), 4),
        "avg_tempo_accuracy": round(_mean([s.tempo_accuracy for s in samples]), 4),
        "completion_rate": round(completed / len(samples), 4),
    }


def lesson_dropoff(samples: list[SessionSample]) -> list[dict]:
    """Tasa de deserción por lección: `1 - (completadas / intentos)`.

    Agrupa las muestras por lección y las ordena de mayor a menor deserción
    (las lecciones donde más se abandona quedan primero).
    """
    by_lesson: dict[str, list[SessionSample]] = {}
    for s in samples:
        by_lesson.setdefault(s.lesson_id, []).append(s)

    result: list[dict] = []
    for lesson_id, group in by_lesson.items():
        attempts = len(group)
        completed = sum(1 for s in group if s.completed)
        result.append(
            {
                "lesson_id": lesson_id,
                "attempts": attempts,
                "completed": completed,
                "dropoff_rate": round(1 - completed / attempts, 4) if attempts else 0.0,
            }
        )

    result.sort(key=lambda r: r["dropoff_rate"], reverse=True)
    return result


def percentile(values: list[float], p: float) -> float:
    """Percentil `p` (0..100) por interpolación lineal; 0.0 sin datos."""
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    rank = (p / 100) * (len(ordered) - 1)
    lo = int(rank)
    hi = min(lo + 1, len(ordered) - 1)
    frac = rank - lo
    return ordered[lo] + (ordered[hi] - ordered[lo]) * frac
