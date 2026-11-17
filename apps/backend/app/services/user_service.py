"""Servicio de perfiles de usuario, follows y búsqueda."""

import uuid
from datetime import datetime

from sqlalchemy import and_, exists, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social import Follow, Like, Post
from app.models.user import User
from app.schemas.user import UserUpdate
from app.services.social_service import _build_post_response, _saved_post_ids
from app.utils.sql import greatest


async def get_user_profile(
    db: AsyncSession,
    user_id: uuid.UUID,
    current_user_id: uuid.UUID,
) -> dict | None:
    """Obtener perfil público de un usuario."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        return None

    # Verificar si el usuario actual sigue a este usuario
    is_followed = False
    if current_user_id != user_id:
        follow_result = await db.execute(
            select(
                exists().where(
                    and_(
                        Follow.follower_id == current_user_id,
                        Follow.following_id == user_id,
                    )
                )
            )
        )
        is_followed = follow_result.scalar()

    return {
        "id": str(user.id),
        "username": user.username,
        "full_name": user.full_name,
        "avatar_url": user.avatar_url,
        "bio": user.bio,
        "followers_count": user.followers_count,
        "following_count": user.following_count,
        "posts_count": user.posts_count,
        "is_followed_by_me": is_followed,
        "created_at": user.created_at.isoformat(),
    }


async def get_user_by_username(db: AsyncSession, username: str) -> User | None:
    """Resolver un username a su User (case-insensitive), para abrir el perfil
    desde una @mención clickeable."""
    result = await db.execute(
        select(User).where(
            func.lower(User.username) == username.lower(),
            User.is_active.is_(True),
        )
    )
    return result.scalar_one_or_none()


async def get_user_posts(
    db: AsyncSession,
    user_id: uuid.UUID,
    current_user_id: uuid.UUID,
    cursor: datetime | None = None,
    limit: int = 20,
) -> dict:
    """Obtener posts de un usuario con cursor pagination."""
    query = (
        select(Post)
        .where(Post.user_id == user_id, Post.is_active == True)
        .order_by(Post.created_at.desc())
        .limit(limit + 1)
    )
    if cursor:
        query = query.where(Post.created_at < cursor)

    result = await db.execute(query)
    posts = list(result.scalars().all())

    has_more = len(posts) > limit
    if has_more:
        posts = posts[:limit]

    # is_liked_by_me
    post_ids = [p.id for p in posts]
    liked_post_ids = set()
    if post_ids:
        liked_result = await db.execute(
            select(Like.post_id).where(
                Like.user_id == current_user_id,
                Like.post_id.in_(post_ids),
            )
        )
        liked_post_ids = set(liked_result.scalars().all())

    saved_post_ids = await _saved_post_ids(db, current_user_id, post_ids)
    items = [_build_post_response(p, p.id in liked_post_ids, p.id in saved_post_ids) for p in posts]
    next_cursor = posts[-1].created_at.isoformat() if posts and has_more else None

    return {"items": items, "next_cursor": next_cursor, "has_more": has_more}


async def toggle_follow(
    db: AsyncSession,
    follower_id: uuid.UUID,
    following_id: uuid.UUID,
) -> dict:
    """Toggle follow/unfollow de un usuario."""
    if follower_id == following_id:
        raise ValueError("No puedes seguirte a ti mismo")

    # Verificar que el usuario a seguir existe
    target_result = await db.execute(select(User).where(User.id == following_id))
    target_user = target_result.scalar_one_or_none()
    if not target_user:
        raise ValueError("Usuario no encontrado")

    # Verificar si ya sigue
    result = await db.execute(
        select(Follow).where(
            Follow.follower_id == follower_id,
            Follow.following_id == following_id,
        )
    )
    existing = result.scalar_one_or_none()

    if existing:
        # Unfollow
        await db.delete(existing)
        await db.execute(
            update(User)
            .where(User.id == following_id)
            .values(followers_count=greatest(User.followers_count - 1, 0))
        )
        await db.execute(
            update(User)
            .where(User.id == follower_id)
            .values(following_count=greatest(User.following_count - 1, 0))
        )
        await db.commit()
        await db.refresh(target_user)
        return {"following": False, "followers_count": target_user.followers_count}
    else:
        # Follow
        follow = Follow(follower_id=follower_id, following_id=following_id)
        db.add(follow)
        await db.execute(
            update(User)
            .where(User.id == following_id)
            .values(followers_count=User.followers_count + 1)
        )
        await db.execute(
            update(User)
            .where(User.id == follower_id)
            .values(following_count=User.following_count + 1)
        )
        await db.commit()
        await db.refresh(target_user)

        # Notificar al usuario seguido
        from app.services import notification_dispatcher

        follower_result = await db.execute(select(User.username).where(User.id == follower_id))
        follower_username = follower_result.scalar() or "Alguien"
        await notification_dispatcher.notify_user(
            db,
            user_id=following_id,
            title="Nuevo seguidor 🎹",
            body=f"@{follower_username} empezó a seguirte",
            data={"type": "follow", "user_id": str(follower_id)},
        )

        return {"following": True, "followers_count": target_user.followers_count}


async def _followed_set(
    db: AsyncSession, current_user_id: uuid.UUID, ids: list[uuid.UUID]
) -> set[uuid.UUID]:
    """Subconjunto de `ids` que el current_user ya sigue (para marcar el botón)."""
    if not ids:
        return set()
    result = await db.execute(
        select(Follow.following_id).where(
            Follow.follower_id == current_user_id,
            Follow.following_id.in_(ids),
        )
    )
    return set(result.scalars().all())


async def get_followers(
    db: AsyncSession,
    user_id: uuid.UUID,
    current_user_id: uuid.UUID,
    page: int = 1,
    limit: int = 20,
) -> dict:
    """Obtener lista de seguidores de un usuario."""
    count_query = select(func.count()).select_from(Follow).where(Follow.following_id == user_id)
    total = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * limit
    result = await db.execute(
        select(Follow)
        .where(Follow.following_id == user_id)
        .order_by(Follow.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    follows = list(result.scalars().all())

    followed = await _followed_set(db, current_user_id, [f.follower.id for f in follows])
    items = [
        {
            "id": str(f.follower.id),
            "username": f.follower.username,
            "full_name": f.follower.full_name,
            "avatar_url": f.follower.avatar_url,
            "is_followed_by_me": f.follower.id in followed,
        }
        for f in follows
    ]
    pages = (total + limit - 1) // limit if limit > 0 else 1

    return {"items": items, "total": total, "page": page, "pages": pages}


async def get_following(
    db: AsyncSession,
    user_id: uuid.UUID,
    current_user_id: uuid.UUID,
    page: int = 1,
    limit: int = 20,
) -> dict:
    """Obtener lista de usuarios que sigue."""
    count_query = select(func.count()).select_from(Follow).where(Follow.follower_id == user_id)
    total = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * limit
    result = await db.execute(
        select(Follow)
        .where(Follow.follower_id == user_id)
        .order_by(Follow.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    follows = list(result.scalars().all())

    followed = await _followed_set(db, current_user_id, [f.following.id for f in follows])
    items = [
        {
            "id": str(f.following.id),
            "username": f.following.username,
            "full_name": f.following.full_name,
            "avatar_url": f.following.avatar_url,
            "is_followed_by_me": f.following.id in followed,
        }
        for f in follows
    ]
    pages = (total + limit - 1) // limit if limit > 0 else 1

    return {"items": items, "total": total, "page": page, "pages": pages}


async def get_user_media(
    db: AsyncSession,
    user_id: uuid.UUID,
    current_user_id: uuid.UUID,
    cursor: datetime | None = None,
    limit: int = 20,
) -> dict:
    """Posts de un usuario que tienen media (para la pestaña 'Media' del perfil)."""
    query = (
        select(Post)
        .where(
            Post.user_id == user_id,
            Post.is_active == True,
            Post.media_url.isnot(None),
        )
        .order_by(Post.created_at.desc())
        .limit(limit + 1)
    )
    if cursor:
        query = query.where(Post.created_at < cursor)

    result = await db.execute(query)
    posts = list(result.scalars().all())

    has_more = len(posts) > limit
    if has_more:
        posts = posts[:limit]

    post_ids = [p.id for p in posts]
    liked_post_ids = set()
    if post_ids:
        liked_result = await db.execute(
            select(Like.post_id).where(
                Like.user_id == current_user_id,
                Like.post_id.in_(post_ids),
            )
        )
        liked_post_ids = set(liked_result.scalars().all())

    saved_post_ids = await _saved_post_ids(db, current_user_id, post_ids)
    items = [_build_post_response(p, p.id in liked_post_ids, p.id in saved_post_ids) for p in posts]
    next_cursor = posts[-1].created_at.isoformat() if posts and has_more else None

    return {"items": items, "next_cursor": next_cursor, "has_more": has_more}


async def get_follow_suggestions(
    db: AsyncSession, current_user_id: uuid.UUID, limit: int = 10
) -> list[dict]:
    """Usuarios sugeridos para seguir (no seguidos, ordenados por popularidad)."""
    following_subq = select(Follow.following_id).where(Follow.follower_id == current_user_id)
    result = await db.execute(
        select(User)
        .where(
            User.id != current_user_id,
            User.is_active == True,
            User.is_banned == False,
            User.id.notin_(following_subq),
        )
        .order_by(User.followers_count.desc(), User.created_at.desc())
        .limit(limit)
    )
    return [
        {
            "id": str(u.id),
            "username": u.username,
            "full_name": u.full_name,
            "avatar_url": u.avatar_url,
            "followers_count": u.followers_count,
        }
        for u in result.scalars().all()
    ]


async def search_users(
    db: AsyncSession,
    query: str,
    page: int = 1,
    limit: int = 20,
) -> dict:
    """Buscar usuarios por username o full_name."""
    search_term = f"%{query}%"
    where_clause = and_(
        User.is_active == True,
        User.is_banned == False,
        or_(
            User.username.ilike(search_term),
            User.full_name.ilike(search_term),
        ),
    )

    count_query = select(func.count()).select_from(User).where(where_clause)
    total = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * limit
    result = await db.execute(
        select(User).where(where_clause).order_by(User.username).offset(offset).limit(limit)
    )
    users = list(result.scalars().all())

    items = [
        {
            "id": str(u.id),
            "username": u.username,
            "full_name": u.full_name,
            "avatar_url": u.avatar_url,
        }
        for u in users
    ]
    pages = (total + limit - 1) // limit if limit > 0 else 1

    return {"items": items, "total": total, "page": page, "pages": pages}


async def ban_user(
    db: AsyncSession,
    user_id: uuid.UUID,
    reason: str,
) -> bool:
    """Banear un usuario."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        return False

    user.is_banned = True
    user.ban_reason = reason
    await db.commit()
    return True


async def unban_user(
    db: AsyncSession,
    user_id: uuid.UUID,
) -> bool:
    """Desbanear un usuario."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        return False

    user.is_banned = False
    user.ban_reason = None
    await db.commit()
    return True


async def admin_set_admin(db: AsyncSession, user_id: uuid.UUID, is_admin: bool) -> dict | None:
    """Da o quita el rol de admin a un usuario."""
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        return None
    user.is_admin = is_admin
    await db.commit()
    return {"id": str(user.id), "is_admin": user.is_admin}


async def admin_get_user_detail(db: AsyncSession, user_id: uuid.UUID) -> dict | None:
    """Detalle de un usuario para el admin: datos + actividad + suscripción."""
    from app.models.lesson import PracticeSession

    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        return None

    where = PracticeSession.user_id == user_id
    sessions = (
        await db.execute(select(func.count()).select_from(PracticeSession).where(where))
    ).scalar() or 0
    avg_score = (await db.execute(select(func.avg(PracticeSession.score)).where(where))).scalar()
    distinct_lessons = (
        await db.execute(select(func.count(func.distinct(PracticeSession.lesson_id))).where(where))
    ).scalar() or 0
    last_active = (
        await db.execute(select(func.max(PracticeSession.created_at)).where(where))
    ).scalar()

    return {
        "id": str(user.id),
        "email": user.email,
        "username": user.username,
        "full_name": user.full_name,
        "avatar_url": user.avatar_url,
        "is_admin": user.is_admin,
        "is_banned": user.is_banned,
        "ban_reason": user.ban_reason,
        "auth_provider": user.auth_provider,
        "xp_level": user.xp_level,
        "followers_count": user.followers_count,
        "following_count": user.following_count,
        "posts_count": user.posts_count,
        "created_at": user.created_at,
        "subscription_status": user.subscription_status,
        "subscription_plan": user.subscription_plan,
        "subscription_expires_at": user.subscription_expires_at,
        "is_premium": user.is_premium,
        "practice": {
            "sessions": sessions,
            "avg_score": round(float(avg_score), 1) if avg_score is not None else None,
            "distinct_lessons": distinct_lessons,
            "last_active": last_active,
        },
    }


async def admin_list_users(
    db: AsyncSession,
    page: int = 1,
    limit: int = 20,
    search: str | None = None,
    is_banned: bool | None = None,
    is_admin: bool | None = None,
) -> dict:
    """Lista paginada de usuarios para panel de admin."""
    conditions = []

    if search:
        term = f"%{search}%"
        conditions.append(
            or_(
                User.email.ilike(term),
                User.username.ilike(term),
                User.full_name.ilike(term),
            )
        )
    if is_banned is not None:
        conditions.append(User.is_banned == is_banned)
    if is_admin is not None:
        conditions.append(User.is_admin == is_admin)

    where = and_(*conditions) if conditions else True

    total = (await db.execute(select(func.count()).select_from(User).where(where))).scalar() or 0

    offset = (page - 1) * limit
    result = await db.execute(
        select(User).where(where).order_by(User.created_at.desc()).offset(offset).limit(limit)
    )
    users = list(result.scalars().all())

    items = [
        {
            "id": str(u.id),
            "email": u.email,
            "username": u.username,
            "full_name": u.full_name,
            "avatar_url": u.avatar_url,
            "is_active": u.is_active,
            "is_admin": u.is_admin,
            "is_banned": u.is_banned,
            "ban_reason": u.ban_reason,
            "xp_level": u.xp_level,
            "followers_count": u.followers_count,
            "posts_count": u.posts_count,
            "created_at": u.created_at.isoformat(),
        }
        for u in users
    ]
    pages = (total + limit - 1) // limit if limit > 0 else 1

    return {"items": items, "total": total, "page": page, "pages": pages}


async def update_user(db: AsyncSession, user: User, update_data: UserUpdate) -> User:
    """Actualiza datos de perfil, preferencias de instrumento y calibración respiratoria."""
    payload = update_data.model_dump(exclude_unset=True)
    for field, value in payload.items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return user
