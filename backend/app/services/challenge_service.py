"""Servicio de desafíos semanales: retos de práctica que se renuevan cada lunes.

No hay tabla de desafíos: las definiciones viven en código y el progreso se
calcula en vivo desde practice_sessions + el weekly_xp ya anclado a lunes (UTC).
"""

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import PracticeSession
from app.services.ranking_service import (
    get_current_week_monday,
    get_or_create_user_xp,
)

# (key, título, descripción, métrica, objetivo). La métrica indexa los valores
# calculados abajo: "days" | "lessons80" | "weekly_xp" | "sessions".
_CHALLENGE_DEFS = [
    ("days", "Practicá 5 días",
     "Entrá a practicar en 5 días distintos esta semana", "days", 5),
    ("lessons80", "3 lecciones al 80%",
     "Completá 3 lecciones con 80% o más", "lessons80", 3),
    ("xp", "Ganá 500 XP",
     "Sumá 500 puntos de experiencia esta semana", "weekly_xp", 500),
    ("sessions", "10 sesiones",
     "Hacé 10 sesiones de práctica esta semana", "sessions", 10),
]


async def get_weekly_challenges(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """Progreso del usuario en los desafíos de la semana actual (lunes-domingo)."""
    monday = get_current_week_monday()
    today = datetime.now(timezone.utc).date()
    week_start = datetime.combine(
        monday, datetime.min.time()
    ).replace(tzinfo=timezone.utc)

    # Sesiones de práctica esta semana.
    sessions = (
        await db.execute(
            select(func.count()).where(
                PracticeSession.user_id == user_id,
                PracticeSession.created_at >= week_start,
            )
        )
    ).scalar() or 0

    # Lecciones DISTINTAS con score >= 80 esta semana.
    lessons80 = (
        await db.execute(
            select(func.count(distinct(PracticeSession.lesson_id))).where(
                PracticeSession.user_id == user_id,
                PracticeSession.created_at >= week_start,
                PracticeSession.score >= 80,
            )
        )
    ).scalar() or 0

    # Días distintos con al menos una práctica (lunes..hoy). Se cuenta día por
    # día para no depender de funciones de fecha específicas del motor.
    days_practiced = 0
    day = monday
    while day <= today:
        day_start = datetime.combine(
            day, datetime.min.time()
        ).replace(tzinfo=timezone.utc)
        day_end = day_start + timedelta(days=1)
        count = (
            await db.execute(
                select(func.count()).where(
                    PracticeSession.user_id == user_id,
                    PracticeSession.created_at >= day_start,
                    PracticeSession.created_at < day_end,
                )
            )
        ).scalar() or 0
        if count > 0:
            days_practiced += 1
        day += timedelta(days=1)

    # XP de la semana (ya anclado a lunes en UserXP). Si la fila quedó en una
    # semana vieja (no practicó esta semana), el valor real es 0.
    user_xp = await get_or_create_user_xp(db, user_id)
    weekly_xp = user_xp.weekly_xp if user_xp.week_start_date == monday else 0

    metric_values = {
        "days": days_practiced,
        "lessons80": lessons80,
        "weekly_xp": weekly_xp,
        "sessions": sessions,
    }

    challenges = []
    for key, title, desc, metric, target in _CHALLENGE_DEFS:
        raw = metric_values[metric]
        challenges.append({
            "key": key,
            "title": title,
            "description": desc,
            "target": target,
            "progress": min(raw, target),
            "completed": raw >= target,
        })

    next_monday = monday + timedelta(days=7)
    days_remaining = (next_monday - today).days

    return {"challenges": challenges, "days_remaining": days_remaining}
