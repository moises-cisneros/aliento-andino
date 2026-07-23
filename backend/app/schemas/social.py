"""Schemas Pydantic para red social: posts, comentarios, likes, follows y reportes."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator


# ===================== USER SUMMARY =====================

class UserSummary(BaseModel):
    """Resumen de usuario reutilizable en posts, comments, etc."""
    id: uuid.UUID
    username: str
    full_name: str
    avatar_url: str | None = None

    model_config = {"from_attributes": True}


# ===================== PRACTICE SESSION SUMMARY =====================

class PracticeSessionSummary(BaseModel):
    """Resumen de sesión de práctica para vincular en posts."""
    id: uuid.UUID
    score: float
    correct_notes: int
    total_notes: int
    total_time_seconds: float
    lesson_title: str | None = None

    model_config = {"from_attributes": True}


# ===================== POST =====================

class PostCreate(BaseModel):
    """Schema para crear publicación."""
    content: str = Field(min_length=1, max_length=2000)
    post_type: str = "text"
    media_url: str | None = Field(None, max_length=500)
    practice_session_id: uuid.UUID | None = None

    @field_validator("post_type")
    @classmethod
    def validate_post_type(cls, v: str) -> str:
        valid = {"text", "image", "video", "practice_result"}
        if v not in valid:
            raise ValueError(f"Tipo de post inválido. Opciones: {valid}")
        return v


class PostUpdate(BaseModel):
    """Schema para editar publicación (solo contenido)."""
    content: str = Field(min_length=1, max_length=2000)


class PostResponse(BaseModel):
    """Respuesta de publicación con datos del usuario y estado de like."""
    id: uuid.UUID
    user: UserSummary
    content: str
    post_type: str
    media_url: str | None = None
    media_thumbnail_url: str | None = None
    practice_session: PracticeSessionSummary | None = None
    likes_count: int
    comments_count: int
    is_liked_by_me: bool = False
    is_saved_by_me: bool = False
    created_at: datetime
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


class PostDetailResponse(PostResponse):
    """Detalle de publicación con últimos comentarios."""
    recent_comments: list["CommentResponse"] = []


# ===================== COMMENT =====================

class CommentCreate(BaseModel):
    """Schema para crear comentario (o reply si parent_comment_id está presente)."""
    content: str = Field(min_length=1, max_length=500)
    parent_comment_id: uuid.UUID | None = None


class CommentUpdate(BaseModel):
    """Schema para editar comentario (solo contenido)."""
    content: str = Field(min_length=1, max_length=500)


class CommentResponse(BaseModel):
    """Respuesta de comentario."""
    id: uuid.UUID
    post_id: uuid.UUID
    user: UserSummary
    content: str
    replies_count: int = 0
    likes_count: int = 0
    is_liked_by_me: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


# ===================== LIKE =====================

class LikeToggleResponse(BaseModel):
    """Respuesta de toggle like."""
    liked: bool
    likes_count: int


# ===================== FOLLOW =====================

class FollowToggleResponse(BaseModel):
    """Respuesta de toggle follow."""
    following: bool
    followers_count: int


# ===================== USER PROFILE =====================

class UserProfileResponse(BaseModel):
    """Perfil público de usuario."""
    id: uuid.UUID
    username: str
    full_name: str
    avatar_url: str | None = None
    bio: str | None = None
    followers_count: int
    following_count: int
    posts_count: int
    is_followed_by_me: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


# ===================== REPORT =====================

class ReportCreate(BaseModel):
    """Schema para crear reporte de contenido."""
    post_id: uuid.UUID | None = None
    comment_id: uuid.UUID | None = None
    reported_user_id: uuid.UUID | None = None
    reason: str = Field(min_length=1, max_length=50)
    description: str | None = Field(None, max_length=1000)

    @field_validator("reason")
    @classmethod
    def validate_reason(cls, v: str) -> str:
        valid = {"spam", "inappropriate", "harassment", "hate_speech", "other"}
        if v not in valid:
            raise ValueError(f"Razón inválida. Opciones: {valid}")
        return v


class ReportResponse(BaseModel):
    """Respuesta de reporte."""
    id: uuid.UUID
    reporter: UserSummary
    post_id: uuid.UUID | None = None
    comment_id: uuid.UUID | None = None
    reported_user_id: uuid.UUID | None = None
    reason: str
    description: str | None = None
    status: str
    reviewed_by: uuid.UUID | None = None
    reviewed_at: datetime | None = None
    created_at: datetime

    # Contenido reportado (para admin)
    post_content: str | None = None
    comment_content: str | None = None
    reported_username: str | None = None

    model_config = {"from_attributes": True}


class ReportUpdateStatus(BaseModel):
    """Schema para actualizar estado de reporte."""
    status: str

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        valid = {"reviewed", "resolved", "dismissed"}
        if v not in valid:
            raise ValueError(f"Estado inválido. Opciones: {valid}")
        return v


# ===================== CURSOR PAGINATION =====================

class CursorPaginatedResponse(BaseModel):
    """Respuesta paginada por cursor para feed/infinite scroll."""
    items: list
    next_cursor: str | None = None
    has_more: bool = False


# ===================== PAGINATED (offset) =====================

class PaginatedUsersResponse(BaseModel):
    """Respuesta paginada de usuarios."""
    items: list[UserSummary]
    total: int
    page: int
    pages: int


# ===================== ADMIN SOCIAL STATS =====================

class SocialStatsResponse(BaseModel):
    """Estadísticas de la red social para admin."""
    total_posts: int
    total_comments: int
    total_likes: int
    total_reports_pending: int
    total_users_banned: int
    most_active_users: list[UserSummary]


# ===================== BAN =====================

class BanRequest(BaseModel):
    """Schema para banear usuario."""
    reason: str = Field(min_length=1, max_length=500)


class MessageResponse(BaseModel):
    """Respuesta genérica de mensaje."""
    message: str
