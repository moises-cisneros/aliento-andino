"""Modelos de lecciones, categorías, notas y sesiones de práctica para Aliento Andino."""

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.fingering import Fingering


class Category(Base):
    """Categorías de lecciones (Escalas, Acordes, Melodías, Ritmo, etc.)."""

    __tablename__ = "categories"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon: Mapped[str | None] = mapped_column(String(50), nullable=True)
    order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    # Relaciones
    lessons: Mapped[list["Lesson"]] = relationship(
        "Lesson", back_populates="category", lazy="selectin"
    )

    def __repr__(self) -> str:
        return f"<Category {self.name}>"


class Lesson(Base):
    """Lección/ejercicio de instrumento andino con metadatos y configuración musical."""

    __tablename__ = "lessons"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    category_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("categories.id", ondelete="CASCADE"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    instrument: Mapped[str] = mapped_column(
        String(20), nullable=False, default="quena", server_default="quena", index=True
    )
    difficulty: Mapped[str] = mapped_column(
        String(20), nullable=False
    )  # "principiante", "intermedio", "avanzado"
    tempo_bpm: Mapped[int] = mapped_column(Integer, nullable=False)
    time_signature: Mapped[str] = mapped_column(String(10), default="4/4")
    key_signature: Mapped[str] = mapped_column(String(10), default="C")
    # Metadatos de catálogo: género musical y autor/compositor (para filtrar y
    # explorar canciones). Nullable: los ejercicios técnicos no tienen autor.
    genre: Mapped[str | None] = mapped_column(String(40), nullable=True, index=True)
    artist: Mapped[str | None] = mapped_column(String(120), nullable=True)
    thumbnail_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    audio_preview_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    total_plays: Mapped[int] = mapped_column(Integer, default=0)
    average_score: Mapped[float] = mapped_column(Float, default=0.0)
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    # Relaciones
    category: Mapped["Category"] = relationship(
        "Category", back_populates="lessons", lazy="selectin"
    )
    notes: Mapped[list["NoteSequence"]] = relationship(
        "NoteSequence",
        back_populates="lesson",
        lazy="selectin",
        order_by="NoteSequence.position",
        cascade="all, delete-orphan",
    )
    practice_sessions: Mapped[list["PracticeSession"]] = relationship(
        "PracticeSession", back_populates="lesson", lazy="noload"
    )
    creator: Mapped["User"] = relationship("User", lazy="selectin")

    def __repr__(self) -> str:
        return f"<Lesson {self.title}>"


class NoteSequence(Base):
    """Secuencia de notas de un ejercicio (cada fila es una nota o silencio para aerófonos andinos)."""

    __tablename__ = "note_sequences"
    __table_args__ = (
        Index("ix_note_sequences_lesson_position", "lesson_id", "position"),
        Index("ix_note_sequences_fingering_id", "fingering_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    lesson_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("lessons.id", ondelete="CASCADE"),
        nullable=False,
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    note: Mapped[str] = mapped_column(String(10), nullable=False)  # "C4", "F#4", "Bb3", "REST"
    duration: Mapped[float] = mapped_column(
        Float, nullable=False
    )  # beats: 1.0=negra, 0.5=corchea, 2.0=blanca
    is_rest: Mapped[bool] = mapped_column(Boolean, default=False)
    breath_mark: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    velocity: Mapped[int] = mapped_column(Integer, default=80)
    fingering_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("fingerings.id", ondelete="SET NULL"),
        nullable=True,
    )
    fingering_data: Mapped[dict | list | None] = mapped_column(JSON, nullable=True)

    # Relaciones
    lesson: Mapped["Lesson"] = relationship("Lesson", back_populates="notes")
    fingering: Mapped["Fingering | None"] = relationship("Fingering")

    def __repr__(self) -> str:
        return f"<NoteSequence pos={self.position} note={self.note}>"


class PracticeSession(Base):
    """Sesión de práctica de un usuario en una lección."""

    __tablename__ = "practice_sessions"
    # Composite index for the paginated history query (user_id filter + newest first).
    __table_args__ = (
        Index("ix_practice_sessions_user_id_created_at", "user_id", text("created_at DESC")),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    lesson_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("lessons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # UUID de cliente para idempotencia de envíos (sync offline). Nullable +
    # unique: en Postgres los NULL no chocan, así que las sesiones online sin
    # client_id conviven con las offline deduplicadas.
    client_id: Mapped[str | None] = mapped_column(
        String(36), nullable=True, unique=True, index=True
    )
    score: Mapped[float] = mapped_column(Float, nullable=False)
    correct_notes: Mapped[int] = mapped_column(Integer, nullable=False)
    total_notes: Mapped[int] = mapped_column(Integer, nullable=False)
    wrong_notes: Mapped[int] = mapped_column(Integer, nullable=False)
    missed_notes: Mapped[int] = mapped_column(Integer, nullable=False)
    average_tempo: Mapped[float] = mapped_column(Float, nullable=False)
    expected_tempo: Mapped[int] = mapped_column(Integer, nullable=False)
    tempo_accuracy: Mapped[float] = mapped_column(Float, nullable=False)
    total_time_seconds: Mapped[float] = mapped_column(Float, nullable=False)
    errors_detail: Mapped[list | None] = mapped_column(JSON, nullable=True)
    ai_feedback: Mapped[str | None] = mapped_column(Text, nullable=True)
    completed: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Relaciones
    user: Mapped["User"] = relationship("User", lazy="selectin")
    lesson: Mapped["Lesson"] = relationship(
        "Lesson", back_populates="practice_sessions", lazy="selectin"
    )

    def __repr__(self) -> str:
        return f"<PracticeSession user={self.user_id} lesson={self.lesson_id} score={self.score}>"


# Importar User para que las relaciones funcionen
from app.models.user import User  # noqa: E402, F401
