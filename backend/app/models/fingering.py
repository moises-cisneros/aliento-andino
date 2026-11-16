"""Modelo de tablas de digitación (FingeringChart) para instrumentos de viento andinos.

Cataloga, por instrumento y nota (pitch), qué orificios/tubos deben cubrirse,
soportando digitaciones alternativas. Reemplaza, en el dominio de viento andino,
a los atributos de mano/dedo del teclado de PianoVision.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime,
    Index,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class FingeringChart(Base):
    """Digitación oficial de una nota para un instrumento de viento andino.

    `instrument`: "quena" | "zampona" | "tarka" | "flauta".
    `pitch`: nota en notación científica, p. ej. "G4".
    `holes`: JSON que describe el estado de cada orificio/tubo
        (p. ej. {"0": "closed", "1": "open", "2": "half", "back": "closed"}
        para Quena; o {"row": "arka", "tube": 3} para Zampoña/Siku).
    `alternate_fingerings`: JSON opcional con digitaciones alternativas.
    """

    __tablename__ = "fingering_charts"
    __table_args__ = (
        UniqueConstraint("instrument", "pitch", name="uq_fingering_instrument_pitch"),
        Index("ix_fingering_charts_instrument", "instrument"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    instrument: Mapped[str] = mapped_column(String(20), nullable=False)
    pitch: Mapped[str] = mapped_column(String(10), nullable=False)
    holes: Mapped[dict] = mapped_column(JSON, nullable=False)
    alternate_fingerings: Mapped[list | None] = mapped_column(JSON, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    def __repr__(self) -> str:
        return f"<FingeringChart {self.instrument} {self.pitch}>"
