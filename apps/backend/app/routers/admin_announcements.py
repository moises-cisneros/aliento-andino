"""Router admin de anuncios: envía una notificación push a un segmento de
usuarios (todos / premium / free), reutilizando el dispatcher FCM existente.
"""

from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin
from app.models.user import User
from app.services import audit_service, notification_dispatcher

router = APIRouter(prefix="/api/admin/announcements", tags=["Admin Announcements"])


class AnnouncementRequest(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    body: str = Field(min_length=1, max_length=500)
    segment: str = Field(default="all", pattern=r"^(all|premium|free)$")


@router.post("")
async def send_announcement(
    payload: AnnouncementRequest,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Envía un anuncio (push + notificación in-app) al segmento elegido.

    Devuelve cuántos usuarios se alcanzaron y a cuántos dispositivos se entregó
    el push (los que no tienen push activado igual reciben la notificación en la
    campanita)."""
    now = datetime.now(UTC)
    # Nunca a baneados/inactivos.
    conditions = [User.is_active.is_(True), User.is_banned.is_(False)]
    if payload.segment == "premium":
        conditions.append(User.subscription_status == "premium")
        conditions.append(User.subscription_expires_at > now)
    elif payload.segment == "free":
        conditions.append(
            or_(
                User.subscription_status != "premium",
                User.subscription_expires_at.is_(None),
                User.subscription_expires_at <= now,
            )
        )

    result = await db.execute(select(User.id).where(and_(*conditions)))
    user_ids = [r[0] for r in result.all()]

    delivered = await notification_dispatcher.notify_users(
        db,
        user_ids=user_ids,
        title=payload.title,
        body=payload.body,
        data={"type": "announcement"},
    )
    await audit_service.log(
        db,
        current_admin,
        "announcement.send",
        "announcement",
        None,
        {
            "segment": payload.segment,
            "title": payload.title,
            "recipients": len(user_ids),
        },
    )
    return {
        "segment": payload.segment,
        "recipients": len(user_ids),
        "delivered": delivered,
    }
