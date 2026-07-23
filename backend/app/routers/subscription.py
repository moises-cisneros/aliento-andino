"""Endpoints de suscripción con pago SIMULADO."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.subscription import (
    CheckoutRequest,
    PlanInfo,
    SubscriptionStatus,
)
from app.services import subscription_service

router = APIRouter(prefix="/api/subscription", tags=["subscription"])


def _status(user: User) -> SubscriptionStatus:
    return SubscriptionStatus(
        is_premium=user.is_premium,
        status=user.subscription_status,
        plan=user.subscription_plan,
        plan_label=subscription_service.plan_label(user.subscription_plan),
        expires_at=user.subscription_expires_at,
        started_at=user.subscription_started_at,
        trial_used=user.subscription_trial_used,
        trial_available=not user.subscription_trial_used and not user.is_premium,
    )


@router.get("/plans", response_model=list[PlanInfo])
async def get_plans():
    """Planes disponibles (precio editable desde el admin; el pago es simulado)."""
    return [
        PlanInfo(
            id=pid,
            label=info["label"],
            price_usd=subscription_service.plan_price(pid),
            period=info["period"],
            days=info["days"],
        )
        for pid, info in subscription_service.PLANS.items()
    ]


@router.get("/me", response_model=SubscriptionStatus)
async def my_subscription(user: User = Depends(get_current_user)):
    return _status(user)


@router.post("/checkout", response_model=SubscriptionStatus)
async def checkout(
    payload: CheckoutRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Pago SIMULADO: valida el formato de la tarjeta y activa premium.

    No se cobra nada ni se guardan datos de tarjeta.
    """
    if payload.plan not in subscription_service.PLANS:
        raise HTTPException(status_code=400, detail="Plan inválido")

    digits = payload.card_number.replace(" ", "")
    if not digits.isdigit() or not (13 <= len(digits) <= 19):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Número de tarjeta inválido",
        )
    if not payload.card_holder.strip():
        raise HTTPException(status_code=422, detail="Falta el titular de la tarjeta")

    user = await subscription_service.activate_subscription(db, user, payload.plan)
    return _status(user)


@router.post("/trial", response_model=SubscriptionStatus)
async def start_trial(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Inicia la prueba gratis de 7 días (una sola vez por usuario)."""
    user = await subscription_service.start_trial(db, user)
    return _status(user)


@router.post("/cancel", response_model=SubscriptionStatus)
async def cancel(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    user = await subscription_service.cancel_subscription(db, user)
    return _status(user)
