"""Modelos de rankings, XP y logros para Aliento Andino."""

import uuid
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UserXP(Base):
    """Puntos de experiencia acumulados por usuario."""

    __tablename__ = "user_xp"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        index=True,
        nullable=False,
    )
    total_xp: Mapped[int] = mapped_column(Integer, default=0)
    weekly_xp: Mapped[int] = mapped_column(Integer, default=0, index=True)
    level: Mapped[int] = mapped_column(Integer, default=1)
    current_streak: Mapped[int] = mapped_column(Integer, default=0)
    longest_streak: Mapped[int] = mapped_column(Integer, default=0)
    # "Congeladores" de racha: protegen la racha ante UN día perdido. Se ganan
    # con hitos de racha (cada 7 días) y se consumen automáticamente al volver.
    streak_freezes: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    total_practice_sessions: Mapped[int] = mapped_column(Integer, default=0)
    total_practice_minutes: Mapped[float] = mapped_column(Float, default=0.0)
    total_lessons_completed: Mapped[int] = mapped_column(Integer, default=0)
    total_perfect_scores: Mapped[int] = mapped_column(Integer, default=0)
    average_score: Mapped[float] = mapped_column(Float, default=0.0)
    last_practice_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    week_start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    # Relación
    user = relationship("User", lazy="selectin")

    def __repr__(self) -> str:
        return f"<UserXP user={self.user_id} xp={self.total_xp}>"


class Achievement(Base):
    """Logros disponibles en el sistema."""

    __tablename__ = "achievements"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str] = mapped_column(String(500), nullable=False)
    icon: Mapped[str] = mapped_column(String(50), nullable=False)
    category: Mapped[str] = mapped_column(String(30), nullable=False)
    xp_reward: Mapped[int] = mapped_column(Integer, default=0)
    requirement_type: Mapped[str] = mapped_column(String(30), nullable=False)
    requirement_value: Mapped[int] = mapped_column(Integer, nullable=False)
    rarity: Mapped[str] = mapped_column(String(20), default="common")
    order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    def __repr__(self) -> str:
        return f"<Achievement {self.code}>"


class UserAchievement(Base):
    """Logros desbloqueados por usuario."""

    __tablename__ = "user_achievements"

    __table_args__ = (UniqueConstraint("user_id", "achievement_id", name="uq_user_achievement"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    achievement_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("achievements.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    unlocked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # Relaciones
    user = relationship("User", lazy="selectin")
    achievement = relationship("Achievement", lazy="selectin")

    def __repr__(self) -> str:
        return f"<UserAchievement user={self.user_id} achievement={self.achievement_id}>"
