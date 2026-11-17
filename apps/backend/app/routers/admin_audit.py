"""Router admin de auditoría: consulta del registro de acciones."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin
from app.models.user import User
from app.services import audit_service

router = APIRouter(prefix="/api/admin/audit", tags=["Admin Audit"])


@router.get("")
async def list_audit(
    action: str | None = Query(None),
    target_type: str | None = Query(None),
    admin_id: str | None = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(30, ge=1, le=100),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lista paginada del registro de auditoría (más recientes primero)."""
    return await audit_service.list_logs(
        db,
        page=page,
        limit=limit,
        action=action,
        target_type=target_type,
        admin_id=admin_id,
    )
