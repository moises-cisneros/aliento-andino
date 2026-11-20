"""Pruebas unitarias y de integración para la entrega de correos electrónicos vía SMTP.

Cubre los criterios de la Issue #138 (Parte de #136):
1. Configuración de variables SMTP y validación de modos (puerto 587 STARTTLS vs 465 SSL).
2. Modo stub en entorno local sin credenciales (no bloquea ni lanza excepción no controlada).
3. Envío real/mockeado de código de verificación de 6 dígitos (multipart: texto plano + HTML).
4. Envío de código de restablecimiento de contraseña.
5. Tolerancia a fallos de red/SMTP.
6. Flujo E2E de generación y validación de código de verificación en endpoints /api/auth.
"""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.user import User
from app.services import email_service


class TestSmtpConfiguration:
    """Validación de variables y modo stub."""

    def test_smtp_configured_detection(self, monkeypatch):
        """Verifica que se requieran host, user y password para considerar SMTP configurado."""
        monkeypatch.setattr(settings, "smtp_host", "")
        monkeypatch.setattr(settings, "smtp_user", "user@example.com")
        monkeypatch.setattr(settings, "smtp_password", "secret")
        assert not email_service._is_smtp_configured()

        monkeypatch.setattr(settings, "smtp_host", "smtp.sendgrid.net")
        monkeypatch.setattr(settings, "smtp_user", "")
        assert not email_service._is_smtp_configured()

        monkeypatch.setattr(settings, "smtp_user", "apikey")
        monkeypatch.setattr(settings, "smtp_password", "")
        assert not email_service._is_smtp_configured()

        monkeypatch.setattr(settings, "smtp_password", "SG.test-secret-key")
        assert email_service._is_smtp_configured()

    @pytest.mark.asyncio
    async def test_stub_mode_when_smtp_unconfigured(self, monkeypatch):
        """Cuando SMTP no está configurado, la función no lanza excepción (modo stub seguro)."""
        monkeypatch.setattr(settings, "smtp_host", "")
        monkeypatch.setattr(settings, "smtp_user", "")
        monkeypatch.setattr(settings, "smtp_password", "")

        with patch("aiosmtplib.send", new_callable=AsyncMock) as mock_send:
            await email_service.send_email_verification_code(
                "estudiante@alientoandino.org", "123456"
            )
            mock_send.assert_not_called()


class TestSmtpDelivery:
    """Envío de correo y construcción de mensajes MIME."""

    @pytest.mark.asyncio
    async def test_send_verification_code_message_structure(self, monkeypatch):
        """Verifica la construcción del mensaje MIME y el envío por puerto 587 (STARTTLS)."""
        monkeypatch.setattr(settings, "smtp_host", "smtp.resend.com")
        monkeypatch.setattr(settings, "smtp_port", 587)
        monkeypatch.setattr(settings, "smtp_user", "resend")
        monkeypatch.setattr(settings, "smtp_password", "re_secret_key")
        monkeypatch.setattr(settings, "smtp_from_name", "Aliento Andino Staging")
        monkeypatch.setattr(settings, "smtp_from_email", "soporte@alientoandino.org")

        with patch("aiosmtplib.send", new_callable=AsyncMock) as mock_send:
            code = "849201"
            target_email = "alumno@alientoandino.org"

            await email_service.send_email_verification_code(target_email, code)

            assert mock_send.called
            call_args, call_kwargs = mock_send.call_args

            msg = call_args[0]
            assert msg["To"] == target_email
            assert msg["From"] == "Aliento Andino Staging <soporte@alientoandino.org>"
            assert "Verificá tu email" in msg["Subject"]

            # Verificar que el código de 6 dígitos se encuentra en el cuerpo del mensaje (texto plano y HTML)
            plain_body = msg.get_body(preferencelist=("plain",)).get_content()
            html_body = msg.get_body(preferencelist=("html",)).get_content()
            assert code in plain_body
            # En HTML cada dígito está estilizado dentro de spans
            for digit in code:
                assert digit in html_body

            # Verificación de parámetros SMTP para 587
            assert call_kwargs["hostname"] == "smtp.resend.com"
            assert call_kwargs["port"] == 587
            assert call_kwargs["start_tls"] is True
            assert call_kwargs["use_tls"] is False
            assert call_kwargs["timeout"] == 15.0

    @pytest.mark.asyncio
    async def test_port_465_uses_direct_tls(self, monkeypatch):
        """El puerto 465 debe usar TLS implícito (use_tls=True) en lugar de STARTTLS."""
        monkeypatch.setattr(settings, "smtp_host", "smtp.mailgun.org")
        monkeypatch.setattr(settings, "smtp_port", 465)
        monkeypatch.setattr(settings, "smtp_user", "postmaster@alientoandino.org")
        monkeypatch.setattr(settings, "smtp_password", "mg-secret")

        with patch("aiosmtplib.send", new_callable=AsyncMock) as mock_send:
            await email_service.send_password_reset_email("docente@alientoandino.org", "654321")

            assert mock_send.called
            call_kwargs = mock_send.call_args[1]
            assert call_kwargs["use_tls"] is True
            assert call_kwargs["start_tls"] is False
            assert call_kwargs["port"] == 465

    @pytest.mark.asyncio
    async def test_send_verification_welcome_email(self, monkeypatch):
        """Verifica la generación y envío del email de bienvenida al registrarse."""
        monkeypatch.setattr(settings, "smtp_host", "smtp.resend.com")
        monkeypatch.setattr(settings, "smtp_user", "resend")
        monkeypatch.setattr(settings, "smtp_password", "re_secret")

        with patch("aiosmtplib.send", new_callable=AsyncMock) as mock_send:
            await email_service.send_verification_email("nuevo@alientoandino.org", "flautista")
            assert mock_send.called
            msg = mock_send.call_args[0][0]
            assert msg["To"] == "nuevo@alientoandino.org"
            assert "flautista" in msg.get_body(preferencelist=("plain",)).get_content()

    @pytest.mark.asyncio
    async def test_smtp_exception_does_not_crash_caller(self, monkeypatch):
        """Si el servidor SMTP rechaza la conexión o hace timeout, se logea el error sin propagar crash."""
        monkeypatch.setattr(settings, "smtp_host", "smtp.unreachable.test")
        monkeypatch.setattr(settings, "smtp_user", "test")
        monkeypatch.setattr(settings, "smtp_password", "secret")

        with patch("aiosmtplib.send", side_effect=TimeoutError("SMTP connection timed out")):
            # No debe levantar excepción no capturada
            await email_service.send_email_verification_code("test@alientoandino.org", "111222")


class TestEmailVerificationFlowIntegration:
    """Flujo E2E de generación y validación del código de verificación de 6 dígitos."""

    @pytest.mark.asyncio
    async def test_request_and_verify_email_flow(
        self, client: AsyncClient, test_user: User, db_session: AsyncSession
    ):
        """Simula solicitud de código y validación exitosa."""
        # Configurar usuario como no verificado
        test_user.is_verified = False
        await db_session.commit()

        # Login para obtener JWT de auth
        login_res = await client.post(
            "/api/auth/login",
            json={"email": test_user.email, "password": "TestPass123"},
        )
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        with patch(
            "app.services.email_service.send_email_verification_code", new_callable=AsyncMock
        ) as mock_send:
            # 1. Solicitar código de verificación
            res_code = await client.post("/api/auth/send-verification-code", headers=headers)
            assert res_code.status_code == 200
            assert res_code.json()["message"] == "Código enviado a tu email"

            # Validar que se llamó al servicio de email
            mock_send.assert_called_once()
            called_email, called_code = mock_send.call_args[0]
            assert called_email == test_user.email
            assert len(called_code) == 6
            assert called_code.isdigit()

            # 2. Verificar código incorrecto debe fallar con 400
            res_bad = await client.post(
                "/api/auth/verify-email",
                json={"code": "000000" if called_code != "000000" else "111111"},
                headers=headers,
            )
            assert res_bad.status_code == 400
            assert "incorrecto" in res_bad.json()["detail"].lower()

            # 3. Verificar código correcto debe responder 200 y marcar is_verified=True
            res_good = await client.post(
                "/api/auth/verify-email",
                json={"code": called_code},
                headers=headers,
            )
            assert res_good.status_code == 200

            # Confirmar en base de datos
            await db_session.refresh(test_user)
            assert test_user.is_verified is True
            assert test_user.email_verification_code is None

    @pytest.mark.asyncio
    async def test_verify_email_rejects_expired_code(
        self, client: AsyncClient, test_user: User, db_session: AsyncSession
    ):
        """Un código con tiempo de expiración vencido debe ser rechazado con HTTP 400."""
        test_user.is_verified = False
        test_user.email_verification_code = "998877"
        test_user.email_verification_expires = datetime.now(UTC) - timedelta(minutes=5)
        await db_session.commit()

        login_res = await client.post(
            "/api/auth/login",
            json={"email": test_user.email, "password": "TestPass123"},
        )
        headers = {"Authorization": f"Bearer {login_res.json()['access_token']}"}

        res = await client.post(
            "/api/auth/verify-email",
            json={"code": "998877"},
            headers=headers,
        )
        assert res.status_code == 400
        assert "expiró" in res.json()["detail"].lower()
