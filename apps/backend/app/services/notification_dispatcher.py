"""Helper para disparar notificaciones FCM a usuarios específicos.

Maneja:
- Lookup de tokens del usuario
- Filtrado por flag notifications_push_enabled
- Limpieza de tokens caducos
- Errores silenciosos (nunca rompe el flujo principal)
"""

import logging
import uuid
from collections.abc import Iterable

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification, NotificationToken
from app.models.user import User
from app.services import fcm_service

logger = logging.getLogger(__name__)


async def notify_user(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> int:
    """Envía una notificación a un usuario, respetando sus preferencias.

    Devuelve la cantidad de dispositivos a los que se entregó.
    Nunca lanza excepción.
    """
    try:
        notif_type = (data or {}).get("type", "generic")

        # Persistir SIEMPRE en BD (incluso si el push está apagado o no hay tokens)
        # para que el usuario vea el historial en la campanita.
        db.add(
            Notification(
                user_id=user_id,
                type=notif_type,
                title=title,
                body=body,
                data=data,
            )
        )
        await db.commit()

        # Verificar flag de preferencia push
        result = await db.execute(select(User.notifications_push_enabled).where(User.id == user_id))
        row = result.first()
        if not row or not row[0]:
            return 0

        # Obtener tokens del user
        tokens_result = await db.execute(
            select(NotificationToken.token).where(NotificationToken.user_id == user_id)
        )
        tokens = [t[0] for t in tokens_result.all()]
        if not tokens:
            return 0

        success, invalid = await fcm_service.send_to_tokens(
            tokens=tokens,
            title=title,
            body=body,
            data=data,
        )

        # Limpiar tokens inválidos
        if invalid:
            await db.execute(delete(NotificationToken).where(NotificationToken.token.in_(invalid)))
            await db.commit()

        return success
    except Exception as e:
        logger.error("notify_user falló: %s", e, exc_info=True)
        return 0


async def notify_users(
    db: AsyncSession,
    *,
    user_ids: Iterable[uuid.UUID],
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> int:
    """Envía la misma notificación a múltiples usuarios."""
    total = 0
    for uid in user_ids:
        total += await notify_user(
            db,
            user_id=uid,
            title=title,
            body=body,
            data=data,
        )
    return total
