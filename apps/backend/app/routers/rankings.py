"""Router de rankings y logros para usuarios autenticados."""

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.ranking import (
    AchievementsListResponse,
    GlobalLeaderboardResponse,
    LeaderboardResponse,
    LessonLeaderboardResponse,
    MyXPResponse,
    StreakLeaderboardResponse,
    UserAchievementResponse,
    WeeklyLeaderboardResponse,
)
from app.services import ranking_service

router = APIRouter(tags=["Rankings y Logros"])


# ===================== LEADERBOARDS =====================


@router.get("/api/v1/rankings/leaderboard", response_model=LeaderboardResponse)
@router.get("/api/rankings/leaderboard", response_model=LeaderboardResponse)
async def get_instrument_leaderboard(
    instrument: str | None = Query(None, description="Instrumento andino: quena, zampona, tarka"),
    scope: str = Query("weekly", description="Scope válido: weekly, all_time"),
    limit: int = Query(50, ge=1, le=100, description="Límite de usuarios en el ranking"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Consulta agregada por XP semanal o histórico filtrada por instrumento andino."""
    return await ranking_service.get_leaderboard(
        db=db,
        user_id=current_user.id,
        instrument=instrument,
        scope=scope,
        limit=limit,
    )


@router.get("/api/rankings/global", response_model=GlobalLeaderboardResponse)
async def get_global_leaderboard(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Top 50 usuarios por XP total."""
    result = await ranking_service.get_global_leaderboard(db, current_user.id)
    return result


@router.get("/api/rankings/weekly", response_model=WeeklyLeaderboardResponse)
async def get_weekly_leaderboard(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Top 50 usuarios por XP semanal."""
    result = await ranking_service.get_weekly_leaderboard(db, current_user.id)
    return result


@router.get("/api/rankings/friends", response_model=GlobalLeaderboardResponse)
async def get_friends_leaderboard(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Ranking entre la gente que seguís (+ vos) por XP total."""
    result = await ranking_service.get_friends_leaderboard(db, current_user.id)
    return result


@router.get("/api/rankings/lesson/{lesson_id}", response_model=LessonLeaderboardResponse)
async def get_lesson_leaderboard(
    lesson_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Top 20 mejores scores en una lección."""
    result = await ranking_service.get_lesson_leaderboard(db, current_user.id, lesson_id)
    return result


@router.get("/api/rankings/streaks", response_model=StreakLeaderboardResponse)
async def get_streaks_leaderboard(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Top 30 usuarios por racha actual."""
    result = await ranking_service.get_streaks_leaderboard(db, current_user.id)
    return result


# ===================== MY XP =====================


@router.get("/api/rankings/my-xp", response_model=MyXPResponse)
async def get_my_xp(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Datos completos de XP del usuario actual."""
    result = await ranking_service.get_my_xp(db, current_user.id)
    return result


# ===================== LOGROS =====================


@router.get("/api/rankings/achievements", response_model=AchievementsListResponse)
async def get_achievements(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista todos los logros con estado del usuario."""
    result = await ranking_service.get_all_achievements(db, current_user.id)
    return result


@router.get(
    "/api/rankings/achievements/recent",
    response_model=list[UserAchievementResponse],
)
async def get_recent_achievements(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Últimos 5 logros desbloqueados por el usuario."""
    return await ranking_service.get_recent_achievements(db, current_user.id)
