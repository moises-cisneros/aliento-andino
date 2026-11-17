"""Lógica de suscripción con PAGO SIMULADO (sin pasarela real).

Activar una suscripción solo marca al usuario como premium y fija el
vencimiento. No se cobra ni se guardan datos de tarjeta.
"""

from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.services import config_service

# Estructura de planes (label/period/días). El PRECIO ahora sale de la config
# editable (config_service), no de acá; estos valores son solo el fallback.
PLANS: dict[str, dict] = {
    "monthly": {"label": "Mensual", "price_usd": 4.99, "period": "mes", "days": 30},
    "annual": {"label": "Anual", "price_usd": 39.99, "period": "año", "days": 365},
}


def plan_price(plan: str) -> float:
    """Precio actual del plan (desde la config editable)."""
    cfg = config_service.get(f"price_{plan}")
    if cfg is not None:
        return float(cfg)
    return float(PLANS.get(plan, {}).get("price_usd", 0))


def trial_days() -> int:
    """Días de prueba gratis (config editable)."""
    return int(config_service.get("trial_days") or 7)


def plan_label(plan: str | None) -> str | None:
    if plan is None:
        return None
    if plan == "trial":
        return "Prueba gratis"
    return PLANS.get(plan, {}).get("label")


async def activate_subscription(db: AsyncSession, user: User, plan: str) -> User:
    """Activa (o extiende) la suscripción premium del usuario."""
    info = PLANS[plan]
    now = datetime.now(UTC)
    # Si ya tiene tiempo vigente, se acumula desde el vencimiento; si no, desde hoy.
    base = (
        user.subscription_expires_at
        if (user.subscription_expires_at and user.subscription_expires_at > now)
        else now
    )
    user.subscription_status = "premium"
    user.subscription_plan = plan
    user.subscription_started_at = user.subscription_started_at or now
    user.subscription_expires_at = base + timedelta(days=info["days"])
    await db.commit()
    await db.refresh(user)
    return user


async def start_trial(db: AsyncSession, user: User) -> User:
    """Activa una prueba gratis de premium por TRIAL_DAYS días (una sola vez)."""
    if user.subscription_trial_used:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya usaste tu prueba gratis",
        )
    if user.is_premium:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya tenés premium activo",
        )
    now = datetime.now(UTC)
    user.subscription_status = "premium"
    user.subscription_plan = "trial"
    user.subscription_started_at = user.subscription_started_at or now
    user.subscription_expires_at = now + timedelta(days=trial_days())
    user.subscription_trial_used = True
    await db.commit()
    await db.refresh(user)
    return user


async def cancel_subscription(db: AsyncSession, user: User) -> User:
    """Cancela la suscripción (baja inmediata a free)."""
    user.subscription_status = "free"
    user.subscription_plan = None
    user.subscription_expires_at = None
    await db.commit()
    await db.refresh(user)
    return user


# ---------------------------------------------------------------------------
# Admin: acciones sobre la suscripción de un usuario (otorgar / cancelar).
# ---------------------------------------------------------------------------


async def _get_user_or_404(db: AsyncSession, user_id) -> User:
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return user


async def admin_grant(db: AsyncSession, user_id, plan: str) -> User:
    """El admin otorga/extiende premium a un usuario (mensual, anual o prueba)."""
    user = await _get_user_or_404(db, user_id)
    if plan == "trial":
        now = datetime.now(UTC)
        base = (
            user.subscription_expires_at
            if (user.subscription_expires_at and user.subscription_expires_at > now)
            else now
        )
        user.subscription_status = "premium"
        user.subscription_plan = "trial"
        user.subscription_started_at = user.subscription_started_at or now
        user.subscription_expires_at = base + timedelta(days=trial_days())
        await db.commit()
        await db.refresh(user)
        return user
    if plan not in PLANS:
        raise HTTPException(status_code=400, detail="Plan inválido")
    return await activate_subscription(db, user, plan)


async def admin_cancel(db: AsyncSession, user_id) -> User:
    """El admin cancela la suscripción de un usuario (baja a free)."""
    user = await _get_user_or_404(db, user_id)
    return await cancel_subscription(db, user)


# ---------------------------------------------------------------------------
# Admin: vista de suscripciones de clientes (pago simulado → solo estado).
# ---------------------------------------------------------------------------


async def admin_list_subscriptions(
    db: AsyncSession,
    page: int = 1,
    limit: int = 20,
    status_filter: str | None = None,  # "free" | "premium"
    plan: str | None = None,  # "monthly" | "annual" | "trial"
    search: str | None = None,
) -> dict:
    """Lista paginada de usuarios con su estado de suscripción, para el admin."""
    conditions = []
    if status_filter == "premium":
        conditions.append(User.subscription_status == "premium")
    elif status_filter == "free":
        conditions.append(User.subscription_status != "premium")
    if plan:
        conditions.append(User.subscription_plan == plan)
    if search:
        term = f"%{search}%"
        conditions.append(
            or_(
                User.email.ilike(term),
                User.username.ilike(term),
                User.full_name.ilike(term),
            )
        )
    where = and_(*conditions) if conditions else True

    total = (await db.execute(select(func.count()).select_from(User).where(where))).scalar() or 0

    offset = (page - 1) * limit
    result = await db.execute(
        select(User).where(where).order_by(User.created_at.desc()).offset(offset).limit(limit)
    )
    users = list(result.scalars().all())

    now = datetime.now(UTC)
    items = []
    for u in users:
        exp = u.subscription_expires_at
        days_left = None
        if exp is not None:
            if exp.tzinfo is None:
                exp = exp.replace(tzinfo=UTC)
            days_left = max(0, (exp - now).days)
        items.append(
            {
                "id": str(u.id),
                "email": u.email,
                "username": u.username,
                "full_name": u.full_name,
                "subscription_status": u.subscription_status,
                "subscription_plan": u.subscription_plan,
                "plan_label": plan_label(u.subscription_plan),
                "subscription_started_at": u.subscription_started_at,
                "subscription_expires_at": u.subscription_expires_at,
                "subscription_trial_used": u.subscription_trial_used,
                "is_premium": u.is_premium,
                "days_until_expiry": days_left,
            }
        )

    pages = (total + limit - 1) // limit if limit else 1
    return {"items": items, "total": total, "page": page, "pages": pages}


async def admin_subscription_summary(db: AsyncSession) -> dict:
    """KPIs de suscripciones para el admin. Los ingresos son ESTIMADOS (los
    pagos son simulados: precio del plan × suscripciones activas)."""
    now = datetime.now(UTC)

    async def cnt(condition) -> int:
        return (
            await db.execute(select(func.count()).select_from(User).where(condition))
        ).scalar() or 0

    total_users = (await db.execute(select(func.count()).select_from(User))).scalar() or 0

    active = User.subscription_expires_at > now
    premium_active = await cnt(and_(User.subscription_status == "premium", active))
    monthly = await cnt(and_(User.subscription_plan == "monthly", active))
    annual = await cnt(and_(User.subscription_plan == "annual", active))
    trial = await cnt(and_(User.subscription_plan == "trial", active))
    trials_used = await cnt(User.subscription_trial_used.is_(True))

    mrr = monthly * plan_price("monthly") + annual * (plan_price("annual") / 12)
    return {
        "total_users": total_users,
        "premium_active": premium_active,
        "free": max(0, total_users - premium_active),
        "monthly": monthly,
        "annual": annual,
        "trial": trial,
        "trials_used": trials_used,
        "estimated_mrr_usd": round(mrr, 2),
        "estimated_arr_usd": round(mrr * 12, 2),
        "simulated": True,
    }
