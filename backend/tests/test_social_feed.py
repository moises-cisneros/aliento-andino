"""Fase 4 social: feed cronológico global (/feed/recent)."""

import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.utils.security import hash_password


class TestRecentFeed:
    async def test_recent_feed_includes_posts_from_non_followed_users(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        # Otro usuario al que NO seguimos.
        other = User(
            id=uuid.uuid4(),
            email="stranger@example.com",
            username="strangerx",
            full_name="Stranger",
            hashed_password=hash_password("TestPass123"),
            auth_provider="local",
            is_active=True,
            is_verified=True,
        )
        db_session.add(other)
        await db_session.commit()

        login = await client.post(
            "/api/auth/login",
            json={"email": "stranger@example.com", "password": "TestPass123"},
        )
        other_headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

        # El extraño publica.
        post = await client.post(
            "/api/posts",
            headers=other_headers,
            json={"content": "Post de un desconocido", "post_type": "text"},
        )
        post_id = post.json()["id"]

        # NO aparece en el feed de seguidos...
        following = await client.get("/api/feed", headers=auth_headers)
        assert following.status_code == 200
        assert all(p["id"] != post_id for p in following.json()["items"])

        # ...pero SÍ en el feed reciente global.
        recent = await client.get("/api/feed/recent", headers=auth_headers)
        assert recent.status_code == 200, recent.text
        assert any(p["id"] == post_id for p in recent.json()["items"])

    async def test_recent_feed_is_descending_and_paginates(
        self, client: AsyncClient, auth_headers: dict
    ):
        for i in range(3):
            await client.post(
                "/api/posts",
                headers=auth_headers,
                json={"content": "Post $i".replace("$i", str(i)), "post_type": "text"},
            )

        recent = await client.get(
            "/api/feed/recent",
            headers=auth_headers,
            params={"limit": 2},
        )
        assert recent.status_code == 200
        data = recent.json()
        assert len(data["items"]) == 2
        assert data["has_more"] is True
        assert data["next_cursor"] is not None

        # Orden cronológico descendente.
        ts = [p["created_at"] for p in data["items"]]
        assert ts == sorted(ts, reverse=True)
