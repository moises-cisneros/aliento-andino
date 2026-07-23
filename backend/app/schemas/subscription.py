"""Schemas de suscripción (pago simulado)."""

from datetime import datetime

from pydantic import BaseModel, Field


class PlanInfo(BaseModel):
    id: str
    label: str
    price_usd: float
    period: str  # "mes" | "año"
    days: int


class CheckoutRequest(BaseModel):
    """Datos de pago SIMULADO. La tarjeta NO se procesa ni se guarda."""

    plan: str = Field(pattern=r"^(monthly|annual)$")
    card_number: str
    card_holder: str
    card_expiry: str  # "MM/YY"
    card_cvc: str


class SubscriptionStatus(BaseModel):
    is_premium: bool
    status: str
    plan: str | None = None
    plan_label: str | None = None
    expires_at: datetime | None = None
    started_at: datetime | None = None
    trial_used: bool = False
    # True si el usuario puede arrancar la prueba gratis (no la usó y no es premium).
    trial_available: bool = False
