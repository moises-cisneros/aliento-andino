"""Schemas Pydantic para el módulo de afinación acústica y tolerancias."""

from pydantic import BaseModel, Field


class InstrumentTuningResponse(BaseModel):
    instrument: str = Field(
        ..., description="Nombre del instrumento andino (quena, zampona, tarka)"
    )
    base_hz: float = Field(..., description="Frecuencia fundamental base en Hertz")
    allowed_cents_tolerance: float = Field(
        ..., description="Tolerancia permitida en cents para considerar afinada una nota"
    )
    description: str = Field(..., description="Descripción acústica y rango característico")
