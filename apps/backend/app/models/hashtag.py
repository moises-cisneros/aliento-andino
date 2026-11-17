"""Modelos de hashtags para la red social."""

import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Hashtag(Base):
    """Hashtag normalizado (en minúscula, sin '#')."""

    __tablename__ = "hashtags"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tag: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    posts_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class PostHashtag(Base):
    """Relación post ↔ hashtag (un post puede tener varios hashtags)."""

    __tablename__ = "post_hashtags"
    __table_args__ = (
        UniqueConstraint("post_id", "hashtag_id", name="uq_post_hashtag"),
        Index("ix_post_hashtags_hashtag_id", "hashtag_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    post_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("posts.id", ondelete="CASCADE"),
        nullable=False,
    )
    hashtag_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("hashtags.id", ondelete="CASCADE"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
