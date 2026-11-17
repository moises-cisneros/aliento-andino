"""Tests for user endpoints."""

import uuid

import pytest
from httpx import AsyncClient
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.schemas.user import UserUpdate
from app.services import user_service
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

    async def test_get_profile(self, client: AsyncClient, auth_headers: dict, test_user: User):
        response = await client.get(
            f"/api/users/{test_user.id}/profile",
            headers=auth_headers,
        )
        assert response.status_code == 200

    async def test_get_nonexistent_profile(self, client: AsyncClient, auth_headers: dict):
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


class TestUserUpdateValidation:
    """Pruebas unitarias de validación Pydantic para UserUpdate (HU-19 / SUB-19-B)."""

    def test_user_update_valid_data(self):
        update = UserUpdate(
            full_name="Kantu Andino",
            avatar_url="https://example.com/avatar.png",
            preferred_instruments=["quena", "zampona"],
            breath_sensitivity_rms=0.45,
        )
        assert update.full_name == "Kantu Andino"
        assert update.avatar_url == "https://example.com/avatar.png"
        assert update.preferred_instruments == ["quena", "zampona"]
        assert update.breath_sensitivity_rms == 0.45

    def test_user_update_rms_below_zero_fails(self):
        with pytest.raises(ValidationError):
            UserUpdate(breath_sensitivity_rms=-0.01)

    def test_user_update_rms_above_one_fails(self):
        with pytest.raises(ValidationError):
            UserUpdate(breath_sensitivity_rms=1.01)

    def test_user_update_invalid_instrument_fails(self):
        with pytest.raises(ValidationError):
            UserUpdate(preferred_instruments=["guitarra"])

    def test_user_update_normalizes_and_deduplicates_instruments(self):
        update = UserUpdate(preferred_instruments=[" Quena ", "TARKA", "quena"])
        assert update.preferred_instruments == ["quena", "tarka"]

    def test_user_update_none_instruments(self):
        update = UserUpdate(preferred_instruments=None)
        assert update.preferred_instruments is None


class TestUserUpdateIntegration:
    """Pruebas de integración para persistencia de datos en base de datos (HU-19 / SUB-19-B)."""

    async def test_user_update_persists_in_db(self, db_session: AsyncSession, test_user: User):
        data = UserUpdate(
            full_name="Nuevo Nombre Quena",
            avatar_url="https://example.com/quena.jpg",
            preferred_instruments=["quena", "tarka"],
            breath_sensitivity_rms=0.38,
        )
        updated = await user_service.update_user(db_session, test_user, data)
        assert updated.full_name == "Nuevo Nombre Quena"
        assert updated.avatar_url == "https://example.com/quena.jpg"
        assert updated.preferred_instruments == ["quena", "tarka"]
        assert updated.breath_sensitivity_rms == 0.38


class TestUserUpdateE2E:
    """Pruebas E2E para PUT /api/v1/users/me y compatibilidad (HU-19 / SUB-19-B)."""

    async def test_put_users_me_requires_auth(self, client: AsyncClient):
        response = await client.put(
            "/api/v1/users/me",
            json={"full_name": "Intruso"},
        )
        assert response.status_code in (401, 403)

    async def test_put_users_me_success(self, client: AsyncClient, auth_headers: dict):
        payload = {
            "full_name": "Sikuri Maestro",
            "avatar_url": "https://example.com/sikuri.png",
            "preferred_instruments": ["zampona", "quena"],
            "breath_sensitivity_rms": 0.52,
        }
        response = await client.put(
            "/api/v1/users/me",
            headers=auth_headers,
            json=payload,
        )
        assert response.status_code == 200
        body = response.json()
        assert body["full_name"] == "Sikuri Maestro"
        assert body["avatar_url"] == "https://example.com/sikuri.png"
        assert body["preferred_instruments"] == ["zampona", "quena"]
        assert body["breath_sensitivity_rms"] == 0.52

    async def test_put_users_me_invalid_rms_returns_422(
        self, client: AsyncClient, auth_headers: dict
    ):
        response_high = await client.put(
            "/api/v1/users/me",
            headers=auth_headers,
            json={"breath_sensitivity_rms": 1.25},
        )
        assert response_high.status_code == 422

        response_neg = await client.put(
            "/api/v1/users/me",
            headers=auth_headers,
            json={"breath_sensitivity_rms": -0.1},
        )
        assert response_neg.status_code == 422

    async def test_put_users_me_invalid_instrument_returns_422(
        self, client: AsyncClient, auth_headers: dict
    ):
        response = await client.put(
            "/api/v1/users/me",
            headers=auth_headers,
            json={"preferred_instruments": ["flauta traversa"]},
        )
        assert response.status_code == 422

    async def test_put_users_me_v1_and_default_parity(
        self, client: AsyncClient, auth_headers: dict
    ):
        # Verificar que /api/users/me también responde idéntico
        response = await client.put(
            "/api/users/me",
            headers=auth_headers,
            json={"breath_sensitivity_rms": 0.33},
        )
        assert response.status_code == 200
        assert response.json()["breath_sensitivity_rms"] == 0.33
