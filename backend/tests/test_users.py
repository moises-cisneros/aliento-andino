"""Tests for user endpoints."""

import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.utils.security import hash_password


class TestSearchUsers:
    """Tests for GET /api/users/search."""

    async def test_search_requires_auth(self, client: AsyncClient):
        response = await client.get("/api/users/search", params={"q": "test"})
        assert response.status_code in (401, 403)

    async def test_search_users(self, client: AsyncClient, auth_headers: dict):
        response = await client.get(
            "/api/users/search",
            params={"q": "test"},
            headers=auth_headers,
        )
        assert response.status_code == 200

    async def test_search_query_too_short(self, client: AsyncClient, auth_headers: dict):
        response = await client.get(
            "/api/users/search",
            params={"q": "a"},
            headers=auth_headers,
        )
        assert response.status_code == 422


class TestUserProfile:
    """Tests for GET /api/users/{user_id}/profile."""

    async def test_get_profile(
        self, client: AsyncClient, auth_headers: dict, test_user: User
    ):
        response = await client.get(
            f"/api/users/{test_user.id}/profile",
            headers=auth_headers,
        )
        assert response.status_code == 200

    async def test_get_nonexistent_profile(
        self, client: AsyncClient, auth_headers: dict
    ):
        fake_id = uuid.uuid4()
        response = await client.get(
            f"/api/users/{fake_id}/profile",
            headers=auth_headers,
        )
        assert response.status_code == 404


class TestToggleFollow:
    """Tests for POST /api/users/{user_id}/follow."""

    async def test_follow_requires_auth(self, client: AsyncClient):
        response = await client.post(f"/api/users/{uuid.uuid4()}/follow")
        assert response.status_code in (401, 403)

    async def test_follow_user(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        # Create another user to follow
        other_user = User(
            id=uuid.uuid4(),
            email="other@example.com",
            username="otheruser",
            full_name="Other User",
            hashed_password=hash_password("OtherPass123"),
            auth_provider="local",
            is_active=True,
        )
        db_session.add(other_user)
        await db_session.commit()

        response = await client.post(
            f"/api/users/{other_user.id}/follow",
            headers=auth_headers,
        )
        assert response.status_code == 200
