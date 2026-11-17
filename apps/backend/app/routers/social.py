"""Router de red social: feed, posts, likes, comentarios y reportes."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.social import (
    CommentCreate,
    CommentUpdate,
    PostCreate,
    PostUpdate,
    ReportCreate,
)
from app.services import social_service

router = APIRouter(prefix="/api", tags=["Social"])


# ===================== FEED =====================


@router.get("/feed")
async def get_feed(
    cursor: str | None = Query(None, description="Cursor ISO datetime para paginación"),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Feed del usuario: posts de personas que sigue + propios."""
    cursor_dt = None
    if cursor:
        try:
            cursor_dt = datetime.fromisoformat(cursor)
        except ValueError:
            raise HTTPException(status_code=400, detail="Formato de cursor inválido")

    return await social_service.get_feed(db, current_user.id, cursor_dt, limit)


@router.get("/feed/explore")
async def get_explore(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Posts populares de las últimas 48 horas."""
    return await social_service.get_explore(db, current_user.id, page, limit)


@router.get("/feed/recent")
async def get_recent_feed(
    cursor: str | None = Query(None, description="Cursor ISO datetime para paginación"),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Feed cronológico global (todos los posts, sin filtro de seguidos)."""
    cursor_dt = None
    if cursor:
        try:
            cursor_dt = datetime.fromisoformat(cursor)
        except ValueError:
            raise HTTPException(status_code=400, detail="Formato de cursor inválido")

    return await social_service.get_recent_feed(db, current_user.id, cursor_dt, limit)


@router.get("/hashtags/{tag}/feed")
async def get_hashtag_feed(
    tag: str,
    cursor: str | None = Query(None, description="Cursor ISO datetime para paginación"),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Feed de posts que contienen un hashtag."""
    cursor_dt = None
    if cursor:
        try:
            cursor_dt = datetime.fromisoformat(cursor)
        except ValueError:
            raise HTTPException(status_code=400, detail="Formato de cursor inválido")

    return await social_service.get_hashtag_feed(db, tag, current_user.id, cursor_dt, limit)


@router.get("/posts/search")
async def search_posts(
    q: str = Query(..., min_length=1, max_length=100),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Buscar posts por contenido. Si `q` empieza con `#` busca el hashtag."""
    return await social_service.search_posts(db, current_user.id, q, page, limit)


# ===================== POSTS =====================


@router.post("/posts", status_code=status.HTTP_201_CREATED)
async def create_post(
    data: PostCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Crear una nueva publicación."""
    try:
        post = await social_service.create_post(
            db,
            user_id=current_user.id,
            content=data.content,
            post_type=data.post_type,
            media_url=data.media_url,
            practice_session_id=data.practice_session_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return social_service._build_post_response(post, False)


@router.get("/posts/{post_id}")
async def get_post_detail(
    post_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Detalle de un post con últimos 5 comentarios."""
    result = await social_service.get_post_detail(db, post_id, current_user.id)
    if not result:
        raise HTTPException(status_code=404, detail="Post no encontrado")
    return result


@router.put("/posts/{post_id}")
async def update_post(
    post_id: uuid.UUID,
    data: PostUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Editar contenido de un post (solo el autor)."""
    post = await social_service.get_post_by_id(db, post_id)
    if not post or not post.is_active:
        raise HTTPException(status_code=404, detail="Post no encontrado")
    if post.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Solo el autor puede editar")

    updated = await social_service.update_post(db, post, data.content)
    return social_service._build_post_response(updated, False)


@router.delete("/posts/{post_id}")
async def delete_post(
    post_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Eliminar post (solo el autor o admin)."""
    post = await social_service.get_post_by_id(db, post_id)
    if not post or not post.is_active:
        raise HTTPException(status_code=404, detail="Post no encontrado")
    if post.user_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=403, detail="No tienes permiso para eliminar este post")

    await social_service.soft_delete_post(db, post)
    return {"message": "Post eliminado correctamente"}


# ===================== LIKES =====================


@router.post("/posts/{post_id}/like")
async def toggle_like(
    post_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Toggle like en un post."""
    post = await social_service.get_post_by_id(db, post_id)
    if not post or not post.is_active:
        raise HTTPException(status_code=404, detail="Post no encontrado")

    return await social_service.toggle_like(db, post_id, current_user.id)


@router.get("/posts/{post_id}/likes")
async def get_post_likes(
    post_id: uuid.UUID,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lista de usuarios que dieron like a un post."""
    post = await social_service.get_post_by_id(db, post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post no encontrado")

    return await social_service.get_post_likes(db, post_id, page, limit)


# ===================== SAVED (BOOKMARK) =====================


@router.post("/posts/{post_id}/save")
async def toggle_save(
    post_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Guardar/quitar un post de los guardados del usuario."""
    post = await social_service.get_post_by_id(db, post_id)
    if not post or not post.is_active:
        raise HTTPException(status_code=404, detail="Post no encontrado")

    return await social_service.toggle_save(db, post_id, current_user.id)


@router.get("/me/saved")
async def get_saved_feed(
    cursor: str | None = Query(None, description="Cursor ISO datetime para paginación"),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Feed de los posts guardados por el usuario."""
    cursor_dt = None
    if cursor:
        try:
            cursor_dt = datetime.fromisoformat(cursor)
        except ValueError:
            raise HTTPException(status_code=400, detail="Formato de cursor inválido")

    return await social_service.get_saved_feed(db, current_user.id, cursor_dt, limit)


# ===================== COMMENTS =====================


@router.post("/posts/{post_id}/comments", status_code=status.HTTP_201_CREATED)
async def create_comment(
    post_id: uuid.UUID,
    data: CommentCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Crear comentario en un post."""
    post = await social_service.get_post_by_id(db, post_id)
    if not post or not post.is_active:
        raise HTTPException(status_code=404, detail="Post no encontrado")

    try:
        comment = await social_service.create_comment(
            db,
            post_id,
            current_user.id,
            data.content,
            parent_comment_id=data.parent_comment_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return social_service._serialize_comment(comment)


@router.get("/comments/{comment_id}/replies")
async def get_comment_replies(
    comment_id: uuid.UUID,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtener replies a un comentario."""
    return await social_service.get_replies(db, comment_id, page, limit, user_id=current_user.id)


@router.get("/posts/{post_id}/comments")
async def get_comments(
    post_id: uuid.UUID,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lista de comentarios de un post."""
    post = await social_service.get_post_by_id(db, post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post no encontrado")

    return await social_service.get_comments(db, post_id, page, limit, user_id=current_user.id)


@router.put("/comments/{comment_id}")
async def update_comment(
    comment_id: uuid.UUID,
    data: CommentUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Editar contenido de un comentario (solo el autor)."""
    comment = await social_service.get_comment_by_id(db, comment_id)
    if not comment or not comment.is_active:
        raise HTTPException(status_code=404, detail="Comentario no encontrado")
    if comment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Solo el autor puede editar")

    updated = await social_service.update_comment(db, comment, data.content)
    is_liked = comment_id in await social_service._liked_comment_ids(
        db, current_user.id, [updated.id]
    )
    return social_service._serialize_comment(updated, is_liked)


@router.post("/comments/{comment_id}/like")
async def toggle_comment_like(
    comment_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Toggle like en un comentario."""
    comment = await social_service.get_comment_by_id(db, comment_id)
    if not comment or not comment.is_active:
        raise HTTPException(status_code=404, detail="Comentario no encontrado")

    return await social_service.toggle_comment_like(db, comment, current_user.id)


@router.delete("/posts/{post_id}/comments/{comment_id}")
async def delete_comment(
    post_id: uuid.UUID,
    comment_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Eliminar comentario (solo el autor o admin)."""
    comment = await social_service.get_comment_by_id(db, comment_id)
    if not comment or not comment.is_active or comment.post_id != post_id:
        raise HTTPException(status_code=404, detail="Comentario no encontrado")
    if comment.user_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=403, detail="No tienes permiso")

    await social_service.soft_delete_comment(db, comment)
    return {"message": "Comentario eliminado correctamente"}


# ===================== REPORTS =====================


@router.post("/reports", status_code=status.HTTP_201_CREATED)
async def create_report(
    data: ReportCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Reportar contenido (post, comentario o usuario)."""
    if not data.post_id and not data.comment_id and not data.reported_user_id:
        raise HTTPException(
            status_code=422,
            detail="Debes indicar al menos un post_id, comment_id o reported_user_id",
        )

    await social_service.create_report(
        db,
        reporter_id=current_user.id,
        reason=data.reason,
        description=data.description,
        post_id=data.post_id,
        comment_id=data.comment_id,
        reported_user_id=data.reported_user_id,
    )
    return {"message": "Reporte enviado correctamente"}
