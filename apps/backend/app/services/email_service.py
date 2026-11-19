"""Servicio de envío de emails con SMTP async (fallback a logging si no hay SMTP)."""

import logging
from email.message import EmailMessage

import aiosmtplib

from app.config import settings

logger = logging.getLogger(__name__)


def _is_smtp_configured() -> bool:
    """Verificar si las credenciales SMTP están configuradas."""
    return bool(settings.smtp_host and settings.smtp_user and settings.smtp_password)


async def _send_email(to: str, subject: str, html_body: str, text_body: str | None = None) -> None:
    """Enviar un email via SMTP con fallback a logging si no está configurado."""
    if not _is_smtp_configured():
        logger.warning(
            "[SMTP NO CONFIGURADO] Email no enviado a %s — subject: %s",
            to,
            subject,
        )
        return

    from_addr = settings.smtp_from_email or settings.smtp_user
    msg = EmailMessage()
    msg["From"] = f"{settings.smtp_from_name} <{from_addr}>"
    msg["To"] = to
    msg["Subject"] = subject

    # Multipart con fallback en texto plano (mejora score antispam SPF/DKIM)
    plain_content = text_body or subject
    msg.set_content(plain_content)
    msg.add_alternative(html_body, subtype="html")

    # Puerto 465 usa TLS implícito (directo), 587/25 usa STARTTLS explícito
    use_tls = settings.smtp_port == 465
    start_tls = not use_tls

    try:
        await aiosmtplib.send(
            msg,
            hostname=settings.smtp_host,
            port=settings.smtp_port,
            username=settings.smtp_user,
            password=settings.smtp_password,
            use_tls=use_tls,
            start_tls=start_tls,
            timeout=15.0,
        )
        logger.info("Email enviado exitosamente a: %s", to)
    except Exception:
        logger.exception("Error enviando email a %s — se omite el envío", to)


async def send_verification_email(email: str, username: str) -> None:
    """Enviar email de verificación de cuenta."""
    subject = "Verifica tu cuenta en Aliento Andino"
    text_body = (
        f"¡Bienvenido a Aliento Andino, {username}!\n\n"
        "Gracias por registrarte. Tu cuenta ha sido creada exitosamente.\n\n"
        "Aliento Andino"
    )
    html = f"""
    <div style="font-family: 'Inter', sans-serif; max-width: 600px; margin: 0 auto; padding: 24px;">
      <h2 style="color: #6366f1;">¡Bienvenido a Aliento Andino!</h2>
      <p>Hola <strong>{username}</strong>,</p>
      <p>Gracias por registrarte. Tu cuenta ha sido creada exitosamente.</p>
      <p style="color: #888; font-size: 12px;">Aliento Andino</p>
    </div>
    """
    await _send_email(email, subject, html, text_body=text_body)


async def send_email_verification_code(email: str, code: str) -> None:
    """Enviar email con el código de 6 dígitos para verificar la cuenta."""
    subject = "Verificá tu email — Aliento Andino"
    text_body = (
        f"Tu código de verificación en Aliento Andino es: {code}\n\n"
        "Ingresá este código en la app para confirmar que sos vos.\n"
        "Este código expira en 15 minutos.\n\n"
        "Si no creaste esta cuenta, ignorá este email.\n"
        "Aliento Andino"
    )

    digits = "".join(
        f'<span style="display:inline-block;width:40px;height:48px;line-height:48px;'
        f"text-align:center;font-size:24px;font-weight:bold;color:#111;"
        f"background:#f3f4f6;border-radius:8px;margin:0 3px;"
        f'font-family:monospace;">{d}</span>'
        for d in code
    )

    html = f"""
    <div style="font-family: 'Inter', Arial, sans-serif; max-width: 500px; margin: 0 auto;
                padding: 32px 24px; background: #ffffff;">
      <div style="text-align: center; margin-bottom: 24px;">
        <div style="display:inline-block;width:56px;height:56px;line-height:56px;
                    border-radius:50%;background:#06b6d4;color:#fff;font-size:28px;
                    text-align:center;">✉️</div>
      </div>
      <h2 style="color: #111; text-align: center; margin: 0 0 8px 0; font-size: 22px;">
        Verificá tu email
      </h2>
      <p style="color: #666; text-align: center; margin: 0 0 24px 0; font-size: 14px;">
        Ingresá este código en la app para confirmar que sos vos:
      </p>
      <div style="text-align: center; margin: 24px 0;">{digits}</div>
      <p style="color: #999; text-align: center; font-size: 13px; margin: 24px 0 0 0;">
        Este código expira en <strong>15 minutos</strong>.<br>
        Si no creaste esta cuenta, ignorá este email.
      </p>
      <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;">
      <p style="color: #bbb; text-align: center; font-size: 11px; margin: 0;">
        Aliento Andino
      </p>
    </div>
    """
    await _send_email(email, subject, html, text_body=text_body)


async def send_password_reset_email(email: str, reset_code: str) -> None:
    """Enviar email de recuperación con código de 6 dígitos."""
    subject = "Tu código de verificación — Aliento Andino"
    text_body = (
        f"Tu código para restablecer tu contraseña en Aliento Andino es: {reset_code}\n\n"
        "Este código expira en 15 minutos.\n\n"
        "Si no solicitaste este cambio, ignorá este email.\n"
        "Aliento Andino"
    )

    # Separar dígitos para mostrar estilo PIN
    digits = "".join(
        f'<span style="display:inline-block;width:40px;height:48px;line-height:48px;'
        f"text-align:center;font-size:24px;font-weight:bold;color:#111;"
        f"background:#f3f4f6;border-radius:8px;margin:0 3px;"
        f'font-family:monospace;">{d}</span>'
        for d in reset_code
    )

    html = f"""
    <div style="font-family: 'Inter', Arial, sans-serif; max-width: 500px; margin: 0 auto;
                padding: 32px 24px; background: #ffffff;">
      <div style="text-align: center; margin-bottom: 24px;">
        <div style="display:inline-block;width:56px;height:56px;line-height:56px;
                    border-radius:50%;background:#6366f1;color:#fff;font-size:28px;
                    text-align:center;">🔑</div>
      </div>
      <h2 style="color: #111; text-align: center; margin: 0 0 8px 0; font-size: 20px;">
        Código de verificación
      </h2>
      <p style="color: #666; text-align: center; margin: 0 0 24px 0; font-size: 14px;">
        Usá este código para restablecer tu contraseña:
      </p>
      <div style="text-align: center; margin: 24px 0;">
        {digits}
      </div>
      <p style="color: #999; text-align: center; font-size: 13px; margin: 24px 0 0 0;">
        Este código expira en <strong>15 minutos</strong>.<br>
        Si no solicitaste este cambio, ignorá este email.
      </p>
      <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;">
      <p style="color: #bbb; text-align: center; font-size: 11px; margin: 0;">
        Aliento Andino
      </p>
    </div>
    """
    await _send_email(email, subject, html, text_body=text_body)
