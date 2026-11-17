"""Router admin de moderación social: reportes, posts, comentarios y bans."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin
from app.models.user import User
from app.schemas.social import BanRequest, ReportUpdateStatus
from app.services import audit_service, auth_service, social_service, user_service


class SetAdminRequest(BaseModel):
    is_admin: bool


router = APIRouter(prefix="/api/admin", tags=["Admin Social"])


@router.get("/reports")
async def get_reports(
    status_filter: str | None = Query(None, alias="status"),
    reason: str | None = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lista de reportes con filtros."""
    return await social_service.get_reports_paginated(
        db, page, limit, status=status_filter, reason=reason
    )


@router.put("/reports/{report_id}")
async def update_report(
    report_id: uuid.UUID,
    data: ReportUpdateStatus,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Actualizar estado de un reporte."""
    report = await social_service.update_report_status(db, report_id, data.status, current_admin.id)
    if not report:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")

    await audit_service.log(
        db,
        current_admin,
        "report.update",
        "report",
        str(report_id),
        {"status": data.status},
    )
    return {
        "id": str(report.id),
        "status": report.status,
        "reviewed_by": str(report.reviewed_by),
        "reviewed_at": report.reviewed_at.isoformat() if report.reviewed_at else None,
    }


@router.delete("/posts/{post_id}")
async def admin_delete_post(
    post_id: uuid.UUID,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin fuerza eliminación de un post."""
    success = await social_service.admin_delete_post(db, post_id)
    if not success:
        raise HTTPException(status_code=404, detail="Post no encontrado")
    await audit_service.log(db, current_admin, "post.delete", "post", str(post_id))
    return {"message": "Post eliminado por admin"}


@router.delete("/comments/{comment_id}")
async def admin_delete_comment(
    comment_id: uuid.UUID,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin elimina un comentario."""
    success = await social_service.admin_delete_comment(db, comment_id)
    if not success:
        raise HTTPException(status_code=404, detail="Comentario no encontrado")
    await audit_service.log(db, current_admin, "comment.delete", "comment", str(comment_id))
    return {"message": "Comentario eliminado por admin"}


@router.post("/users/{user_id}/ban")
async def ban_user(
    user_id: uuid.UUID,
    data: BanRequest,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Banear un usuario."""
    if user_id == current_admin.id:
        raise HTTPException(status_code=422, detail="No puedes banearte a ti mismo")

    success = await user_service.ban_user(db, user_id, data.reason)
    if not success:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    await audit_service.log(
        db,
        current_admin,
        "user.ban",
        "user",
        str(user_id),
        {"reason": data.reason},
    )
    return {"message": "Usuario baneado correctamente"}


@router.post("/users/{user_id}/unban")
async def unban_user(
    user_id: uuid.UUID,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Desbanear un usuario."""
    success = await user_service.unban_user(db, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    await audit_service.log(db, current_admin, "user.unban", "user", str(user_id))
    return {"message": "Usuario desbaneado correctamente"}


@router.get("/social/stats")
async def get_social_stats(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Estadísticas de la red social."""
    return await social_service.get_social_stats(db)


@router.get("/users")
async def list_users(
    search: str | None = Query(None),
    is_banned: bool | None = Query(None),
    is_admin: bool | None = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lista paginada de usuarios para administración."""
    return await user_service.admin_list_users(
        db,
        page=page,
        limit=limit,
        search=search,
        is_banned=is_banned,
        is_admin=is_admin,
    )


@router.get("/users/{user_id}")
async def get_user_detail(
    user_id: uuid.UUID,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Detalle de un usuario con su actividad."""
    detail = await user_service.admin_get_user_detail(db, user_id)
    if detail is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return detail


@router.post("/users/{user_id}/set-admin")
async def set_admin(
    user_id: uuid.UUID,
    payload: SetAdminRequest,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Da o quita el rol de admin a un usuario."""
    if user_id == current_admin.id and not payload.is_admin:
        raise HTTPException(status_code=422, detail="No puedes quitarte el admin a ti mismo")
    res = await user_service.admin_set_admin(db, user_id, payload.is_admin)
    if res is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    await audit_service.log(
        db,
        current_admin,
        "user.grant_admin" if payload.is_admin else "user.revoke_admin",
        "user",
        str(user_id),
        {"is_admin": payload.is_admin},
    )
    return res


@router.post("/users/{user_id}/reset-password")
async def reset_user_password(
    user_id: uuid.UUID,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Dispara el envío del email de reseteo de contraseña al usuario."""
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if user.auth_provider != "local":
        return {
            "message": f"{user.email} inicia sesión con Google; no tiene contraseña que resetear."
        }
    await auth_service.forgot_password(user.email, db)
    await audit_service.log(
        db,
        current_admin,
        "user.reset_password",
        "user",
        str(user_id),
        {"email": user.email},
    )
    return {"message": f"Se envió el email de reseteo a {user.email}."}
