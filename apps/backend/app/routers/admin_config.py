"""Router admin de configuración editable (precios, trial, feature flags)."""

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin
from app.models.user import User
from app.services import audit_service, config_service

router = APIRouter(prefix="/api/admin/config", tags=["Admin Config"])


class ConfigUpdate(BaseModel):
    price_monthly: float | None = None
    price_annual: float | None = None
    trial_days: int | None = None
    ai_feedback_enabled: bool | None = None


@router.get("")
async def get_config(
    current_admin: User = Depends(get_current_admin),
):
    """Devuelve la configuración editable actual."""
    return config_service.all_settings()


@router.put("")
async def update_config(
    payload: ConfigUpdate,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Actualiza la config (solo los campos enviados) y refresca el cache."""
    changes = {k: v for k, v in payload.model_dump().items() if v is not None}
    result = await config_service.update(db, changes)
    await audit_service.log(db, current_admin, "config.update", "config", None, changes)
    return result
