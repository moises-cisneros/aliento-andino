"""Tests del flujo de autenticación con Google OAuth.

Mockea la verificación oficial del ID token (`verify_oauth2_token`) para cubrir
registro nuevo, login de usuario existente y rechazo de tokens inválidos, sin
contactar a Google.
"""

from httpx import AsyncClient

from app.services import auth_service


def _fake_payload(**overrides):
    payload = {
        "sub": "google-sub-123",
        "email": "googler@example.com",
        "name": "Google User",
        "picture": "https://example.com/avatar.png",
    }
    payload.update(overrides)
    return payload


class TestGoogleAuth:
    async def test_new_user_is_registered(self, client: AsyncClient, monkeypatch):
        monkeypatch.setattr(
            auth_service.google_id_token,
            "verify_oauth2_token",
            lambda *a, **k: _fake_payload(),
        )
        resp = await client.post("/api/auth/google", json={"google_token": "valid"})
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "access_token" in data
        assert data["user"]["email"] == "googler@example.com"
        # Google ya verificó el email.
        assert data["user"]["is_verified"] is True

    async def test_invalid_token_returns_401(self, client: AsyncClient, monkeypatch):
        def _raise(*a, **k):
            raise ValueError("token inválido")

        monkeypatch.setattr(auth_service.google_id_token, "verify_oauth2_token", _raise)
        resp = await client.post("/api/auth/google", json={"google_token": "bad"})
        assert resp.status_code == 401

    async def test_payload_without_email_is_rejected(self, client: AsyncClient, monkeypatch):
        monkeypatch.setattr(
            auth_service.google_id_token,
            "verify_oauth2_token",
            lambda *a, **k: _fake_payload(email=None),
        )
        resp = await client.post("/api/auth/google", json={"google_token": "valid"})
        assert resp.status_code == 401

    async def test_existing_google_user_logs_in(self, client: AsyncClient, monkeypatch):
        monkeypatch.setattr(
            auth_service.google_id_token,
            "verify_oauth2_token",
            lambda *a, **k: _fake_payload(sub="repeat-sub", email="repeat@example.com"),
        )
        first = await client.post("/api/auth/google", json={"google_token": "valid"})
        assert first.status_code == 200, first.text
        second = await client.post("/api/auth/google", json={"google_token": "valid"})
        assert second.status_code == 200, second.text
        # Segundo intento = login del mismo usuario (mismo email, no duplica).
        assert second.json()["user"]["email"] == "repeat@example.com"
