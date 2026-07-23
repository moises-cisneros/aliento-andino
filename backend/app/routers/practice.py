"""Router de práctica y progreso del usuario."""

import logging
import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session, get_db
from app.dependencies.auth import get_current_user
from app.models.lesson import PracticeSession
from app.models.user import User
from app.schemas.lesson import (
    PaginatedResponse,
    PracticeSessionResponse,
    PracticeSubmitRequest,
    PracticeSubmitResponse,
    ProgressStats,
    WeeklyDataPoint,
)
from app.services import gemini_service, practice_service, ranking_service
from app.schemas.ranking import AchievementResponse, XPGainResult

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Práctica y Progreso"])


def _visible_feedback(user: User, value: str | None) -> str | None:
    """Defensa en profundidad: el feedback con IA es premium. Aunque solo se
    genera para usuarios premium, al LEER también lo ocultamos si el usuario ya
    no tiene suscripción (p. ej. se le venció después de generarse), para que el
    privilegio se respete punta a punta."""
    return value if user.is_premium else None


async def _generate_and_save_feedback(
    session_id: uuid.UUID,
    payload: dict,
):
    """Background task: pedirle a Gemini el feedback y guardarlo en BD.

    Usa una sesión de BD nueva porque la del request ya está cerrada cuando
    esta tarea corre.
    """
    from app.services import config_service

    # Feature flag editable: si el feedback IA está apagado, no se gasta en Gemini.
    if not config_service.get("ai_feedback_enabled"):
        return
    feedback = await gemini_service.generate_practice_feedback(**payload)
    if not feedback:
        return
    async with async_session() as db:
        result = await db.execute(
            update(PracticeSession)
            .where(PracticeSession.id == session_id)
            .values(ai_feedback=feedback)
        )
        await db.commit()
    if result.rowcount != 1:
        logger.warning("No se guardó ai_feedback: sesión %s no encontrada", session_id)
        return
    logger.info("ai_feedback guardado para sesión %s", session_id)


@router.post("/api/practice/submit", response_model=PracticeSubmitResponse)
async def submit_practice(
    data: PracticeSubmitRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Registrar resultado de una sesión de práctica."""
    # Idempotencia: si esta práctica ya fue registrada (reintento de sync offline
    # con el mismo client_id), devolver lo existente sin re-procesar XP ni pedir
    # feedback IA de nuevo.
    if data.client_id:
        existing = await practice_service.get_session_by_client_id(
            db, data.client_id, current_user.id
        )
        if existing:
            user_xp = await ranking_service.get_or_create_user_xp(db, current_user.id)
            return PracticeSubmitResponse(
                session=PracticeSessionResponse(
                    id=existing.id,
                    user_id=existing.user_id,
                    lesson_id=existing.lesson_id,
                    score=existing.score,
                    correct_notes=existing.correct_notes,
                    total_notes=existing.total_notes,
                    wrong_notes=existing.wrong_notes,
                    missed_notes=existing.missed_notes,
                    average_tempo=existing.average_tempo,
                    expected_tempo=existing.expected_tempo,
                    tempo_accuracy=existing.tempo_accuracy,
                    total_time_seconds=existing.total_time_seconds,
                    errors_detail=existing.errors_detail,
                    ai_feedback=_visible_feedback(current_user, existing.ai_feedback),
                    completed=existing.completed,
                    created_at=existing.created_at,
                ),
                ai_feedback=_visible_feedback(current_user, existing.ai_feedback),
                current_level=user_xp.level,
            )

    try:
        session = await practice_service.submit_practice(db, data, current_user.id)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    # Procesar XP y logros
    xp_result = await ranking_service.process_practice_xp(
        db=db,
        user_id=current_user.id,
        score=data.score,
        difficulty=session.lesson.difficulty if session.lesson else "principiante",
        is_completed=data.completed and data.score >= 70,
        total_time_seconds=data.total_time_seconds,
    )

    # La tarea IA usa otra conexión; la sesión debe existir antes de actualizarla.
    await db.commit()

    # Feedback IA con Gemini: SOLO para usuarios premium (es función de pago).
    if current_user.is_premium:
        background_tasks.add_task(
            _generate_and_save_feedback,
            session_id=session.id,
            payload={
                "skill_level": current_user.skill_level,
                "lesson_title": session.lesson.title if session.lesson else "Lección",
                "difficulty": session.lesson.difficulty if session.lesson else "principiante",
                "tempo_bpm": session.expected_tempo,
                "score": session.score,
                "correct_notes": session.correct_notes,
                "wrong_notes": session.wrong_notes,
                "missed_notes": session.missed_notes,
                "total_notes": session.total_notes,
                "average_tempo": session.average_tempo,
                "tempo_accuracy": session.tempo_accuracy,
                "total_time_seconds": session.total_time_seconds,
                "errors_detail": session.errors_detail,
            },
        )

    # Mapear logros nuevos
    new_achievements = [
        AchievementResponse(
            id=ach.id,
            code=ach.code,
            name=ach.name,
            description=ach.description,
            icon=ach.icon,
            category=ach.category,
            xp_reward=ach.xp_reward,
            rarity=ach.rarity,
            requirement_type=ach.requirement_type,
            requirement_value=ach.requirement_value,
            is_unlocked=True,
            progress=ach.requirement_value,
        )
        for ach in xp_result["new_achievements"]
    ]

    return PracticeSubmitResponse(
        session=PracticeSessionResponse(
            id=session.id,
            user_id=session.user_id,
            lesson_id=session.lesson_id,
            score=session.score,
            correct_notes=session.correct_notes,
            total_notes=session.total_notes,
            wrong_notes=session.wrong_notes,
            missed_notes=session.missed_notes,
            average_tempo=session.average_tempo,
            expected_tempo=session.expected_tempo,
            tempo_accuracy=session.tempo_accuracy,
            total_time_seconds=session.total_time_seconds,
            errors_detail=session.errors_detail,
            ai_feedback=_visible_feedback(current_user, session.ai_feedback),
            completed=session.completed,
            created_at=session.created_at,
        ),
        ai_feedback=_visible_feedback(current_user, session.ai_feedback),
        xp_earned=xp_result["xp_earned"],
        new_level=xp_result["new_level"],
        current_level=xp_result["current_level"],
        new_achievements=new_achievements,
    )


@router.get(
    "/api/practice/sessions/{session_id}",
    response_model=PracticeSessionResponse,
)
async def get_practice_session(
    session_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener una sesión de práctica por ID. Útil para polling de ai_feedback."""
    from sqlalchemy import select
    from app.models.lesson import PracticeSession

    result = await db.execute(
        select(PracticeSession).where(
            PracticeSession.id == session_id,
            PracticeSession.user_id == current_user.id,
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sesión no encontrada",
        )
    return PracticeSessionResponse(
        id=session.id,
        user_id=session.user_id,
        lesson_id=session.lesson_id,
        score=session.score,
        correct_notes=session.correct_notes,
        total_notes=session.total_notes,
        wrong_notes=session.wrong_notes,
        missed_notes=session.missed_notes,
        average_tempo=session.average_tempo,
        expected_tempo=session.expected_tempo,
        tempo_accuracy=session.tempo_accuracy,
        total_time_seconds=session.total_time_seconds,
        errors_detail=session.errors_detail,
        ai_feedback=_visible_feedback(current_user, session.ai_feedback),
        completed=session.completed,
        created_at=session.created_at,
    )


@router.get("/api/practice/history", response_model=PaginatedResponse)
async def get_practice_history(
    lesson_id: uuid.UUID | None = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Historial de prácticas del usuario actual."""
    return await practice_service.get_practice_history(
        db,
        user_id=current_user.id,
        lesson_id=lesson_id,
        page=page,
        limit=limit,
        is_premium=current_user.is_premium,
    )


@router.get("/api/progress/stats", response_model=ProgressStats)
async def get_progress_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Estadísticas generales de progreso del usuario."""
    return await practice_service.get_user_progress_stats(db, current_user.id)


@router.get("/api/progress/weekly", response_model=list[WeeklyDataPoint])
async def get_weekly_progress(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Progreso de la última semana (para gráfico en Flutter)."""
    return await practice_service.get_weekly_progress(db, current_user.id)
