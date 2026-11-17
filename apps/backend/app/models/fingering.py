"""Modelo de base de datos para catálogo oficial de digitaciones por instrumento andino (HU-05, SUB-05-B)."""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Index, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Fingering(Base):
    """Digitación registrada para un instrumento andino (Quena, Zampoña, Tarka)."""

    __tablename__ = "fingerings"
    __table_args__ = (
        Index("ix_fingerings_instrument_note_octave", "instrument", "note", "octave"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    instrument: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    note: Mapped[str] = mapped_column(String(10), nullable=False)
    octave: Mapped[int] = mapped_column(Integer, nullable=False)
    holes_covered: Mapped[list] = mapped_column(JSON, nullable=False)
    is_alternate: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    def __repr__(self) -> str:
        alt_str = " (alterna)" if self.is_alternate else ""
        return f"<Fingering {self.instrument} {self.note}{self.octave}{alt_str}>"
