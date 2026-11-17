"""Servicio FCM usando firebase-admin SDK (más simple y confiable que HTTP v1 a mano)."""

import logging
from collections.abc import Iterable
from pathlib import Path

from app.config import settings

logger = logging.getLogger(__name__)

_app_initialized = False

# Límite duro de tokens por llamada multicast en la API de FCM.
_MAX_MULTICAST_TOKENS = 500


def _resolve_credentials_path() -> Path | None:
    raw = settings.google_application_credentials
    if not raw:
        return None
    p = Path(raw)
    if not p.is_absolute():
        p = Path(__file__).resolve().parent.parent.parent / p
    if not p.exists():
        logger.warning("Credenciales FCM no encontradas en %s", p)
        return None
    return p


def _ensure_app():
    """Inicializa firebase-admin una sola vez (idempotente).

    Usa el archivo de service account si está configurado (dev local) o, si no,
    Application Default Credentials (ADC). En la VM de GCP, ADC = la service
    account de la instancia (la misma que ya usa Vertex), así no hace falta
    montar un archivo de secreto en producción.
    """
    global _app_initialized
    if _app_initialized:
        return True

    try:
        import firebase_admin
        from firebase_admin import credentials

        if not firebase_admin._apps:
            options = {"projectId": settings.vertex_project_id or None}
            cred_path = _resolve_credentials_path()
            if cred_path is not None:
                # Dev local: archivo de service account.
                cred = credentials.Certificate(str(cred_path))
                firebase_admin.initialize_app(cred, options)
            else:
                # Producción: Application Default Credentials (SA de la VM).
                logger.info("FCM: inicializando con Application Default Credentials (ADC)")
                firebase_admin.initialize_app(credentials.ApplicationDefault(), options)
        _app_initialized = True
        return True
    except Exception as e:
        logger.error("Error inicializando firebase-admin: %s", e, exc_info=True)
        return False


async def send_to_tokens(
    *,
    tokens: Iterable[str],
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> tuple[int, list[str]]:
    """Envía una notificación FCM a múltiples tokens.

    Devuelve (success_count, invalid_tokens). Los tokens inválidos deberían
    borrarse de la BD.
    """
    token_list = list(tokens)
    if not token_list:
        return 0, []
    if not _ensure_app():
        return 0, []

    from firebase_admin import messaging

    success_count = 0
    invalid: list[str] = []

    # firebase-admin envía via gRPC y maneja la auth correctamente.
    # send_each_for_multicast acepta como MÁXIMO 500 tokens por llamada, así que
    # particionamos en lotes para soportar audiencias grandes sin fallar.
    try:
        for start in range(0, len(token_list), _MAX_MULTICAST_TOKENS):
            chunk = token_list[start : start + _MAX_MULTICAST_TOKENS]
            message = messaging.MulticastMessage(
                tokens=chunk,
                notification=messaging.Notification(title=title, body=body),
                data={k: str(v) for k, v in (data or {}).items()},
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="aliento_andino_default",
                    ),
                ),
            )
            response = messaging.send_each_for_multicast(message)
            success_count += response.success_count

            for idx, resp in enumerate(response.responses):
                if not resp.success and resp.exception is not None:
                    code = getattr(resp.exception, "code", None)
                    # Tokens muertos / no registrados / de otro sender: se
                    # marcan inválidos para borrarlos de la BD y no reintentar.
                    if code in {
                        "UNREGISTERED",
                        "registration-token-not-registered",
                        "INVALID_ARGUMENT",
                        "invalid-argument",
                        "NOT_FOUND",  # el token ya no existe (app desinstalada / rotado)
                        "SENDER_ID_MISMATCH",  # token registrado contra otro proyecto FCM
                    }:
                        invalid.append(chunk[idx])
                    logger.warning(
                        "FCM token=%s... code=%s msg=%s",
                        chunk[idx][:20],
                        code,
                        resp.exception,
                    )
    except Exception as e:
        logger.error("Error enviando FCM (multicast): %s", e, exc_info=True)
        return success_count, invalid

    logger.info("FCM enviado: %d ok, %d inválidos", success_count, len(invalid))
    return success_count, invalid
