"""Tests for lessons endpoints."""

from httpx import AsyncClient


class TestLessonsRequireAuth:
    """Lessons endpoints require authentication."""

    async def test_list_categories_no_auth(self, client: AsyncClient):
        response = await client.get("/api/lessons/categories")
        assert response.status_code in (401, 403)

    async def test_list_lessons_no_auth(self, client: AsyncClient):
        response = await client.get("/api/lessons")
        assert response.status_code in (401, 403)


class TestListCategories:
    """Tests for GET /api/lessons/categories."""

    async def test_list_categories(self, client: AsyncClient, auth_headers: dict):
        response = await client.get("/api/lessons/categories", headers=auth_headers)
        assert response.status_code == 200
        assert isinstance(response.json(), list)


class TestListLessons:
    """Tests for GET /api/lessons."""

    async def test_list_lessons(self, client: AsyncClient, auth_headers: dict):
        response = await client.get("/api/lessons", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "items" in data or isinstance(data, dict)

    async def test_list_lessons_pagination(self, client: AsyncClient, auth_headers: dict):
        response = await client.get(
            "/api/lessons",
            params={"page": 1, "limit": 5},
            headers=auth_headers,
        )
        assert response.status_code == 200
