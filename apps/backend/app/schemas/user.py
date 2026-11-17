"""Schemas para actualización y consulta de perfiles de usuario (HU-19 / SUB-19-B)."""

from pydantic import BaseModel, Field, field_validator

from app.schemas.auth import UserResponse

VALID_ANDEAN_INSTRUMENTS = {"quena", "zampona", "tarka"}


class UserUpdate(BaseModel):
    """Schema para actualizar perfil, preferencias de instrumentos y calibración de soplo."""

    full_name: str | None = Field(None, min_length=1, max_length=255)
    avatar_url: str | None = Field(None, max_length=500)
    preferred_instruments: list[str] | None = Field(
        None, description="Lista de instrumentos andinos preferidos (quena, zampona, tarka)"
    )
    breath_sensitivity_rms: float | None = Field(
        None,
        ge=0.0,
        le=1.0,
        description="Sensibilidad de soplo basal RMS calibrada (entre 0.0 y 1.0)",
    )

    @field_validator("preferred_instruments")
    @classmethod
    def validate_instruments(cls, v: list[str] | None) -> list[str] | None:
        if v is not None:
            normalized = []
            for inst in v:
                clean = inst.strip().lower()
                if clean not in VALID_ANDEAN_INSTRUMENTS:
                    raise ValueError(
                        f"Instrumento '{inst}' inválido. Solo se admiten: {', '.join(sorted(VALID_ANDEAN_INSTRUMENTS))}"
                    )
                if clean not in normalized:
                    normalized.append(clean)
            return normalized
        return v


__all__ = ["UserUpdate", "UserResponse", "VALID_ANDEAN_INSTRUMENTS"]
