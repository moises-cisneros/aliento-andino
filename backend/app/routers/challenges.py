"""Router de desafíos semanales para usuarios autenticados."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.challenge import WeeklyChallengesResponse
from app.services import challenge_service

router = APIRouter(tags=["Desafíos"])


@router.get("/api/challenges/weekly", response_model=WeeklyChallengesResponse)
async def weekly_challenges(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Desafíos de la semana actual con el progreso del usuario."""
    return await challenge_service.get_weekly_challenges(db, current_user.id)
