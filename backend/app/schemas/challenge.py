"""Schemas Pydantic para desafíos semanales."""

from pydantic import BaseModel


class WeeklyChallengeItem(BaseModel):
    """Un desafío semanal con el progreso del usuario."""
    key: str
    title: str
    description: str
    target: int
    progress: int
    completed: bool


class WeeklyChallengesResponse(BaseModel):
    """Lista de desafíos de la semana + días restantes para el reset."""
    challenges: list[WeeklyChallengeItem]
    days_remaining: int
