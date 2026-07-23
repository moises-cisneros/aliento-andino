"""Router del agente tutor de IA (function calling con Gemini/Vertex)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.tutor import TutorChatRequest, TutorChatResponse
from app.services import tutor_service

router = APIRouter(prefix="/api", tags=["Tutor IA"])


@router.post("/tutor/chat", response_model=TutorChatResponse)
async def tutor_chat(
    data: TutorChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Un turno del agente tutor. Devuelve texto + acciones de UI a ejecutar."""
    history = [turn.model_dump() for turn in data.history]
    result = await tutor_service.run_tutor_turn(
        db, current_user, data.message, history, current_route=data.current_route
    )
    return result
