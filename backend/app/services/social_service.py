"""Servicio de red social: posts, likes, comentarios y reportes."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import and_, delete, exists, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social import (
    Comment, CommentLike, Like, Post, Report, SavedPost,
)
from app.models.hashtag import Hashtag, PostHashtag
from app.models.lesson import PracticeSession, Lesson
from app.models.user import User
from app.services.text_parsing import extract_hashtags, extract_mentions
from app.utils.sql import greatest


# ===================== POSTS =====================

async def create_post(
    db: AsyncSession,
    user_id: uuid.UUID,
    content: str,
    post_type: str = "text",
    media_url: str | None = None,
    practice_session_id: uuid.UUID | None = None,
) -> Post:
    """Crear una nueva publicación."""
    # Validar practice_session si se proporciona
    if practice_session_id:
        result = await db.execute(
            select(PracticeSession).where(
                PracticeSession.id == practice_session_id,
                PracticeSession.user_id == user_id,
            )
        )
        session = result.scalar_one_or_none()
        if not session:
            raise ValueError("Sesión de práctica no encontrada o no pertenece al usuario")

    post = Post(
        user_id=user_id,
        content=content,
        post_type=post_type,
        media_url=media_url,
        practice_session_id=practice_session_id,
    )
    db.add(post)

    # Incrementar counter cache
    await db.execute(
        update(User).where(User.id == user_id).values(posts_count=User.posts_count + 1)
    )

    await db.flush()  # asegura post.id para los hashtags
    await _sync_hashtags(db, post)

    await db.commit()
    await db.refresh(post)

    # Notificar a usuarios mencionados (best-effort, post-commit)
    await _notify_mentions(db, user_id, content, str(post.id))
    return post


async def get_post_by_id(db: AsyncSession, post_id: uuid.UUID) -> Post | None:
    """Obtener post por ID."""
    result = await db.execute(select(Post).where(Post.id == post_id))
    return result.scalar_one_or_none()


async def update_post(db: AsyncSession, post: Post, content: str) -> Post:
    """Editar contenido de un post (re-sincroniza hashtags)."""
    post.content = content
    await db.flush()
    await _resync_hashtags(db, post)
    await db.commit()
    await db.refresh(post)
    return post


async def _sync_hashtags(db: AsyncSession, post: Post) -> None:
    """Extrae los hashtags del contenido y los enlaza al post (incrementa counters)."""
    tags = extract_hashtags(post.content)
    if not tags:
        return
    existing = await db.execute(select(Hashtag).where(Hashtag.tag.in_(tags)))
    by_tag = {h.tag: h for h in existing.scalars().all()}
    for tag in tags:
        hashtag = by_tag.get(tag)
        if hashtag is None:
            hashtag = Hashtag(tag=tag, posts_count=0)
            db.add(hashtag)
            await db.flush()
            by_tag[tag] = hashtag
        db.add(PostHashtag(post_id=post.id, hashtag_id=hashtag.id))
        await db.execute(
            update(Hashtag)
            .where(Hashtag.id == hashtag.id)
            .values(posts_count=Hashtag.posts_count + 1)
        )


async def _resync_hashtags(db: AsyncSession, post: Post) -> None:
    """Borra los hashtags actuales del post (decrementa counters) y re-sincroniza."""
    rows = await db.execute(
        select(PostHashtag.hashtag_id).where(PostHashtag.post_id == post.id)
    )
    hashtag_ids = list(rows.scalars().all())
    if hashtag_ids:
        await db.execute(
            update(Hashtag)
            .where(Hashtag.id.in_(hashtag_ids))
            .values(posts_count=greatest(Hashtag.posts_count - 1, 0))
        )
        await db.execute(delete(PostHashtag).where(PostHashtag.post_id == post.id))
    await _sync_hashtags(db, post)


async def _notify_mentions(
    db: AsyncSession,
    author_id: uuid.UUID,
    text: str,
    post_id: str,
    comment_id: str | None = None,
) -> None:
    """Notifica a los usuarios mencionados con @username en el texto."""
    usernames = extract_mentions(text)
    if not usernames:
        return
    from app.services import notification_dispatcher

    result = await db.execute(
        select(User.id, User.username).where(
            func.lower(User.username).in_(usernames),
            User.is_active.is_(True),
            User.is_banned.is_(False),
        )
    )
    rows = result.all()
    if not rows:
        return

    actor_result = await db.execute(select(User.username).where(User.id == author_id))
    actor = actor_result.scalar() or "Alguien"

    data = {"type": "mention", "post_id": post_id}
    if comment_id:
        data["comment_id"] = comment_id

    for uid, _uname in rows:
        if uid == author_id:
            continue
        await notification_dispatcher.notify_user(
            db,
            user_id=uid,
            title="Te mencionaron 💬",
            body=f"@{actor} te mencionó en una publicación",
            data=dict(data),
        )


async def soft_delete_post(db: AsyncSession, post: Post) -> None:
    """Soft delete de un post."""
    post.is_active = False
    # Decrementar counter cache
    await db.execute(
        update(User).where(User.id == post.user_id).values(
            posts_count=greatest(User.posts_count - 1, 0)
        )
    )
    await db.commit()


async def get_feed(
    db: AsyncSession,
    user_id: uuid.UUID,
    cursor: datetime | None = None,
    limit: int = 20,
) -> dict:
    """Obtener feed del usuario (posts de seguidos + propios)."""
    from app.models.social import Follow

    # Subquery de IDs que sigue el usuario
    following_ids = select(Follow.following_id).where(Follow.follower_id == user_id)

    # Posts de seguidos + propios, activos, de usuarios no baneados
    query = (
        select(Post)
        .join(User, Post.user_id == User.id)
        .where(
            Post.is_active == True,
            User.is_banned == False,
            (Post.user_id == user_id) | (Post.user_id.in_(following_ids)),
        )
        .order_by(Post.created_at.desc())
        .limit(limit + 1)  # +1 para saber si hay más
    )

    if cursor:
        query = query.where(Post.created_at < cursor)

    result = await db.execute(query)
    posts = list(result.scalars().all())

    has_more = len(posts) > limit
    if has_more:
        posts = posts[:limit]

    # Obtener is_liked_by_me para cada post
    post_ids = [p.id for p in posts]
    liked_post_ids = set()
    if post_ids:
        liked_result = await db.execute(
            select(Like.post_id).where(
                Like.user_id == user_id,
                Like.post_id.in_(post_ids),
            )
        )
        liked_post_ids = set(liked_result.scalars().all())

    saved_post_ids = await _saved_post_ids(db, user_id, post_ids)

    # Construir respuesta con datos de practice session
    items = []
    for post in posts:
        post_dict = _build_post_response(
            post, post.id in liked_post_ids, post.id in saved_post_ids
        )
        items.append(post_dict)

    next_cursor = posts[-1].created_at.isoformat() if posts and has_more else None

    return {
        "items": items,
        "next_cursor": next_cursor,
        "has_more": has_more,
    }


async def get_recent_feed(
    db: AsyncSession,
    user_id: uuid.UUID,
    cursor: datetime | None = None,
    limit: int = 20,
) -> dict:
    """Feed cronológico global: todos los posts activos (sin filtro de seguidos)."""
    query = (
        select(Post)
        .join(User, Post.user_id == User.id)
        .where(
            Post.is_active == True,  # noqa: E712
            User.is_banned == False,  # noqa: E712
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
                Like.user_id == user_id,
                Like.post_id.in_(post_ids),
            )
        )
        liked_post_ids = set(liked_result.scalars().all())

    saved_post_ids = await _saved_post_ids(db, user_id, post_ids)
    items = [
        _build_post_response(p, p.id in liked_post_ids, p.id in saved_post_ids)
        for p in posts
    ]
    next_cursor = posts[-1].created_at.isoformat() if posts and has_more else None

    return {"items": items, "next_cursor": next_cursor, "has_more": has_more}


async def get_hashtag_feed(
    db: AsyncSession,
    tag: str,
    user_id: uuid.UUID,
    cursor: datetime | None = None,
    limit: int = 20,
) -> dict:
    """Feed de posts que contienen un hashtag (cronológico descendente)."""
    norm = tag.lstrip("#").lower()

    query = (
        select(Post)
        .join(PostHashtag, PostHashtag.post_id == Post.id)
        .join(Hashtag, Hashtag.id == PostHashtag.hashtag_id)
        .join(User, Post.user_id == User.id)
        .where(
            Hashtag.tag == norm,
            Post.is_active == True,  # noqa: E712
            User.is_banned == False,  # noqa: E712
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
                Like.user_id == user_id,
                Like.post_id.in_(post_ids),
            )
        )
        liked_post_ids = set(liked_result.scalars().all())

    saved_post_ids = await _saved_post_ids(db, user_id, post_ids)
    items = [
        _build_post_response(p, p.id in liked_post_ids, p.id in saved_post_ids)
        for p in posts
    ]
    next_cursor = posts[-1].created_at.isoformat() if posts and has_more else None

    return {"items": items, "next_cursor": next_cursor, "has_more": has_more}


async def get_explore(
    db: AsyncSession,
    user_id: uuid.UUID,
    page: int = 1,
    limit: int = 20,
) -> dict:
    """Obtener posts populares de las últimas 48 horas."""
    from datetime import timedelta

    cutoff = datetime.now(timezone.utc) - timedelta(hours=48)

    # Total
    count_query = (
        select(func.count())
        .select_from(Post)
        .join(User, Post.user_id == User.id)
        .where(
            Post.is_active == True,
            User.is_banned == False,
            Post.created_at >= cutoff,
        )
    )
    total = (await db.execute(count_query)).scalar() or 0

    # Posts ordenados por likes
    offset = (page - 1) * limit
    query = (
        select(Post)
        .join(User, Post.user_id == User.id)
        .where(
            Post.is_active == True,
            User.is_banned == False,
            Post.created_at >= cutoff,
        )
        .order_by(Post.likes_count.desc(), Post.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(query)
    posts = list(result.scalars().all())

    # is_liked_by_me
    post_ids = [p.id for p in posts]
    liked_post_ids = set()
    if post_ids:
        liked_result = await db.execute(
            select(Like.post_id).where(
                Like.user_id == user_id,
                Like.post_id.in_(post_ids),
            )
        )
        liked_post_ids = set(liked_result.scalars().all())

    saved_post_ids = await _saved_post_ids(db, user_id, post_ids)
    items = [
        _build_post_response(p, p.id in liked_post_ids, p.id in saved_post_ids)
        for p in posts
    ]
    pages = (total + limit - 1) // limit if limit > 0 else 1

    return {"items": items, "total": total, "page": page, "pages": pages}


async def search_posts(
    db: AsyncSession,
    user_id: uuid.UUID,
    query_str: str,
    page: int = 1,
    limit: int = 20,
) -> dict:
    """Buscar posts por contenido (ILIKE). Si empieza con # busca el hashtag completo."""
    q = query_str.strip()
    if q.startswith("#"):
        # Hashtag: matchear con espacios/inicio/final
        hashtag = q.lower()
        like_pattern = f"%{hashtag}%"
    else:
        like_pattern = f"%{q}%"

    count_query = (
        select(func.count())
        .select_from(Post)
        .join(User, Post.user_id == User.id)
        .where(
            Post.is_active == True,
            User.is_banned == False,
            Post.content.ilike(like_pattern),
        )
    )
    total = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * limit
    query = (
        select(Post)
        .join(User, Post.user_id == User.id)
        .where(
            Post.is_active == True,
            User.is_banned == False,
            Post.content.ilike(like_pattern),
        )
        .order_by(Post.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(query)
    posts = list(result.scalars().all())

    post_ids = [p.id for p in posts]
    liked_post_ids = set()
    if post_ids:
        liked_result = await db.execute(
            select(Like.post_id).where(
                Like.user_id == user_id,
                Like.post_id.in_(post_ids),
            )
        )
        liked_post_ids = set(liked_result.scalars().all())

    saved_post_ids = await _saved_post_ids(db, user_id, post_ids)
    items = [
        _build_post_response(p, p.id in liked_post_ids, p.id in saved_post_ids)
        for p in posts
    ]
    pages = (total + limit - 1) // limit if limit > 0 else 1

    return {"items": items, "total": total, "page": page, "pages": pages}


async def get_post_detail(
    db: AsyncSession,
    post_id: uuid.UUID,
    user_id: uuid.UUID,
) -> dict | None:
    """Obtener detalle de un post con últimos 5 comentarios."""
    post = await get_post_by_id(db, post_id)
    if not post or not post.is_active:
        return None

    # Check like
    liked_result = await db.execute(
        select(exists().where(and_(Like.post_id == post_id, Like.user_id == user_id)))
    )
    is_liked = liked_result.scalar()

    # Check saved
    saved_result = await db.execute(
        select(
            exists().where(
                and_(SavedPost.post_id == post_id, SavedPost.user_id == user_id)
            )
        )
    )
    is_saved = saved_result.scalar()

    # Últimos 5 comentarios
    comments_result = await db.execute(
        select(Comment)
        .where(Comment.post_id == post_id, Comment.is_active == True)
        .order_by(Comment.created_at.asc())
        .limit(5)
    )
    comments = list(comments_result.scalars().all())

    liked_comments = await _liked_comment_ids(db, user_id, [c.id for c in comments])

    post_dict = _build_post_response(post, is_liked, is_saved)
    post_dict["recent_comments"] = [
        _serialize_comment(c, c.id in liked_comments) for c in comments
    ]

    return post_dict


# ===================== LIKES =====================

async def toggle_like(
    db: AsyncSession,
    post_id: uuid.UUID,
    user_id: uuid.UUID,
) -> dict:
    """Toggle like en un post. Retorna estado y nuevo count."""
    # Verificar si ya existe el like
    result = await db.execute(
        select(Like).where(Like.post_id == post_id, Like.user_id == user_id)
    )
    existing_like = result.scalar_one_or_none()

    if existing_like:
        # Quitar like
        await db.delete(existing_like)
        await db.execute(
            update(Post).where(Post.id == post_id).values(
                likes_count=greatest(Post.likes_count - 1, 0)
            )
        )
        await db.commit()
        # Obtener count actualizado
        post = await get_post_by_id(db, post_id)
        return {"liked": False, "likes_count": post.likes_count}
    else:
        # Dar like
        like = Like(post_id=post_id, user_id=user_id)
        db.add(like)
        await db.execute(
            update(Post).where(Post.id == post_id).values(
                likes_count=Post.likes_count + 1
            )
        )
        await db.commit()
        post = await get_post_by_id(db, post_id)

        # Notificar al autor del post (si no es uno mismo)
        if post.user_id != user_id:
            from app.models.user import User
            from app.services import notification_dispatcher
            actor_result = await db.execute(
                select(User.username).where(User.id == user_id)
            )
            actor_username = actor_result.scalar() or "Alguien"
            await notification_dispatcher.notify_user(
                db,
                user_id=post.user_id,
                title="Nuevo me gusta ❤️",
                body=f"A @{actor_username} le gustó tu publicación",
                data={"type": "like", "post_id": str(post_id)},
            )

        return {"liked": True, "likes_count": post.likes_count}


async def get_post_likes(
    db: AsyncSession,
    post_id: uuid.UUID,
    page: int = 1,
    limit: int = 20,
) -> dict:
    """Obtener lista de usuarios que dieron like a un post."""
    count_query = select(func.count()).select_from(Like).where(Like.post_id == post_id)
    total = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * limit
    result = await db.execute(
        select(Like)
        .where(Like.post_id == post_id)
        .order_by(Like.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    likes = list(result.scalars().all())

    items = [
        {
            "id": str(like.user.id),
            "username": like.user.username,
            "full_name": like.user.full_name,
            "avatar_url": like.user.avatar_url,
        }
        for like in likes
    ]
    pages = (total + limit - 1) // limit if limit > 0 else 1

    return {"items": items, "total": total, "page": page, "pages": pages}


# ===================== SAVED (BOOKMARK) =====================

async def toggle_save(
    db: AsyncSession,
    post_id: uuid.UUID,
    user_id: uuid.UUID,
) -> dict:
    """Toggle guardar/bookmark de un post. Sin notificación (acción privada)."""
    result = await db.execute(
        select(SavedPost).where(
            SavedPost.post_id == post_id,
            SavedPost.user_id == user_id,
        )
    )
    existing = result.scalar_one_or_none()

    if existing:
        await db.delete(existing)
        await db.commit()
        return {"saved": False}

    db.add(SavedPost(post_id=post_id, user_id=user_id))
    await db.commit()
    return {"saved": True}


async def get_saved_feed(
    db: AsyncSession,
    user_id: uuid.UUID,
    cursor: datetime | None = None,
    limit: int = 20,
) -> dict:
    """Feed de los posts guardados por el usuario (orden = fecha de guardado desc)."""
    query = (
        select(Post, SavedPost.created_at.label("saved_at"))
        .join(SavedPost, SavedPost.post_id == Post.id)
        .join(User, Post.user_id == User.id)
        .where(
            SavedPost.user_id == user_id,
            Post.is_active == True,  # noqa: E712
            User.is_banned == False,  # noqa: E712
        )
        .order_by(SavedPost.created_at.desc())
        .limit(limit + 1)
    )
    if cursor:
        query = query.where(SavedPost.created_at < cursor)

    result = await db.execute(query)
    rows = result.all()

    has_more = len(rows) > limit
    if has_more:
        rows = rows[:limit]

    posts = [row[0] for row in rows]
    post_ids = [p.id for p in posts]
    liked_post_ids = set()
    if post_ids:
        liked_result = await db.execute(
            select(Like.post_id).where(
                Like.user_id == user_id,
                Like.post_id.in_(post_ids),
            )
        )
        liked_post_ids = set(liked_result.scalars().all())

    # Todos están guardados por definición
    items = [
        _build_post_response(p, p.id in liked_post_ids, True) for p in posts
    ]
    next_cursor = rows[-1][1].isoformat() if rows and has_more else None

    return {"items": items, "next_cursor": next_cursor, "has_more": has_more}


# ===================== COMMENTS =====================

async def create_comment(
    db: AsyncSession,
    post_id: uuid.UUID,
    user_id: uuid.UUID,
    content: str,
    parent_comment_id: uuid.UUID | None = None,
) -> Comment:
    """Crear comentario en un post (o reply a otro comment si parent_comment_id)."""
    # Validar que el parent comment existe y es del mismo post
    parent_user_id: uuid.UUID | None = None
    if parent_comment_id is not None:
        parent_result = await db.execute(
            select(Comment).where(
                Comment.id == parent_comment_id,
                Comment.post_id == post_id,
                Comment.is_active.is_(True),
            )
        )
        parent = parent_result.scalar_one_or_none()
        if not parent:
            raise ValueError("Comentario padre no encontrado")
        parent_user_id = parent.user_id

    comment = Comment(
        post_id=post_id,
        user_id=user_id,
        content=content,
        parent_comment_id=parent_comment_id,
    )
    db.add(comment)

    # Incrementar counter cache del post
    await db.execute(
        update(Post).where(Post.id == post_id).values(
            comments_count=Post.comments_count + 1
        )
    )

    # Incrementar replies_count del parent si aplica
    if parent_comment_id is not None:
        await db.execute(
            update(Comment).where(Comment.id == parent_comment_id).values(
                replies_count=Comment.replies_count + 1
            )
        )

    await db.commit()
    await db.refresh(comment)

    # Notificar a usuarios mencionados en el comentario
    await _notify_mentions(
        db, user_id, content, str(post_id), comment_id=str(comment.id)
    )

    # Notificar
    post = await get_post_by_id(db, post_id)
    # Si es un reply, notif va al autor del parent comment (no al autor del post)
    if parent_user_id is not None and parent_user_id != user_id:
        from app.models.user import User
        from app.services import notification_dispatcher
        actor_result = await db.execute(
            select(User.username).where(User.id == user_id)
        )
        actor_username = actor_result.scalar() or "Alguien"
        preview = content[:60] + ("…" if len(content) > 60 else "")
        await notification_dispatcher.notify_user(
            db,
            user_id=parent_user_id,
            title="Te respondieron 💬",
            body=f"@{actor_username}: {preview}",
            data={
                "type": "comment_reply",
                "post_id": str(post_id),
                "comment_id": str(comment.id),
            },
        )
        return comment

    # Comentario raíz → notif al autor del post
    if post and post.user_id != user_id:
        from app.models.user import User
        from app.services import notification_dispatcher
        actor_result = await db.execute(
            select(User.username).where(User.id == user_id)
        )
        actor_username = actor_result.scalar() or "Alguien"
        preview = content[:60] + ("…" if len(content) > 60 else "")
        await notification_dispatcher.notify_user(
            db,
            user_id=post.user_id,
            title="Nuevo comentario 💬",
            body=f"@{actor_username}: {preview}",
            data={"type": "comment", "post_id": str(post_id)},
        )

    return comment


def _serialize_comment(c: Comment, is_liked_by_me: bool = False) -> dict:
    return {
        "id": str(c.id),
        "post_id": str(c.post_id),
        "parent_comment_id": str(c.parent_comment_id) if c.parent_comment_id else None,
        "replies_count": c.replies_count,
        "likes_count": c.likes_count,
        "is_liked_by_me": is_liked_by_me,
        "user": {
            "id": str(c.user.id),
            "username": c.user.username,
            "full_name": c.user.full_name,
            "avatar_url": c.user.avatar_url,
        },
        "content": c.content,
        "created_at": c.created_at.isoformat(),
    }


async def _liked_comment_ids(
    db: AsyncSession,
    user_id: uuid.UUID | None,
    comment_ids: list[uuid.UUID],
) -> set[uuid.UUID]:
    """Set de comment_ids que el usuario actual marcó con like."""
    if not user_id or not comment_ids:
        return set()
    result = await db.execute(
        select(CommentLike.comment_id).where(
            CommentLike.user_id == user_id,
            CommentLike.comment_id.in_(comment_ids),
        )
    )
    return set(result.scalars().all())


async def _saved_post_ids(
    db: AsyncSession,
    user_id: uuid.UUID | None,
    post_ids: list[uuid.UUID],
) -> set[uuid.UUID]:
    """Set de post_ids que el usuario actual guardó (bookmark)."""
    if not user_id or not post_ids:
        return set()
    result = await db.execute(
        select(SavedPost.post_id).where(
            SavedPost.user_id == user_id,
            SavedPost.post_id.in_(post_ids),
        )
    )
    return set(result.scalars().all())


async def get_comments(
    db: AsyncSession,
    post_id: uuid.UUID,
    page: int = 1,
    limit: int = 20,
    user_id: uuid.UUID | None = None,
) -> dict:
    """Obtener comentarios raíz (sin parent) de un post paginados.
    Los replies se obtienen aparte via get_replies(comment_id).
    """
    count_query = (
        select(func.count())
        .select_from(Comment)
        .where(
            Comment.post_id == post_id,
            Comment.is_active == True,
            Comment.parent_comment_id.is_(None),
        )
    )
    total = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * limit
    result = await db.execute(
        select(Comment)
        .where(
            Comment.post_id == post_id,
            Comment.is_active == True,
            Comment.parent_comment_id.is_(None),
        )
        .order_by(Comment.created_at.asc())
        .offset(offset)
        .limit(limit)
    )
    comments = list(result.scalars().all())

    liked = await _liked_comment_ids(db, user_id, [c.id for c in comments])
    items = [_serialize_comment(c, c.id in liked) for c in comments]
    pages = (total + limit - 1) // limit if limit > 0 else 1

    return {"items": items, "total": total, "page": page, "pages": pages}


async def get_replies(
    db: AsyncSession,
    parent_comment_id: uuid.UUID,
    page: int = 1,
    limit: int = 20,
    user_id: uuid.UUID | None = None,
) -> dict:
    """Obtener replies a un comentario."""
    count_query = (
        select(func.count())
        .select_from(Comment)
        .where(
            Comment.parent_comment_id == parent_comment_id,
            Comment.is_active == True,
        )
    )
    total = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * limit
    result = await db.execute(
        select(Comment)
        .where(
            Comment.parent_comment_id == parent_comment_id,
            Comment.is_active == True,
        )
        .order_by(Comment.created_at.asc())
        .offset(offset)
        .limit(limit)
    )
    replies = list(result.scalars().all())

    liked = await _liked_comment_ids(db, user_id, [c.id for c in replies])
    items = [_serialize_comment(c, c.id in liked) for c in replies]
    pages = (total + limit - 1) // limit if limit > 0 else 1

    return {"items": items, "total": total, "page": page, "pages": pages}


async def soft_delete_comment(db: AsyncSession, comment: Comment) -> None:
    """Soft delete de un comentario."""
    comment.is_active = False
    # Decrementar counter cache del post
    await db.execute(
        update(Post).where(Post.id == comment.post_id).values(
            comments_count=greatest(Post.comments_count - 1, 0)
        )
    )
    # Si era un reply, decrementar replies_count del parent
    if comment.parent_comment_id is not None:
        await db.execute(
            update(Comment).where(Comment.id == comment.parent_comment_id).values(
                replies_count=greatest(Comment.replies_count - 1, 0)
            )
        )
    await db.commit()


async def get_comment_by_id(db: AsyncSession, comment_id: uuid.UUID) -> Comment | None:
    """Obtener comentario por ID."""
    result = await db.execute(select(Comment).where(Comment.id == comment_id))
    return result.scalar_one_or_none()


async def toggle_comment_like(
    db: AsyncSession,
    comment: Comment,
    user_id: uuid.UUID,
) -> dict:
    """Toggle like en un comentario. Retorna estado y nuevo count. Notifica al autor."""
    result = await db.execute(
        select(CommentLike).where(
            CommentLike.comment_id == comment.id,
            CommentLike.user_id == user_id,
        )
    )
    existing = result.scalar_one_or_none()

    if existing:
        await db.delete(existing)
        await db.execute(
            update(Comment).where(Comment.id == comment.id).values(
                likes_count=greatest(Comment.likes_count - 1, 0)
            )
        )
        await db.commit()
        await db.refresh(comment)
        return {"liked": False, "likes_count": comment.likes_count}

    db.add(CommentLike(comment_id=comment.id, user_id=user_id))
    await db.execute(
        update(Comment).where(Comment.id == comment.id).values(
            likes_count=Comment.likes_count + 1
        )
    )
    await db.commit()
    await db.refresh(comment)

    # Notificar al autor del comentario (si no es uno mismo)
    if comment.user_id != user_id:
        from app.services import notification_dispatcher
        actor_result = await db.execute(
            select(User.username).where(User.id == user_id)
        )
        actor_username = actor_result.scalar() or "Alguien"
        await notification_dispatcher.notify_user(
            db,
            user_id=comment.user_id,
            title="Nuevo me gusta ❤️",
            body=f"A @{actor_username} le gustó tu comentario",
            data={
                "type": "comment_like",
                "post_id": str(comment.post_id),
                "comment_id": str(comment.id),
            },
        )

    return {"liked": True, "likes_count": comment.likes_count}


async def update_comment(
    db: AsyncSession,
    comment: Comment,
    content: str,
) -> Comment:
    """Editar el contenido de un comentario (la autoría se valida en el router)."""
    comment.content = content
    await db.commit()
    await db.refresh(comment)
    return comment


# ===================== REPORTS =====================

async def create_report(
    db: AsyncSession,
    reporter_id: uuid.UUID,
    reason: str,
    description: str | None = None,
    post_id: uuid.UUID | None = None,
    comment_id: uuid.UUID | None = None,
    reported_user_id: uuid.UUID | None = None,
) -> Report:
    """Crear reporte de contenido."""
    report = Report(
        reporter_id=reporter_id,
        post_id=post_id,
        comment_id=comment_id,
        reported_user_id=reported_user_id,
        reason=reason,
        description=description,
    )
    db.add(report)

    # Marcar post como reportado si aplica
    if post_id:
        await db.execute(
            update(Post).where(Post.id == post_id).values(is_reported=True)
        )

    await db.commit()
    await db.refresh(report)
    return report


# ===================== ADMIN =====================

async def get_reports_paginated(
    db: AsyncSession,
    page: int = 1,
    limit: int = 20,
    status: str | None = None,
    reason: str | None = None,
) -> dict:
    """Obtener reportes paginados para admin."""
    query = select(Report)
    count_query = select(func.count()).select_from(Report)

    if status:
        query = query.where(Report.status == status)
        count_query = count_query.where(Report.status == status)
    if reason:
        query = query.where(Report.reason == reason)
        count_query = count_query.where(Report.reason == reason)

    total = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * limit
    result = await db.execute(
        query.order_by(Report.created_at.desc()).offset(offset).limit(limit)
    )
    reports = list(result.scalars().all())

    items = []
    for r in reports:
        item = {
            "id": str(r.id),
            "reporter": {
                "id": str(r.reporter.id),
                "username": r.reporter.username,
                "full_name": r.reporter.full_name,
                "avatar_url": r.reporter.avatar_url,
            },
            "post_id": str(r.post_id) if r.post_id else None,
            "comment_id": str(r.comment_id) if r.comment_id else None,
            "reported_user_id": str(r.reported_user_id) if r.reported_user_id else None,
            "reason": r.reason,
            "description": r.description,
            "status": r.status,
            "reviewed_by": str(r.reviewed_by) if r.reviewed_by else None,
            "reviewed_at": r.reviewed_at.isoformat() if r.reviewed_at else None,
            "created_at": r.created_at.isoformat(),
            "post_content": r.post.content if r.post else None,
            "comment_content": r.comment.content if r.comment else None,
            "reported_username": r.reported_user.username if r.reported_user else None,
        }
        items.append(item)

    pages = (total + limit - 1) // limit if limit > 0 else 1
    return {"items": items, "total": total, "page": page, "pages": pages}


async def update_report_status(
    db: AsyncSession,
    report_id: uuid.UUID,
    status: str,
    admin_id: uuid.UUID,
) -> Report | None:
    """Actualizar estado de un reporte."""
    result = await db.execute(select(Report).where(Report.id == report_id))
    report = result.scalar_one_or_none()
    if not report:
        return None

    report.status = status
    report.reviewed_by = admin_id
    report.reviewed_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(report)
    return report


async def admin_delete_post(db: AsyncSession, post_id: uuid.UUID) -> bool:
    """Admin fuerza soft delete de un post."""
    result = await db.execute(select(Post).where(Post.id == post_id))
    post = result.scalar_one_or_none()
    if not post:
        return False

    post.is_active = False
    post.is_reported = True
    await db.execute(
        update(User).where(User.id == post.user_id).values(
            posts_count=greatest(User.posts_count - 1, 0)
        )
    )
    await db.commit()
    return True


async def admin_delete_comment(db: AsyncSession, comment_id: uuid.UUID) -> bool:
    """Admin elimina un comentario."""
    result = await db.execute(select(Comment).where(Comment.id == comment_id))
    comment = result.scalar_one_or_none()
    if not comment:
        return False

    comment.is_active = False
    await db.execute(
        update(Post).where(Post.id == comment.post_id).values(
            comments_count=greatest(Post.comments_count - 1, 0)
        )
    )
    await db.commit()
    return True


async def get_social_stats(db: AsyncSession) -> dict:
    """Estadísticas de la red social para admin."""
    total_posts = (
        await db.execute(select(func.count()).select_from(Post).where(Post.is_active == True))
    ).scalar() or 0

    total_comments = (
        await db.execute(
            select(func.count()).select_from(Comment).where(Comment.is_active == True)
        )
    ).scalar() or 0

    total_likes = (
        await db.execute(select(func.count()).select_from(Like))
    ).scalar() or 0

    total_reports_pending = (
        await db.execute(
            select(func.count()).select_from(Report).where(Report.status == "pending")
        )
    ).scalar() or 0

    total_users_banned = (
        await db.execute(
            select(func.count()).select_from(User).where(User.is_banned == True)
        )
    ).scalar() or 0

    # Top 5 usuarios más activos (más posts)
    top_users_result = await db.execute(
        select(User)
        .where(User.is_active == True, User.is_banned == False)
        .order_by(User.posts_count.desc())
        .limit(5)
    )
    top_users = [
        {
            "id": str(u.id),
            "username": u.username,
            "full_name": u.full_name,
            "avatar_url": u.avatar_url,
            "posts_count": u.posts_count,
        }
        for u in top_users_result.scalars().all()
    ]

    return {
        "total_posts": total_posts,
        "total_comments": total_comments,
        "total_likes": total_likes,
        "total_reports_pending": total_reports_pending,
        "total_users_banned": total_users_banned,
        "most_active_users": top_users,
    }


# ===================== HELPERS =====================

def _build_post_response(post: Post, is_liked: bool, is_saved: bool = False) -> dict:
    """Construir diccionario de respuesta para un post."""
    practice_summary = None
    if post.practice_session:
        ps = post.practice_session
        # Obtener título de la lección
        lesson_title = None
        if hasattr(ps, "lesson") and ps.lesson:
            lesson_title = ps.lesson.title
        practice_summary = {
            "id": str(ps.id),
            "score": ps.score,
            "correct_notes": ps.correct_notes,
            "total_notes": ps.total_notes,
            "total_time_seconds": ps.total_time_seconds,
            "lesson_title": lesson_title,
        }

    return {
        "id": str(post.id),
        "user": {
            "id": str(post.user.id),
            "username": post.user.username,
            "full_name": post.user.full_name,
            "avatar_url": post.user.avatar_url,
        },
        "content": post.content,
        "post_type": post.post_type,
        "media_url": post.media_url,
        "media_thumbnail_url": post.media_thumbnail_url,
        "practice_session": practice_summary,
        "likes_count": post.likes_count,
        "comments_count": post.comments_count,
        "is_liked_by_me": is_liked,
        "is_saved_by_me": is_saved,
        "created_at": post.created_at.isoformat(),
        "updated_at": post.updated_at.isoformat() if post.updated_at else None,
    }
