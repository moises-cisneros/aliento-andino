"""Fase 3 social: guardar posts (bookmark), likes en comentarios y editar comentario."""

import uuid

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.utils.security import hash_password


async def _make_user(
    client: AsyncClient,
    db_session: AsyncSession,
    *,
    email: str,
    username: str,
) -> dict:
    """Crea un usuario vía db_session (committed) y devuelve sus auth headers."""
    user = User(
        id=uuid.uuid4(),
        email=email,
        username=username,
        full_name=username.capitalize(),
        hashed_password=hash_password("TestPass123"),
        auth_provider="local",
        is_active=True,
        is_verified=True,
    )
    db_session.add(user)
    await db_session.commit()

    login = await client.post(
        "/api/auth/login",
        json={"email": email, "password": "TestPass123"},
    )
    assert login.status_code == 200, login.text
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


class TestSavePost:
    async def test_save_is_idempotent_and_appears_in_saved_feed(
        self, client: AsyncClient, auth_headers: dict
    ):
        resp = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={"content": "Post para guardar", "post_type": "text"},
        )
        assert resp.status_code == 201, resp.text
        post_id = resp.json()["id"]

        # Guardar.
        save = await client.post(f"/api/posts/{post_id}/save", headers=auth_headers)
        assert save.status_code == 200, save.text
        assert save.json()["saved"] is True

        # Aparece en /me/saved con is_saved_by_me=True.
        saved = await client.get("/api/me/saved", headers=auth_headers)
        assert saved.status_code == 200, saved.text
        items = saved.json()["items"]
        match = next((p for p in items if p["id"] == post_id), None)
        assert match is not None
        assert match["is_saved_by_me"] is True

        # Toggle de nuevo → quitado (idempotente, sin duplicar fila).
        unsave = await client.post(f"/api/posts/{post_id}/save", headers=auth_headers)
        assert unsave.status_code == 200
        assert unsave.json()["saved"] is False

        saved2 = await client.get("/api/me/saved", headers=auth_headers)
        assert all(p["id"] != post_id for p in saved2.json()["items"])

    async def test_feed_post_exposes_is_saved_flag(self, client: AsyncClient, auth_headers: dict):
        resp = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={"content": "Otro post", "post_type": "text"},
        )
        post_id = resp.json()["id"]
        await client.post(f"/api/posts/{post_id}/save", headers=auth_headers)

        detail = await client.get(f"/api/posts/{post_id}", headers=auth_headers)
        assert detail.status_code == 200
        assert detail.json()["is_saved_by_me"] is True


class TestCommentLike:
    async def test_comment_like_increments_count_and_toggles(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        other = await _make_user(
            client, db_session, email="liker@example.com", username="likeruser"
        )

        # auth_headers crea el post y el comentario.
        post = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={"content": "Post con comentario", "post_type": "text"},
        )
        post_id = post.json()["id"]
        comment = await client.post(
            f"/api/posts/{post_id}/comments",
            headers=auth_headers,
            json={"content": "Buen comentario"},
        )
        assert comment.status_code == 201, comment.text
        comment_id = comment.json()["id"]
        assert comment.json()["likes_count"] == 0
        assert comment.json()["is_liked_by_me"] is False

        # Otro usuario da like al comentario.
        like = await client.post(f"/api/comments/{comment_id}/like", headers=other)
        assert like.status_code == 200, like.text
        assert like.json()["liked"] is True
        assert like.json()["likes_count"] == 1

        # Se refleja en el listado para ese usuario.
        listing = await client.get(f"/api/posts/{post_id}/comments", headers=other)
        target = next(c for c in listing.json()["items"] if c["id"] == comment_id)
        assert target["likes_count"] == 1
        assert target["is_liked_by_me"] is True

        # El autor recibe notificación type=comment_like.
        notifs = await client.get("/api/notifications", headers=auth_headers)
        assert any(n["type"] == "comment_like" for n in notifs.json()["items"])

        # Toggle → quita el like.
        unlike = await client.post(f"/api/comments/{comment_id}/like", headers=other)
        assert unlike.json()["liked"] is False
        assert unlike.json()["likes_count"] == 0


class TestEditComment:
    async def test_owner_can_edit_comment(self, client: AsyncClient, auth_headers: dict):
        post = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={"content": "Post", "post_type": "text"},
        )
        post_id = post.json()["id"]
        comment = await client.post(
            f"/api/posts/{post_id}/comments",
            headers=auth_headers,
            json={"content": "Original"},
        )
        comment_id = comment.json()["id"]

        edit = await client.put(
            f"/api/comments/{comment_id}",
            headers=auth_headers,
            json={"content": "Editado"},
        )
        assert edit.status_code == 200, edit.text
        assert edit.json()["content"] == "Editado"

    async def test_non_owner_cannot_edit_comment(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        other = await _make_user(
            client, db_session, email="intruder@example.com", username="intruderx"
        )
        post = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={"content": "Post", "post_type": "text"},
        )
        post_id = post.json()["id"]
        comment = await client.post(
            f"/api/posts/{post_id}/comments",
            headers=auth_headers,
            json={"content": "Mío"},
        )
        comment_id = comment.json()["id"]

        edit = await client.put(
            f"/api/comments/{comment_id}",
            headers=other,
            json={"content": "Hackeado"},
        )
        assert edit.status_code == 403, edit.text


class TestPostReaction:
    """[SUB-11-A] Endpoint de contrato POST /posts/{post_id}/react."""

    async def test_react_toggles_like_and_count(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        reactor = await _make_user(
            client, db_session, email="reactor@example.com", username="reactoruser"
        )
        post = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={"content": "Post para reaccionar", "post_type": "text"},
        )
        assert post.status_code == 201, post.text
        post_id = post.json()["id"]

        # Reaccionar (contrato /react) activa el «me gusta».
        react = await client.post(f"/api/posts/{post_id}/react", headers=reactor)
        assert react.status_code == 200, react.text
        assert react.json() == {"liked": True, "likes_count": 1}

        # El post expone is_liked_by_me para quien reaccionó.
        detail = await client.get(f"/api/posts/{post_id}", headers=reactor)
        assert detail.json()["is_liked_by_me"] is True
        assert detail.json()["likes_count"] == 1

        # Toggle de nuevo quita la reacción (idempotente).
        again = await client.post(f"/api/posts/{post_id}/react", headers=reactor)
        assert again.status_code == 200
        assert again.json() == {"liked": False, "likes_count": 0}

    async def test_react_to_deleted_post_returns_404(self, client: AsyncClient, auth_headers: dict):
        post = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={"content": "Post a eliminar", "post_type": "text"},
        )
        post_id = post.json()["id"]
        deleted = await client.delete(f"/api/posts/{post_id}", headers=auth_headers)
        assert deleted.status_code in (200, 204), deleted.text

        react = await client.post(f"/api/posts/{post_id}/react", headers=auth_headers)
        assert react.status_code == 404
