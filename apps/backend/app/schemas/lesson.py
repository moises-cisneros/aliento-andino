"""Schemas Pydantic para lecciones, categorías, notas y práctica."""

import re
import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

# --- Regex para validar notas musicales ---
NOTE_PATTERN = re.compile(r"^[A-G][#b]?[0-8]$")


# ===================== CATEGORY =====================


class CategoryCreate(BaseModel):
    """Schema para crear categoría."""

    name: str = Field(min_length=1, max_length=100)
    description: str | None = None
    icon: str | None = None
    order: int = 0


class CategoryUpdate(BaseModel):
    """Schema para editar categoría (todos opcionales)."""

    name: str | None = Field(None, min_length=1, max_length=100)
    description: str | None = None
    icon: str | None = None
    order: int | None = None
    is_active: bool | None = None


class CategoryResponse(BaseModel):
    """Schema de respuesta de categoría."""

    id: uuid.UUID
    name: str
    description: str | None = None
    icon: str | None = None
    order: int
    is_active: bool
    created_at: datetime
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


class CategoryWithCount(BaseModel):
    """Categoría con conteo de lecciones (para listado público)."""

    id: uuid.UUID
    name: str
    description: str | None = None
    icon: str | None = None
    order: int
    is_active: bool = True
    lessons_count: int = 0

    model_config = {"from_attributes": True}


# ===================== NOTE SEQUENCE =====================


class NoteSequenceCreate(BaseModel):
    """Schema para crear una nota en la secuencia."""

    position: int = Field(ge=1)
    note: str = Field(max_length=10)
    duration: float = Field(gt=0)
    is_rest: bool = False
    finger: int | None = Field(None, ge=1, le=5)
    hand: str | None = None
    velocity: int = Field(default=80, ge=0, le=127)
    is_chord: bool = False
    chord_group: int | None = None

    @field_validator("note")
    @classmethod
    def validate_note(cls, v: str, info) -> str:
        """Validar formato de nota musical o silencio."""
        # Si es silencio, aceptar "REST"
        if info.data.get("is_rest"):
            return v if v else "REST"
        if not NOTE_PATTERN.match(v):
            raise ValueError(
                f"Formato de nota inválido: '{v}'. Usar notación científica (ej: C4, F#4, Bb3)"
            )
        return v

    @field_validator("hand")
    @classmethod
    def validate_hand(cls, v: str | None) -> str | None:
        if v is not None and v not in ("left", "right", "both"):
            raise ValueError("hand debe ser 'left', 'right' o 'both'")
        return v


class NoteSequenceResponse(BaseModel):
    """Schema de respuesta de una nota."""

    id: uuid.UUID
    position: int
    note: str
    duration: float
    is_rest: bool
    finger: int | None = None
    hand: str | None = None
    velocity: int
    is_chord: bool
    chord_group: int | None = None

    model_config = {"from_attributes": True}


# ===================== LESSON =====================


class LessonCreate(BaseModel):
    """Schema para crear lección con sus notas."""

    category_id: uuid.UUID
    title: str = Field(min_length=3, max_length=255)
    description: str = Field(min_length=1)
    difficulty: str
    tempo_bpm: int = Field(ge=40, le=200)
    time_signature: str = "4/4"
    key_signature: str = "C"
    thumbnail_url: str | None = None
    audio_preview_url: str | None = None
    duration_seconds: int | None = None
    is_premium: bool = False
    order: int = 0
    notes: list[NoteSequenceCreate] = []

    @field_validator("difficulty")
    @classmethod
    def validate_difficulty(cls, v: str) -> str:
        allowed = ("principiante", "intermedio", "avanzado")
        if v not in allowed:
            raise ValueError(f"difficulty debe ser uno de: {allowed}")
        return v


class LessonUpdate(BaseModel):
    """Schema para editar lección (sin notas)."""

    category_id: uuid.UUID | None = None
    title: str | None = Field(None, min_length=3, max_length=255)
    description: str | None = None
    difficulty: str | None = None
    tempo_bpm: int | None = Field(None, ge=40, le=200)
    time_signature: str | None = None
    key_signature: str | None = None
    thumbnail_url: str | None = None
    audio_preview_url: str | None = None
    duration_seconds: int | None = None
    is_premium: bool | None = None
    order: int | None = None
    is_active: bool | None = None

    @field_validator("difficulty")
    @classmethod
    def validate_difficulty(cls, v: str | None) -> str | None:
        if v is not None:
            allowed = ("principiante", "intermedio", "avanzado")
            if v not in allowed:
                raise ValueError(f"difficulty debe ser uno de: {allowed}")
        return v


class NotesUpdateRequest(BaseModel):
    """Schema para reemplazar toda la secuencia de notas."""

    notes: list[NoteSequenceCreate]


class LessonResponse(BaseModel):
    """Schema de respuesta de lección."""

    id: uuid.UUID
    category_id: uuid.UUID
    title: str
    description: str
    difficulty: str
    tempo_bpm: int
    time_signature: str
    key_signature: str
    genre: str | None = None
    artist: str | None = None
    thumbnail_url: str | None = None
    audio_preview_url: str | None = None
    duration_seconds: int | None = None
    order: int
    is_active: bool
    is_premium: bool
    total_plays: int
    average_score: float
    created_by: uuid.UUID | None = None
    created_at: datetime
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


class LessonWithNotes(LessonResponse):
    """Lección con secuencia de notas completa (para detalle)."""

    notes: list[NoteSequenceResponse] = []
    category_name: str | None = None
    creator_name: str | None = None
    user_best_score: float | None = None
    user_attempts: int = 0


class LessonListItem(LessonResponse):
    """Lección para listado con info extra del usuario."""

    category_name: str | None = None
    notes_count: int = 0
    user_best_score: float | None = None
    requires_premium: bool = False


class LessonAdminListItem(LessonResponse):
    """Lección para listado admin."""

    category_name: str | None = None
    notes_count: int = 0
    creator_name: str | None = None


# ===================== PRACTICE SESSION =====================


class PracticeSubmitRequest(BaseModel):
    """Schema para enviar resultado de práctica."""

    lesson_id: uuid.UUID
    # UUID generado en el cliente para idempotencia: si llega dos veces (p. ej.
    # un reintento de sincronización offline), no se duplica la sesión ni el XP.
    client_id: uuid.UUID | None = None
    score: float = Field(ge=0, le=100)
    correct_notes: int = Field(ge=0)
    total_notes: int = Field(ge=1)
    wrong_notes: int = Field(ge=0)
    missed_notes: int = Field(ge=0)
    average_tempo: float = Field(ge=0)
    total_time_seconds: float = Field(ge=0)
    errors_detail: list[dict] | None = None
    completed: bool = True


class PracticeSessionResponse(BaseModel):
    """Schema de respuesta de sesión de práctica."""

    id: uuid.UUID
    user_id: uuid.UUID
    lesson_id: uuid.UUID
    score: float
    correct_notes: int
    total_notes: int
    wrong_notes: int
    missed_notes: int
    average_tempo: float
    expected_tempo: int
    tempo_accuracy: float
    total_time_seconds: float
    errors_detail: list[dict] | None = None
    ai_feedback: str | None = None
    completed: bool
    created_at: datetime
    lesson_title: str | None = None

    model_config = {"from_attributes": True}


class PracticeSessionResult(PracticeSessionResponse):
    """Respuesta de POST /api/v1/practice/session: la sesión más el XP otorgado.

    En un reintento idempotente (mismo client_id) `xp_earned` es 0.
    """

    xp_earned: int = 0
    new_level: bool = False
    current_level: int = 1
    new_achievements: list = []


class PracticeSubmitResponse(BaseModel):
    """Respuesta después de enviar práctica."""

    session: PracticeSessionResponse
    ai_feedback: str | None = None
    xp_earned: int = 0
    new_level: bool = False
    current_level: int = 1
    new_achievements: list = []


# ===================== PROGRESS / STATS =====================


class ProgressStats(BaseModel):
    """Estadísticas generales del usuario."""

    total_sessions: int = 0
    total_lessons_played: int = 0
    average_score: float = 0.0
    best_score: float = 0.0
    total_practice_time: float = 0.0  # segundos
    lessons_completed: int = 0  # score >= 70
    current_streak: int = 0  # días consecutivos
    favorite_category: str | None = None


class WeeklyDataPoint(BaseModel):
    """Dato de un día para el gráfico semanal."""

    date: str  # "2026-04-01"
    sessions_count: int = 0
    average_score: float = 0.0
    practice_minutes: float = 0.0


class AdminStatsOverview(BaseModel):
    """Estadísticas para dashboard admin."""

    total_lessons: int = 0
    total_categories: int = 0
    total_practice_sessions: int = 0
    total_users_active: int = 0
    most_played_lesson: str | None = None
    highest_rated_lesson: str | None = None
    average_global_score: float = 0.0


# ===================== PAGINACIÓN =====================


class PaginatedResponse(BaseModel):
    """Respuesta paginada genérica."""

    items: list = []
    total: int = 0
    page: int = 1
    pages: int = 1
