"""Fase 2 social: is_followed_by_me en listas, pestaña media y sugerencias."""

import uuid

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.utils.security import hash_password


def _make_user(email: str, username: str) -> User:
    return User(
        id=uuid.uuid4(),
        email=email,
        username=username,
        full_name=username.capitalize(),
        hashed_password=hash_password("TestPass123"),
        auth_provider="local",
        is_active=True,
        is_verified=True,
    )


class TestProfilesAndFollowers:
    async def test_following_list_marks_is_followed_by_me(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        u2 = _make_user("u2@example.com", "usertwo")
        db_session.add(u2)
        await db_session.commit()

        me = (await client.get("/api/auth/me", headers=auth_headers)).json()

        # test_user sigue a u2
        follow = await client.post(f"/api/users/{u2.id}/follow", headers=auth_headers)
        assert follow.status_code == 200, follow.text

        # La lista "siguiendo" de test_user marca is_followed_by_me=True para u2
        following = await client.get(f"/api/users/{me['id']}/following", headers=auth_headers)
        assert following.status_code == 200, following.text
        items = following.json()["items"]
        u2_item = next((i for i in items if i["id"] == str(u2.id)), None)
        assert u2_item is not None
        assert u2_item["is_followed_by_me"] is True

    async def test_suggestions_exclude_followed_and_self(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        u2 = _make_user("s2@example.com", "sugtwo")
        u3 = _make_user("s3@example.com", "sugthree")
        db_session.add_all([u2, u3])
        await db_session.commit()

        me = (await client.get("/api/auth/me", headers=auth_headers)).json()
        await client.post(f"/api/users/{u2.id}/follow", headers=auth_headers)

        sug = await client.get("/api/users/suggestions", headers=auth_headers)
        assert sug.status_code == 200, sug.text
        ids = {u["id"] for u in sug.json()}
        assert str(u2.id) not in ids  # ya seguido
        assert me["id"] not in ids  # uno mismo
        assert str(u3.id) in ids  # sugerido

    async def test_media_tab_only_posts_with_media(self, client: AsyncClient, auth_headers: dict):
        me = (await client.get("/api/auth/me", headers=auth_headers)).json()

        text_post = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={"content": "solo texto", "post_type": "text"},
        )
        media_post = await client.post(
            "/api/posts",
            headers=auth_headers,
            json={
                "content": "con foto",
                "post_type": "image",
                "media_url": "https://example.com/a.jpg",
            },
        )
        assert text_post.status_code == 201
        assert media_post.status_code == 201

        media = await client.get(f"/api/users/{me['id']}/media", headers=auth_headers)
        assert media.status_code == 200, media.text
        ids = {p["id"] for p in media.json()["items"]}
        assert media_post.json()["id"] in ids
        assert text_post.json()["id"] not in ids
