"""Servicio de lógica de negocio para práctica y progreso del usuario."""

import math
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.lesson import Lesson, PracticeSession
from app.schemas.lesson import PracticeSubmitRequest


async def submit_practice(
    db: AsyncSession, data: PracticeSubmitRequest, user_id: uuid.UUID
) -> PracticeSession:
    """Registrar resultado de una sesión de práctica y actualizar stats de lección."""
    # Obtener la lección para datos de tempo
    result = await db.execute(select(Lesson).where(Lesson.id == data.lesson_id))
    lesson = result.scalar_one_or_none()
    if not lesson:
        raise ValueError("Lección no encontrada")

    # Calcular precisión de tempo
    tempo_accuracy = 0.0
    if lesson.tempo_bpm > 0 and data.average_tempo > 0:
        ratio = data.average_tempo / lesson.tempo_bpm
        tempo_accuracy = max(0.0, min(100.0, 100.0 - abs(1.0 - ratio) * 100.0))

    # Crear sesión de práctica
    session = PracticeSession(
        user_id=user_id,
        lesson_id=data.lesson_id,
        client_id=str(data.client_id) if data.client_id else None,
        score=data.score,
        correct_notes=data.correct_notes,
        total_notes=data.total_notes,
        wrong_notes=data.wrong_notes,
        missed_notes=data.missed_notes,
        average_tempo=data.average_tempo,
        expected_tempo=lesson.tempo_bpm,
        tempo_accuracy=tempo_accuracy,
        total_time_seconds=data.total_time_seconds,
        errors_detail=data.errors_detail,
        completed=data.completed,
    )
    db.add(session)

    # Actualizar total_plays y average_score de la lección
    lesson.total_plays += 1
    # Recalcular promedio
    avg_q = select(func.avg(PracticeSession.score)).where(
        PracticeSession.lesson_id == data.lesson_id
    )
    avg_result = await db.execute(avg_q)
    new_avg = avg_result.scalar()
    if new_avg is not None:
        lesson.average_score = round(new_avg, 2)

    await db.flush()
    await db.refresh(session)
    # Cargar relación lesson para el router
    session.lesson = lesson
    return session


async def get_session_by_client_id(
    db: AsyncSession, client_id: uuid.UUID, user_id: uuid.UUID
) -> PracticeSession | None:
    """Buscar una sesión ya registrada con ese client_id (idempotencia)."""
    result = await db.execute(
        select(PracticeSession)
        .options(selectinload(PracticeSession.lesson))
        .where(
            PracticeSession.client_id == str(client_id),
            PracticeSession.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()


async def get_practice_history(
    db: AsyncSession,
    user_id: uuid.UUID,
    lesson_id: uuid.UUID | None = None,
    page: int = 1,
    limit: int = 20,
    is_premium: bool = False,
) -> dict:
    """Obtener historial de prácticas del usuario.

    `is_premium` controla si se incluye el `ai_feedback` (función de pago): para
    usuarios sin suscripción se devuelve None aunque la columna tenga valor.
    """
    query = (
        select(PracticeSession)
        .options(selectinload(PracticeSession.lesson))
        .where(PracticeSession.user_id == user_id)
    )

    if lesson_id:
        query = query.where(PracticeSession.lesson_id == lesson_id)

    # Contar total
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    pages = max(1, math.ceil(total / limit))
    offset = (page - 1) * limit
    query = query.order_by(PracticeSession.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    sessions = list(result.scalars().all())

    items = []
    for s in sessions:
        items.append(
            {
                "id": s.id,
                "user_id": s.user_id,
                "lesson_id": s.lesson_id,
                "score": s.score,
                "correct_notes": s.correct_notes,
                "total_notes": s.total_notes,
                "wrong_notes": s.wrong_notes,
                "missed_notes": s.missed_notes,
                "average_tempo": s.average_tempo,
                "expected_tempo": s.expected_tempo,
                "tempo_accuracy": s.tempo_accuracy,
                "total_time_seconds": s.total_time_seconds,
                "errors_detail": s.errors_detail,
                "ai_feedback": s.ai_feedback if is_premium else None,
                "completed": s.completed,
                "created_at": s.created_at,
                "lesson_title": s.lesson.title if s.lesson else None,
            }
        )

    return {"items": items, "total": total, "page": page, "pages": pages}


async def get_user_progress_stats(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """Obtener estadísticas generales de progreso del usuario."""
    # Total sesiones
    total_q = select(func.count()).where(PracticeSession.user_id == user_id)
    total_result = await db.execute(total_q)
    total_sessions = total_result.scalar() or 0

    # Lecciones distintas jugadas
    distinct_q = select(func.count(distinct(PracticeSession.lesson_id))).where(
        PracticeSession.user_id == user_id
    )
    distinct_result = await db.execute(distinct_q)
    total_lessons_played = distinct_result.scalar() or 0

    # Score promedio
    avg_q = select(func.avg(PracticeSession.score)).where(PracticeSession.user_id == user_id)
    avg_result = await db.execute(avg_q)
    average_score = round(avg_result.scalar() or 0.0, 2)

    # Mejor score
    best_q = select(func.max(PracticeSession.score)).where(PracticeSession.user_id == user_id)
    best_result = await db.execute(best_q)
    best_score = best_result.scalar() or 0.0

    # Tiempo total de práctica
    time_q = select(func.sum(PracticeSession.total_time_seconds)).where(
        PracticeSession.user_id == user_id
    )
    time_result = await db.execute(time_q)
    total_practice_time = time_result.scalar() or 0.0

    # Lecciones completadas (mejor score >= 70 en al menos una sesión)
    completed_q = select(func.count(distinct(PracticeSession.lesson_id))).where(
        PracticeSession.user_id == user_id,
        PracticeSession.score >= 70,
    )
    completed_result = await db.execute(completed_q)
    lessons_completed = completed_result.scalar() or 0

    # Racha actual (días consecutivos con al menos 1 práctica)
    current_streak = await _calculate_streak(db, user_id)

    # Categoría favorita (la más practicada)
    from app.models.lesson import Category

    fav_q = (
        select(Category.name, func.count(PracticeSession.id).label("cnt"))
        .join(Lesson, Lesson.id == PracticeSession.lesson_id)
        .join(Category, Category.id == Lesson.category_id)
        .where(PracticeSession.user_id == user_id)
        .group_by(Category.name)
        .order_by(func.count(PracticeSession.id).desc())
        .limit(1)
    )
    fav_result = await db.execute(fav_q)
    fav_row = fav_result.first()
    favorite_category = fav_row[0] if fav_row else None

    return {
        "total_sessions": total_sessions,
        "total_lessons_played": total_lessons_played,
        "average_score": average_score,
        "best_score": best_score,
        "total_practice_time": total_practice_time,
        "lessons_completed": lessons_completed,
        "current_streak": current_streak,
        "favorite_category": favorite_category,
    }


async def _calculate_streak(db: AsyncSession, user_id: uuid.UUID) -> int:
    """Calcular racha de días consecutivos con práctica."""
    # Obtener fechas únicas de práctica ordenadas descendente
    dates_q = (
        select(func.date(PracticeSession.created_at))
        .where(PracticeSession.user_id == user_id)
        .distinct()
        .order_by(func.date(PracticeSession.created_at).desc())
    )
    result = await db.execute(dates_q)
    dates = [row[0] for row in result.all()]

    if not dates:
        return 0

    today = datetime.now(UTC).date()
    streak = 0

    # Verificar si hoy o ayer tienen práctica (para contar racha)
    if dates[0] != today and dates[0] != today - timedelta(days=1):
        return 0

    for i, date in enumerate(dates):
        expected_date = today - timedelta(days=i)
        # Permitir que la racha empiece desde ayer
        if i == 0 and date == today - timedelta(days=1):
            expected_date = today - timedelta(days=1)
            streak += 1
            continue
        if i == 0 and date != today:
            break
        if date == expected_date:
            streak += 1
        else:
            break

    return streak


async def get_weekly_progress(db: AsyncSession, user_id: uuid.UUID) -> list[dict]:
    """Obtener progreso de los últimos 7 días."""
    today = datetime.now(UTC).date()
    week_data = []

    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        day_start = datetime.combine(day, datetime.min.time()).replace(tzinfo=UTC)
        day_end = day_start + timedelta(days=1)

        # Sesiones del día
        count_q = select(func.count()).where(
            PracticeSession.user_id == user_id,
            PracticeSession.created_at >= day_start,
            PracticeSession.created_at < day_end,
        )
        count_result = await db.execute(count_q)
        sessions_count = count_result.scalar() or 0

        # Score promedio del día
        avg_q = select(func.avg(PracticeSession.score)).where(
            PracticeSession.user_id == user_id,
            PracticeSession.created_at >= day_start,
            PracticeSession.created_at < day_end,
        )
        avg_result = await db.execute(avg_q)
        avg_score = round(avg_result.scalar() or 0.0, 2)

        # Minutos de práctica del día
        time_q = select(func.sum(PracticeSession.total_time_seconds)).where(
            PracticeSession.user_id == user_id,
            PracticeSession.created_at >= day_start,
            PracticeSession.created_at < day_end,
        )
        time_result = await db.execute(time_q)
        practice_seconds = time_result.scalar() or 0.0
        practice_minutes = round(practice_seconds / 60.0, 1)

        week_data.append(
            {
                "date": day.isoformat(),
                "sessions_count": sessions_count,
                "average_score": avg_score,
                "practice_minutes": practice_minutes,
            }
        )

    return week_data


async def get_admin_stats_overview(db: AsyncSession) -> dict:
    """Obtener estadísticas generales para el dashboard admin."""
    from app.models.lesson import Category

    # Total lecciones activas
    lessons_q = select(func.count()).where(Lesson.is_active == True)  # noqa: E712
    lessons_result = await db.execute(lessons_q)
    total_lessons = lessons_result.scalar() or 0

    # Total categorías activas
    cats_q = select(func.count()).where(Category.is_active == True)  # noqa: E712
    cats_result = await db.execute(cats_q)
    total_categories = cats_result.scalar() or 0

    # Total sesiones de práctica
    sessions_q = select(func.count(PracticeSession.id))
    sessions_result = await db.execute(sessions_q)
    total_practice_sessions = sessions_result.scalar() or 0

    # Usuarios activos (con al menos 1 práctica en los últimos 30 días)
    thirty_days_ago = datetime.now(UTC) - timedelta(days=30)
    users_q = select(func.count(distinct(PracticeSession.user_id))).where(
        PracticeSession.created_at >= thirty_days_ago
    )
    users_result = await db.execute(users_q)
    total_users_active = users_result.scalar() or 0

    # Lección más jugada
    most_played_q = (
        select(Lesson.title)
        .where(Lesson.is_active == True)  # noqa: E712
        .order_by(Lesson.total_plays.desc())
        .limit(1)
    )
    most_played_result = await db.execute(most_played_q)
    most_played = most_played_result.scalar()

    # Lección mejor calificada
    highest_q = (
        select(Lesson.title)
        .where(Lesson.is_active == True, Lesson.total_plays > 0)  # noqa: E712
        .order_by(Lesson.average_score.desc())
        .limit(1)
    )
    highest_result = await db.execute(highest_q)
    highest_rated = highest_result.scalar()

    # Score promedio global
    avg_q = select(func.avg(PracticeSession.score))
    avg_result = await db.execute(avg_q)
    avg_global = round(avg_result.scalar() or 0.0, 2)

    return {
        "total_lessons": total_lessons,
        "total_categories": total_categories,
        "total_practice_sessions": total_practice_sessions,
        "total_users_active": total_users_active,
        "most_played_lesson": most_played,
        "highest_rated_lesson": highest_rated,
        "average_global_score": avg_global,
    }
