"""Tests del flujo de autenticación con Google OAuth (Issue #137 - E2E-KEY).

Cubre:
1. Registro de nuevo usuario a partir del token de Google.
2. Login de usuario Google existente sin duplicar registros.
3. Vinculación automática de perfil preexistente con email verificado (Criterio 3).
4. Rechazo de vinculación si el email en Google no está verificado.
5. Rechazo de tokens inválidos, expirados o incompletos (sin sub / sin email).
6. Rechazo de usuarios inactivos / suspendidos.
7. Generación válida de JWT (access_token, refresh_token) y cookie httpOnly pv_refresh_token.
"""

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.services import auth_service


def _fake_payload(**overrides):
    payload = {
        "sub": "google-sub-123",
        "email": "googler@example.com",
        "name": "Google User",
        "picture": "https://example.com/avatar.png",
        "email_verified": True,
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
        assert "refresh_token" in data
        assert data["user"]["email"] == "googler@example.com"
        assert data["user"]["full_name"] == "Google User"
        assert data["user"]["avatar_url"] == "https://example.com/avatar.png"
        assert data["user"]["is_verified"] is True
        assert "pv_refresh_token" in resp.headers.get("set-cookie", "")

    async def test_invalid_token_returns_401(self, client: AsyncClient, monkeypatch):
        def _raise(*a, **k):
            raise ValueError("token inválido")

        monkeypatch.setattr(auth_service.google_id_token, "verify_oauth2_token", _raise)
        resp = await client.post("/api/auth/google", json={"google_token": "bad"})
        assert resp.status_code == 401
        assert resp.json()["detail"] == "Token de Google inválido o expirado"

    async def test_payload_without_email_is_rejected(self, client: AsyncClient, monkeypatch):
        monkeypatch.setattr(
            auth_service.google_id_token,
            "verify_oauth2_token",
            lambda *a, **k: _fake_payload(email=None),
        )
        resp = await client.post("/api/auth/google", json={"google_token": "valid"})
        assert resp.status_code == 401
        assert resp.json()["detail"] == "No se pudo obtener información de Google"

    async def test_payload_without_sub_is_rejected(self, client: AsyncClient, monkeypatch):
        monkeypatch.setattr(
            auth_service.google_id_token,
            "verify_oauth2_token",
            lambda *a, **k: _fake_payload(sub=None),
        )
        resp = await client.post("/api/auth/google", json={"google_token": "valid"})
        assert resp.status_code == 401
        assert resp.json()["detail"] == "No se pudo obtener información de Google"

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
        assert second.json()["user"]["email"] == "repeat@example.com"
        assert first.json()["user"]["id"] == second.json()["user"]["id"]

    async def test_existing_local_user_auto_links_when_verified(
        self, client: AsyncClient, db_session: AsyncSession, test_user: User, monkeypatch
    ):
        """Criterio 3: Vinculación automática del perfil si el email está verificado por Google."""
        assert test_user.google_id is None
        assert test_user.avatar_url is None

        monkeypatch.setattr(
            auth_service.google_id_token,
            "verify_oauth2_token",
            lambda *a, **k: _fake_payload(
                sub="new-google-sub-999",
                email=test_user.email,
                name="Google Updated Name",
                picture="https://example.com/avatar_linked.png",
                email_verified=True,
            ),
        )

        resp = await client.post("/api/auth/google", json={"google_token": "valid"})
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["user"]["id"] == str(test_user.id)
        assert data["user"]["email"] == test_user.email
        assert data["user"]["avatar_url"] == "https://example.com/avatar_linked.png"
        assert data["user"]["is_verified"] is True

        # Verificar en base de datos la vinculación efectiva
        await db_session.refresh(test_user)
        assert test_user.google_id == "new-google-sub-999"
        assert test_user.avatar_url == "https://example.com/avatar_linked.png"
        assert test_user.is_verified is True

    async def test_existing_local_user_rejected_if_unverified_email(
        self, client: AsyncClient, test_user: User, monkeypatch
    ):
        """Si el email de Google no está verificado, se rechaza la vinculación (previene takeover)."""
        monkeypatch.setattr(
            auth_service.google_id_token,
            "verify_oauth2_token",
            lambda *a, **k: _fake_payload(
                sub="unverified-sub-456",
                email=test_user.email,
                email_verified=False,
            ),
        )
        resp = await client.post("/api/auth/google", json={"google_token": "valid"})
        assert resp.status_code == 409
        assert "no está verificado" in resp.json()["detail"]

    async def test_inactive_user_cannot_login_with_google(
        self, client: AsyncClient, db_session: AsyncSession, test_user: User, monkeypatch
    ):
        """Usuarios desactivados/suspendidos no pueden autenticarse con Google."""
        test_user.is_active = False
        await db_session.commit()

        monkeypatch.setattr(
            auth_service.google_id_token,
            "verify_oauth2_token",
            lambda *a, **k: _fake_payload(sub="inactive-sub", email=test_user.email),
        )
        resp = await client.post("/api/auth/google", json={"google_token": "valid"})
        assert resp.status_code == 401
        assert resp.json()["detail"] == "Cuenta desactivada"
