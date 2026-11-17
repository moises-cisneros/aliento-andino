"""Schemas del agente tutor de IA."""

from pydantic import BaseModel, Field


class TutorTurn(BaseModel):
    """Un turno previo de la conversación (para dar contexto al agente)."""

    role: str = Field(description='"user" o "model"')
    text: str


class TutorChatRequest(BaseModel):
    """Mensaje del usuario al tutor + historial reciente + pantalla actual."""

    message: str = Field(min_length=1, max_length=1000)
    history: list[TutorTurn] = []
    current_route: str | None = Field(default=None, max_length=200)


class TutorAction(BaseModel):
    """Acción de UI que el cliente Flutter debe ejecutar."""

    tool: str
    args: dict


class TutorChatResponse(BaseModel):
    """Respuesta del agente: texto + acciones a ejecutar en el cliente."""

    reply: str
    actions: list[TutorAction] = []
