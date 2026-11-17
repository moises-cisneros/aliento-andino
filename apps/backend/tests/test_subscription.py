"""Tests de suscripción: prueba gratis (trial) con pago simulado."""

import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


class TestFreeTrial:
    async def test_trial_available_for_fresh_user(self, client: AsyncClient, auth_headers: dict):
        r = await client.get("/api/subscription/me", headers=auth_headers)
        assert r.status_code == 200
        data = r.json()
        assert data["is_premium"] is False
        assert data["trial_used"] is False
        assert data["trial_available"] is True

    async def test_start_trial_grants_premium_once(self, client: AsyncClient, auth_headers: dict):
        r = await client.post("/api/subscription/trial", headers=auth_headers)
        assert r.status_code == 200
        data = r.json()
        assert data["is_premium"] is True
        assert data["plan"] == "trial"
        assert data["plan_label"] == "Prueba gratis"
        assert data["trial_used"] is True
        assert data["trial_available"] is False
        assert data["expires_at"] is not None

        # No se puede repetir.
        r2 = await client.post("/api/subscription/trial", headers=auth_headers)
        assert r2.status_code == 409

        # /me refleja que ya no está disponible.
        me = await client.get("/api/subscription/me", headers=auth_headers)
        assert me.json()["trial_available"] is False

    async def test_trial_requires_auth(self, client: AsyncClient):
        r = await client.post("/api/subscription/trial")
        assert r.status_code in (401, 403)
