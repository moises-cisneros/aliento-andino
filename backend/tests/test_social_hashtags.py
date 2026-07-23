"""Fase 1 social: hashtags con feed propio y notificación de @menciones."""

import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.utils.security import hash_password


class TestHashtags:
    async def test_post_creates_hashtag_and_appears_in_feed(
        self, client: AsyncClient, auth_headers: dict
    ):
        resp = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={"content": "Practicando #Jazz y #blues hoy", "post_type": "text"},
        )
        assert resp.status_code == 201, resp.text
        post_id = resp.json()["id"]

        # Feed por hashtag (normalizado a minúscula).
        feed = await client.get("/api/hashtags/jazz/feed", headers=auth_headers)
        assert feed.status_code == 200, feed.text
        assert any(p["id"] == post_id for p in feed.json()["items"])

        # Case-insensitive en la ruta.
        feed2 = await client.get("/api/hashtags/JAZZ/feed", headers=auth_headers)
        assert any(p["id"] == post_id for p in feed2.json()["items"])

        # Un hashtag distinto del mismo post.
        feed3 = await client.get("/api/hashtags/blues/feed", headers=auth_headers)
        assert any(p["id"] == post_id for p in feed3.json()["items"])

    async def test_hashtag_feed_empty_for_unknown_tag(
        self, client: AsyncClient, auth_headers: dict
    ):
        feed = await client.get("/api/hashtags/noexiste/feed", headers=auth_headers)
        assert feed.status_code == 200
        assert feed.json()["items"] == []


class TestMentions:
    async def test_mention_notifies_user(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        # Segundo usuario creado vía db_session (committed) + login para su token.
        user2 = User(
            id=uuid.uuid4(),
            email="mentioned@example.com",
            username="mentioneduser",
            full_name="Mentioned",
            hashed_password=hash_password("TestPass123"),
            auth_provider="local",
            is_active=True,
            is_verified=True,
        )
        db_session.add(user2)
        await db_session.commit()

        login = await client.post(
            "/api/auth/login",
            json={"email": "mentioned@example.com", "password": "TestPass123"},
        )
        assert login.status_code == 200, login.text
        headers2 = {"Authorization": f"Bearer {login.json()['access_token']}"}

        # test_user menciona a @mentioneduser.
        resp = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={"content": "Gran dúo con @mentioneduser 🎹", "post_type": "text"},
        )
        assert resp.status_code == 201, resp.text

        # El usuario mencionado recibe una notificación type=mention.
        notifs = await client.get("/api/notifications", headers=headers2)
        assert notifs.status_code == 200, notifs.text
        assert any(
            n["type"] == "mention" for n in notifs.json()["items"]
        ), notifs.json()

    async def test_no_self_mention_notification(
        self, client: AsyncClient, auth_headers: dict
    ):
        me = await client.get("/api/auth/me", headers=auth_headers)
        my_username = me.json()["username"]

        await client.post(
            "/api/posts",
            headers=auth_headers,
            json={
                "content": f"Nota para @{my_username} mismo",
                "post_type": "text",
            },
        )
        notifs = await client.get("/api/notifications", headers=auth_headers)
        assert notifs.status_code == 200
        assert all(n["type"] != "mention" for n in notifs.json()["items"])
