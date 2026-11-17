"""Servicio de configuración de afinación y tolerancias para instrumentos andinos."""

from fastapi import HTTPException

from app.schemas.tuning import InstrumentTuningResponse

ANDEAN_TUNING_CONFIG: dict[str, dict] = {
    "quena": {
        "instrument": "quena",
        "base_hz": 392.00,  # Sol4 (G4)
        "allowed_cents_tolerance": 15.0,
        "description": "Quena tradicional en Sol mayor (G4). Rango cromático Sol4 a Sol6.",
    },
    "zampona": {
        "instrument": "zampona",
        "base_hz": 392.00,  # Sol4 (G4)
        "allowed_cents_tolerance": 20.0,
        "description": "Zampoña diatónica o cromática (Ira y Arca). Rango Sol4 a Mi6.",
    },
    "tarka": {
        "instrument": "tarka",
        "base_hz": 523.25,  # Do5 (C5)
        "allowed_cents_tolerance": 25.0,
        "description": "Tarka tradicional en Do (C5). Timbre con sobretono armónico característico.",
    },
}


class TuningService:
    @staticmethod
    def get_all_tolerances() -> list[InstrumentTuningResponse]:
        """Retorna la lista de tolerancias para todos los instrumentos soportados."""
        return [InstrumentTuningResponse(**data) for data in ANDEAN_TUNING_CONFIG.values()]

    @staticmethod
    def get_instrument_tolerance(instrument: str) -> InstrumentTuningResponse:
        """Retorna la tolerancia y nota base para un instrumento andino específico."""
        key = instrument.strip().lower()
        if key not in ANDEAN_TUNING_CONFIG:
            raise HTTPException(
                status_code=400,
                detail="Instrumento no admitido. Valores válidos: quena, zampona, tarka",
            )
        return InstrumentTuningResponse(**ANDEAN_TUNING_CONFIG[key])
