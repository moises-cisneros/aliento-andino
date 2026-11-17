"""[SUB-21-A] Router de analítica pedagógica por instrumento (HU-21).

Endpoints en FastAPI con consultas agregadas en PostgreSQL que calculan la
precisión de notas y la tasa de deserción por instrumento y por lección. Un
filtro inválido o sin datos devuelve una estructura vacía con HTTP 200 (nunca
un error 500).
"""

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin
from app.models.lesson import Lesson, PracticeSession
from app.models.user import User
from app.services import analytics_service as svc

router = APIRouter(prefix="/api/v1/analytics", tags=["Analytics"])

# Ventanas temporales soportadas por `date_range`; cualquier otro valor (p. ej.
# "all") desactiva el filtro temporal en lugar de fallar.
_RANGE_DAYS = {"week": 7, "month": 30, "year": 365}


def _since(date_range: str | None) -> datetime | None:
    days = _RANGE_DAYS.get(date_range or "month")
    if days is None:
        return None
    return datetime.now(UTC) - timedelta(days=days)


def _base_query(instrument: str | None, since: datetime | None):
    stmt = select(
        Lesson.instrument.label("instrument"),
        Lesson.title.label("title"),
        PracticeSession.lesson_id.label("lesson_id"),
        PracticeSession.score.label("score"),
        PracticeSession.correct_notes.label("correct_notes"),
        PracticeSession.total_notes.label("total_notes"),
        PracticeSession.tempo_accuracy.label("tempo_accuracy"),
        PracticeSession.completed.label("completed"),
    ).join(Lesson, Lesson.id == PracticeSession.lesson_id)
    if instrument:
        stmt = stmt.where(Lesson.instrument == instrument)
    if since is not None:
        stmt = stmt.where(PracticeSession.created_at >= since)
    return stmt


def _to_sample(row) -> svc.SessionSample:
    return svc.SessionSample(
        instrument=row.instrument,
        lesson_id=str(row.lesson_id),
        score=float(row.score),
        correct_notes=int(row.correct_notes),
        total_notes=int(row.total_notes),
        tempo_accuracy=float(row.tempo_accuracy),
        completed=bool(row.completed),
    )


@router.get("/instruments")
async def get_instrument_metrics(
    instrument: str | None = Query(None, description="quena | zampona | tarka"),
    date_range: str = Query("month", description="week | month | year | all"),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Precisión de notas y tasa de finalización agregadas por instrumento.

    La *precisión* es la proporción de notas acertadas (`correct_notes /
    total_notes`); la desviación en cents por nota se infiere on-device y no se
    persiste, por lo que no se agrega aquí.
    """
    rows = (await db.execute(_base_query(instrument, _since(date_range)))).all()

    by_instrument: dict[str, list[svc.SessionSample]] = {}
    for row in rows:
        by_instrument.setdefault(row.instrument, []).append(_to_sample(row))

    return [
        {"instrument": inst, **svc.summarize_instrument(samples)}
        for inst, samples in sorted(by_instrument.items())
    ]


@router.get("/lessons/dropoff")
async def get_lesson_dropoff(
    instrument: str | None = Query(None, description="quena | zampona | tarka"),
    date_range: str = Query("month", description="week | month | year | all"),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Tasa de deserción por lección (opcionalmente filtrada por instrumento)."""
    rows = (await db.execute(_base_query(instrument, _since(date_range)))).all()

    titles = {str(row.lesson_id): row.title for row in rows}
    dropoff = svc.lesson_dropoff([_to_sample(row) for row in rows])
    for entry in dropoff:
        entry["title"] = titles.get(entry["lesson_id"], "")
    return dropoff
