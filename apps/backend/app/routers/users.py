"""Router de perfiles de usuario, follows y búsqueda."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.services import user_service

router = APIRouter(prefix="/api/users", tags=["Users"])


@router.get("/search")
async def search_users(
    q: str = Query(min_length=2, max_length=100, description="Buscar por username o nombre"),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Buscar usuarios por username o full_name."""
    return await user_service.search_users(db, q, page, limit)


@router.get("/suggestions")
async def get_follow_suggestions(
    limit: int = Query(10, ge=1, le=30),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Usuarios sugeridos para seguir."""
    return await user_service.get_follow_suggestions(db, current_user.id, limit)


@router.get("/by-username/{username}")
async def get_user_by_username(
    username: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Resuelve un username a su id (para abrir el perfil desde una @mención)."""
    user = await user_service.get_user_by_username(db, username)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {
        "id": str(user.id),
        "username": user.username,
        "full_name": user.full_name,
        "avatar_url": user.avatar_url,
    }


@router.get("/{user_id}/profile")
async def get_user_profile(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Perfil público de un usuario."""
    profile = await user_service.get_user_profile(db, user_id, current_user.id)
    if not profile:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return profile


@router.get("/{user_id}/posts")
async def get_user_posts(
    user_id: uuid.UUID,
    cursor: str | None = Query(None),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Posts de un usuario específico."""
    cursor_dt = None
    if cursor:
        try:
            cursor_dt = datetime.fromisoformat(cursor)
        except ValueError:
            raise HTTPException(status_code=400, detail="Formato de cursor inválido")

    return await user_service.get_user_posts(db, user_id, current_user.id, cursor_dt, limit)


@router.get("/{user_id}/media")
async def get_user_media(
    user_id: uuid.UUID,
    cursor: str | None = Query(None),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Posts con media de un usuario (pestaña Media del perfil)."""
    cursor_dt = None
    if cursor:
        try:
            cursor_dt = datetime.fromisoformat(cursor)
        except ValueError:
            raise HTTPException(status_code=400, detail="Formato de cursor inválido")

    return await user_service.get_user_media(db, user_id, current_user.id, cursor_dt, limit)


@router.post("/{user_id}/follow")
async def toggle_follow(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Toggle follow/unfollow de un usuario."""
    try:
        return await user_service.toggle_follow(db, current_user.id, user_id)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))


@router.get("/{user_id}/followers")
async def get_followers(
    user_id: uuid.UUID,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lista de seguidores de un usuario."""
    return await user_service.get_followers(db, user_id, current_user.id, page, limit)


@router.get("/{user_id}/following")
async def get_following(
    user_id: uuid.UUID,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lista de usuarios que sigue."""
    return await user_service.get_following(db, user_id, current_user.id, page, limit)
