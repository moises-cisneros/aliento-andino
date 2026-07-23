"""Router admin de exportación a CSV (usuarios, suscripciones, lecciones)."""

from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin
from app.models.user import User
from app.services import csv_export_service

router = APIRouter(prefix="/api/admin/export", tags=["Admin Export"])


def _csv_response(content: str, filename: str) -> Response:
    return Response(
        content=content,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/users.csv")
async def export_users(
    search: str | None = Query(None),
    is_banned: bool | None = Query(None),
    is_admin: bool | None = Query(None),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Exporta la lista de usuarios (con los mismos filtros que la vista)."""
    csv_str = await csv_export_service.users_csv(
        db, search=search, is_banned=is_banned, is_admin=is_admin
    )
    return _csv_response(csv_str, "usuarios.csv")


@router.get("/subscriptions.csv")
async def export_subscriptions(
    status_filter: str | None = Query(None, alias="status"),
    plan: str | None = Query(None),
    search: str | None = Query(None),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Exporta la lista de suscripciones de clientes."""
    csv_str = await csv_export_service.subscriptions_csv(
        db, status_filter=status_filter, plan=plan, search=search
    )
    return _csv_response(csv_str, "suscripciones.csv")


@router.get("/lesson-performance.csv")
async def export_lesson_performance(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Exporta el rendimiento por lección (intentos y score promedio)."""
    csv_str = await csv_export_service.lesson_performance_csv(db)
    return _csv_response(csv_str, "rendimiento-lecciones.csv")
