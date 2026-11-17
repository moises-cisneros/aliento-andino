"""Schemas Pydantic para catálogo oficial de digitaciones por instrumento andino (HU-05, SUB-05-B)."""

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator


class FingeringCreate(BaseModel):
    """Schema para registrar una digitación en el catálogo oficial."""

    instrument: str = Field(..., description="Instrumento andino: quena, zampona o tarka")
    note: str = Field(
        ..., min_length=1, max_length=10, description="Tono musical (ej: G, C#, Sol, Do)"
    )
    octave: int = Field(..., ge=1, le=8, description="Octava musical (ej: 4, 5, 6)")
    holes_covered: list[Any] = Field(
        ...,
        min_length=1,
        description="Array de orificios/tubos cubiertos (Quena: 7, Tarka: 6, Zampoña: tubos activos)",
    )
    is_alternate: bool = Field(
        default=False,
        description="Indica si es una digitación alterna (True) o la digitación principal (False)",
    )
    description: str | None = Field(default=None, description="Nota técnica o contexto pedagógico")

    @field_validator("instrument")
    @classmethod
    def validate_instrument(cls, v: str) -> str:
        allowed = ("quena", "zampona", "tarka")
        normalized = v.strip().lower()
        if normalized not in allowed:
            raise ValueError(f"instrument debe ser uno de: {allowed}")
        return normalized

    @field_validator("holes_covered")
    @classmethod
    def validate_holes_covered(cls, v: list[Any], info) -> list[Any]:
        if not isinstance(v, list) or len(v) == 0:
            raise ValueError("holes_covered debe ser un array no vacío de orificios o tubos")

        instrument = info.data.get("instrument")
        if instrument == "quena" and len(v) != 7:
            raise ValueError(
                "holes_covered para Quena debe contener exactamente 7 elementos (pulgar + 6 frontales)"
            )
        if instrument == "tarka" and len(v) != 6:
            raise ValueError(
                "holes_covered para Tarka debe contener exactamente 6 elementos (6 orificios frontales)"
            )
        if instrument == "zampona" and len(v) > 13:
            raise ValueError(
                "holes_covered para Zampoña no puede exceder 13 tubos (ira: 6, arca: 7)"
            )

        return v


class FingeringResponse(BaseModel):
    """Schema de respuesta para digitación registrada."""

    id: uuid.UUID
    instrument: str
    note: str
    octave: int
    holes_covered: list[Any]
    is_alternate: bool
    description: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}
