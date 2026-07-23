"""Router de administración de rankings y logros."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin
from app.models.user import User
from app.schemas.ranking import (
    AchievementCreate,
    AchievementUpdate,
    AdminAchievementResponse,
    RankingStatsResponse,
)
from app.services import ranking_service

router = APIRouter(tags=["Admin Rankings"])


@router.get("/api/admin/rankings/stats", response_model=RankingStatsResponse)
async def get_ranking_stats(
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    """Estadísticas del sistema de rankings."""
    return await ranking_service.get_ranking_stats(db)


@router.get(
    "/api/admin/achievements",
    response_model=list[AdminAchievementResponse],
)
async def get_admin_achievements(
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    """Lista todos los logros con stats de desbloqueo."""
    return await ranking_service.get_admin_achievements(db)


@router.post(
    "/api/admin/achievements",
    response_model=AdminAchievementResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_achievement(
    data: AchievementCreate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    """Crear un nuevo logro."""
    achievement = await ranking_service.create_achievement(db, data.model_dump())
    return {
        **{
            "id": achievement.id,
            "code": achievement.code,
            "name": achievement.name,
            "description": achievement.description,
            "icon": achievement.icon,
            "category": achievement.category,
            "xp_reward": achievement.xp_reward,
            "requirement_type": achievement.requirement_type,
            "requirement_value": achievement.requirement_value,
            "rarity": achievement.rarity,
            "order": achievement.order,
            "is_active": achievement.is_active,
            "created_at": achievement.created_at,
        },
        "unlocked_count": 0,
    }


@router.put(
    "/api/admin/achievements/{achievement_id}",
    response_model=AdminAchievementResponse,
)
async def update_achievement(
    achievement_id: uuid.UUID,
    data: AchievementUpdate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    """Editar un logro existente."""
    achievement = await ranking_service.update_achievement(
        db, achievement_id, data.model_dump(exclude_unset=True)
    )
    if not achievement:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Logro no encontrado",
        )
    return {
        "id": achievement.id,
        "code": achievement.code,
        "name": achievement.name,
        "description": achievement.description,
        "icon": achievement.icon,
        "category": achievement.category,
        "xp_reward": achievement.xp_reward,
        "requirement_type": achievement.requirement_type,
        "requirement_value": achievement.requirement_value,
        "rarity": achievement.rarity,
        "order": achievement.order,
        "is_active": achievement.is_active,
        "unlocked_count": 0,
        "created_at": achievement.created_at,
    }


@router.delete("/api/admin/achievements/{achievement_id}")
async def delete_achievement(
    achievement_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    """Desactivar un logro (soft delete)."""
    success = await ranking_service.delete_achievement(db, achievement_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Logro no encontrado",
        )
    return {"message": "Logro desactivado exitosamente"}
