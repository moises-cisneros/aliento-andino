"""Router para gestión de tokens FCM, historial in-app y envío de notificaciones."""

import logging
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models.notification import Notification, NotificationToken
from app.models.user import User
from app.schemas.auth import MessageResponse
from app.services import fcm_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/notifications", tags=["Notificaciones"])


class RegisterTokenRequest(BaseModel):
    token: str = Field(min_length=1, max_length=255)
    platform: str = Field(default="android", pattern=r"^(android|ios|web)$")


class DeleteTokenRequest(BaseModel):
    token: str


class NotificationItem(BaseModel):
    id: uuid.UUID
    type: str
    title: str
    body: str
    data: dict | None = None
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class NotificationListResponse(BaseModel):
    items: list[NotificationItem]
    total: int
    unread_count: int


class UnreadCountResponse(BaseModel):
    unread_count: int


@router.post("/register-token", response_model=MessageResponse)
async def register_token(
    data: RegisterTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Registrar o actualizar un token FCM del usuario actual."""
    # Si el token ya existe para otro usuario, reasignarlo (cambio de cuenta en el mismo device).
    result = await db.execute(
        select(NotificationToken).where(NotificationToken.token == data.token)
    )
    existing = result.scalar_one_or_none()
    if existing:
        existing.user_id = current_user.id
        existing.platform = data.platform
    else:
        db.add(
            NotificationToken(
                user_id=current_user.id,
                token=data.token,
                platform=data.platform,
            )
        )
    await db.commit()
    return MessageResponse(message="Token registrado")


@router.delete("/unregister-token", response_model=MessageResponse)
async def unregister_token(
    data: DeleteTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Eliminar un token FCM (al hacer logout o desinstalar)."""
    await db.execute(
        delete(NotificationToken).where(
            NotificationToken.token == data.token,
            NotificationToken.user_id == current_user.id,
        )
    )
    await db.commit()
    return MessageResponse(message="Token eliminado")


@router.post("/test", response_model=MessageResponse)
async def send_test_notification(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Enviar una notificación de prueba a todos los tokens del usuario actual.

    Respeta el flag `notifications_push_enabled` del usuario.
    """
    if not current_user.notifications_push_enabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tenés las notificaciones push desactivadas",
        )

    result = await db.execute(
        select(NotificationToken.token).where(NotificationToken.user_id == current_user.id)
    )
    tokens = [row[0] for row in result.all()]
    if not tokens:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No tenés tokens registrados",
        )

    success_count, invalid = await fcm_service.send_to_tokens(
        tokens=tokens,
        title="Aliento Andino",
        body="¡Notificaciones funcionando! 🎹",
        data={"type": "test"},
    )

    # Limpiar tokens inválidos
    if invalid:
        await db.execute(delete(NotificationToken).where(NotificationToken.token.in_(invalid)))
        await db.commit()

    if success_count == 0:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo enviar la notificación (revisar configuración FCM)",
        )

    return MessageResponse(message=f"Enviado a {success_count} dispositivo(s)")


# ============== HISTORIAL IN-APP ==============


@router.get("", response_model=NotificationListResponse)
async def list_notifications(
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Listar las últimas N notificaciones del usuario actual + unread count."""
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(limit)
    )
    items = list(result.scalars().all())

    total_result = await db.execute(
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == current_user.id)
    )
    total = total_result.scalar() or 0

    unread_result = await db.execute(
        select(func.count())
        .select_from(Notification)
        .where(
            Notification.user_id == current_user.id,
            Notification.is_read.is_(False),
        )
    )
    unread = unread_result.scalar() or 0

    return NotificationListResponse(
        items=[NotificationItem.model_validate(n) for n in items],
        total=total,
        unread_count=unread,
    )


@router.get("/unread-count", response_model=UnreadCountResponse)
async def unread_count(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Cantidad de notificaciones no leídas (para el badge de la campanita)."""
    result = await db.execute(
        select(func.count())
        .select_from(Notification)
        .where(
            Notification.user_id == current_user.id,
            Notification.is_read.is_(False),
        )
    )
    return UnreadCountResponse(unread_count=result.scalar() or 0)


@router.post("/mark-read/{notification_id}", response_model=MessageResponse)
async def mark_read(
    notification_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Marcar una notificación como leída."""
    result = await db.execute(
        update(Notification)
        .where(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
        .values(is_read=True)
    )
    await db.commit()
    if result.rowcount == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notificación no encontrada",
        )
    return MessageResponse(message="Marcada como leída")


@router.post("/mark-all-read", response_model=MessageResponse)
async def mark_all_read(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Marcar todas las notificaciones del usuario como leídas."""
    result = await db.execute(
        update(Notification)
        .where(
            Notification.user_id == current_user.id,
            Notification.is_read.is_(False),
        )
        .values(is_read=True)
    )
    await db.commit()
    return MessageResponse(message=f"{result.rowcount} notificaciones marcadas como leídas")
