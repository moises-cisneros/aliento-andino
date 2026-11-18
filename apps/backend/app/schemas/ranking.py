"""Schemas Pydantic para rankings, XP y logros."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

# ===================== RANKING ENTRIES =====================


class RankingEntry(BaseModel):
    """Entrada de leaderboard global/semanal."""

    rank: int
    user_id: uuid.UUID
    username: str
    full_name: str
    avatar_url: str | None = None
    total_xp: int = 0
    weekly_xp: int = 0
    level: int = 1
    total_lessons_completed: int = 0


class StreakRankingEntry(BaseModel):
    """Entrada de leaderboard de rachas."""

    rank: int
    user_id: uuid.UUID
    username: str
    full_name: str
    avatar_url: str | None = None
    current_streak: int = 0
    longest_streak: int = 0


class LessonRankingEntry(BaseModel):
    """Entrada de ranking por lección."""

    rank: int
    user_id: uuid.UUID
    username: str
    full_name: str
    avatar_url: str | None = None
    score: float
    tempo_accuracy: float = 0.0
    created_at: datetime | None = None


# ===================== LEADERBOARD RESPONSES =====================


class GlobalLeaderboardResponse(BaseModel):
    """Respuesta del leaderboard global."""

    leaderboard: list[RankingEntry]
    my_rank: int
    my_xp: int
    my_level: int


class WeeklyLeaderboardResponse(BaseModel):
    """Respuesta del leaderboard semanal."""

    leaderboard: list[RankingEntry]
    my_rank: int
    my_weekly_xp: int
    days_remaining: int


class LessonLeaderboardResponse(BaseModel):
    """Respuesta del ranking por lección."""

    leaderboard: list[LessonRankingEntry]
    my_best_score: float
    my_rank: int


class StreakLeaderboardResponse(BaseModel):
    """Respuesta del leaderboard de rachas."""

    leaderboard: list[StreakRankingEntry]
    my_rank: int = 0
    my_streak: int
    my_longest: int


# ===================== INSTRUMENT LEADERBOARD (SUB-12-A / HU-12) =====================


class UserRankingResponse(BaseModel):
    """Entrada individual de ranking de usuario para leaderboards."""

    rank: int
    user_id: uuid.UUID
    username: str
    full_name: str
    avatar_url: str | None = None
    xp: int
    total_xp: int = 0
    weekly_xp: int = 0
    level: int = 1
    instrument: str | None = None


class LeaderboardResponse(BaseModel):
    """Respuesta estructurada del leaderboard filtrado por instrumento y scope."""

    items: list[UserRankingResponse]
    user_rank: int | None = None
    instrument: str | None = None
    scope: str = "weekly"
    leaderboard: list[UserRankingResponse] | None = None


# ===================== USER XP =====================


class MyXPResponse(BaseModel):
    """Datos completos de XP del usuario actual."""

    total_xp: int = 0
    weekly_xp: int = 0
    level: int = 1
    xp_for_current_level: int = 0
    xp_for_next_level: int = 100
    xp_progress_percentage: float = 0.0
    current_streak: int = 0
    longest_streak: int = 0
    streak_freezes: int = 0
    total_sessions: int = 0
    total_minutes: float = 0.0
    total_completed: int = 0
    total_perfect: int = 0
    average_score: float = 0.0
    global_rank: int = 0
    weekly_rank: int = 0


# ===================== ACHIEVEMENTS =====================


class AchievementResponse(BaseModel):
    """Logro con estado del usuario."""

    id: uuid.UUID
    code: str
    name: str
    description: str
    icon: str
    category: str
    xp_reward: int = 0
    rarity: str = "common"
    requirement_type: str
    requirement_value: int
    is_unlocked: bool = False
    unlocked_at: datetime | None = None
    progress: int = 0


class AchievementsListResponse(BaseModel):
    """Lista de todos los logros con estado del usuario."""

    achievements: list[AchievementResponse]
    total_unlocked: int = 0
    total_available: int = 0


class UserAchievementResponse(BaseModel):
    """Logro desbloqueado por el usuario (recientes)."""

    id: uuid.UUID
    achievement_id: uuid.UUID
    code: str
    name: str
    description: str
    icon: str
    category: str
    xp_reward: int = 0
    rarity: str = "common"
    unlocked_at: datetime


# ===================== ADMIN =====================


class AchievementCreate(BaseModel):
    """Crear nuevo logro (admin)."""

    code: str = Field(min_length=1, max_length=50)
    name: str = Field(min_length=1, max_length=100)
    description: str = Field(min_length=1, max_length=500)
    icon: str = Field(min_length=1, max_length=50)
    category: str = Field(min_length=1, max_length=30)
    xp_reward: int = Field(default=0, ge=0)
    requirement_type: str = Field(min_length=1, max_length=30)
    requirement_value: int = Field(ge=0)
    rarity: str = Field(default="common", max_length=20)


class AchievementUpdate(BaseModel):
    """Editar logro (admin)."""

    name: str | None = None
    description: str | None = None
    icon: str | None = None
    category: str | None = None
    xp_reward: int | None = None
    requirement_type: str | None = None
    requirement_value: int | None = None
    rarity: str | None = None
    order: int | None = None


class AdminAchievementResponse(BaseModel):
    """Logro para admin (incluye stats)."""

    id: uuid.UUID
    code: str
    name: str
    description: str
    icon: str
    category: str
    xp_reward: int
    requirement_type: str
    requirement_value: int
    rarity: str
    order: int
    is_active: bool
    unlocked_count: int = 0
    created_at: datetime


class TopUserSummary(BaseModel):
    """Usuario con más XP (para la tarjeta destacada de Rankings)."""

    username: str
    level: int = 1
    total_xp: int = 0


class RankingStatsResponse(BaseModel):
    """Estadísticas del sistema de rankings (admin)."""

    total_xp_distributed: int = 0
    # Alias que consume el front (mismo valor que total_xp_distributed).
    total_xp_awarded: int = 0
    total_users_with_xp: int = 0
    average_level: float = 0.0
    max_level: int = 0
    total_achievements_unlocked: int = 0
    most_unlocked_achievement: str | None = None
    hardest_achievement: str | None = None
    users_with_active_streak: int = 0
    longest_active_streak: int = 0
    top_user: TopUserSummary | None = None


# ===================== PRACTICE SUBMIT XP EXTENSION =====================


class XPGainResult(BaseModel):
    """Resultado de XP ganado después de practice submit."""

    xp_earned: int = 0
    new_level: bool = False
    current_level: int = 1
    new_achievements: list[AchievementResponse] = []
