"""Registro y consulta de la auditoría de acciones del admin."""

from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_log import AdminAuditLog
from app.models.user import User


async def log(
    db: AsyncSession,
    admin: User,
    action: str,
    target_type: str | None = None,
    target_id: str | None = None,
    detail: dict[str, Any] | None = None,
    commit: bool = True,
) -> None:
    """Registra una acción del admin.

    Nunca debe romper la operación principal: si falla el insert, se ignora
    (la acción de negocio ya se hizo). Por defecto hace su propio commit.
    """
    try:
        entry = AdminAuditLog(
            admin_id=admin.id if admin else None,
            admin_email=admin.email if admin else None,
            action=action,
            target_type=target_type,
            target_id=str(target_id) if target_id is not None else None,
            detail=detail,
        )
        db.add(entry)
        if commit:
            await db.commit()
    except Exception:  # noqa: BLE001 - la auditoría no debe tumbar la acción
        try:
            await db.rollback()
        except Exception:  # noqa: BLE001
            pass


async def list_logs(
    db: AsyncSession,
    page: int = 1,
    limit: int = 30,
    action: str | None = None,
    target_type: str | None = None,
    admin_id: str | None = None,
) -> dict:
    """Lista paginada de entradas de auditoría (más recientes primero)."""
    conditions = []
    if action:
        conditions.append(AdminAuditLog.action == action)
    if target_type:
        conditions.append(AdminAuditLog.target_type == target_type)
    if admin_id:
        conditions.append(AdminAuditLog.admin_id == admin_id)
    where = conditions if conditions else [True]

    total = (
        await db.execute(
            select(func.count()).select_from(AdminAuditLog).where(*where)
        )
    ).scalar() or 0

    offset = (page - 1) * limit
    rows = (
        await db.execute(
            select(AdminAuditLog)
            .where(*where)
            .order_by(AdminAuditLog.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
    ).scalars().all()

    items = [
        {
            "id": str(r.id),
            "admin_id": str(r.admin_id) if r.admin_id else None,
            "admin_email": r.admin_email,
            "action": r.action,
            "target_type": r.target_type,
            "target_id": r.target_id,
            "detail": r.detail,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]
    pages = (total + limit - 1) // limit if limit > 0 else 1
    return {"items": items, "total": total, "page": page, "pages": pages}
