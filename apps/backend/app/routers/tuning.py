"""Router FastAPI para consulta de calibración y tolerancias de afinación andina."""

from fastapi import APIRouter

from app.schemas.tuning import InstrumentTuningResponse
from app.services.tuning_service import TuningService

router = APIRouter(prefix="/api/v1/tuning", tags=["tuning"])


@router.get("/tolerances", response_model=list[InstrumentTuningResponse])
async def get_all_tolerances():
    """Obtiene la configuración de afinación y tolerancia en cents para los instrumentos andinos."""
    return TuningService.get_all_tolerances()


@router.get("/tolerances/{instrument}", response_model=InstrumentTuningResponse)
async def get_instrument_tolerance(instrument: str):
    """Obtiene la tolerancia y nota base para un instrumento andino específico."""
    return TuningService.get_instrument_tolerance(instrument)
