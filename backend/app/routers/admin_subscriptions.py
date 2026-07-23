"""Router admin de suscripciones.

Los pagos son SIMULADOS (no hay pasarela real ni facturas): solo se expone el
ESTADO de suscripción por usuario + KPIs. Los ingresos son estimados.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin
from app.models.user import User
from app.services import audit_service, subscription_service

router = APIRouter(prefix="/api/admin/subscriptions", tags=["Admin Subscriptions"])


class GrantRequest(BaseModel):
    plan: str = Field(pattern=r"^(monthly|annual|trial)$")


def _sub_state(user: User) -> dict:
    return {
        "id": str(user.id),
        "subscription_status": user.subscription_status,
        "subscription_plan": user.subscription_plan,
        "plan_label": subscription_service.plan_label(user.subscription_plan),
        "subscription_expires_at": user.subscription_expires_at,
        "is_premium": user.is_premium,
    }


def _parse_uuid(user_id: str) -> uuid.UUID:
    try:
        return uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="ID inválido")


@router.get("")
async def list_subscriptions(
    status: str | None = Query(None),  # "free" | "premium"
    plan: str | None = Query(None),  # "monthly" | "annual" | "trial"
    search: str | None = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lista paginada de suscripciones de clientes (estado premium por usuario)."""
    return await subscription_service.admin_list_subscriptions(
        db, page=page, limit=limit, status_filter=status, plan=plan, search=search
    )


@router.get("/summary")
async def subscription_summary(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """KPIs de suscripciones: premium/free, por plan e ingresos estimados."""
    return await subscription_service.admin_subscription_summary(db)


@router.post("/{user_id}/grant")
async def grant_subscription(
    user_id: str,
    payload: GrantRequest,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Otorga/extiende premium a un usuario (mensual, anual o prueba)."""
    user = await subscription_service.admin_grant(db, _parse_uuid(user_id), payload.plan)
    await audit_service.log(
        db, current_admin, "subscription.grant", "user", user_id,
        {"plan": payload.plan},
    )
    return _sub_state(user)


@router.post("/{user_id}/cancel")
async def cancel_subscription_admin(
    user_id: str,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Cancela la suscripción de un usuario (baja a free)."""
    user = await subscription_service.admin_cancel(db, _parse_uuid(user_id))
    await audit_service.log(
        db, current_admin, "subscription.cancel", "user", user_id,
    )
    return _sub_state(user)
