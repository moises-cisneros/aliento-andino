"""Servicio de Cloud Storage para uploads de media (avatares, posts)."""

import logging
import uuid
from datetime import datetime

from app.config import settings

logger = logging.getLogger(__name__)

# Tipos de archivo permitidos
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/quicktime", "video/webm"}
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB
MAX_VIDEO_SIZE = 50 * 1024 * 1024  # 50 MB


def _build_object_name(folder: str, original_filename: str) -> str:
    """Construir nombre único del objeto en GCS."""
    ext = ""
    if "." in original_filename:
        ext = "." + original_filename.rsplit(".", 1)[-1].lower()
    timestamp = datetime.utcnow().strftime("%Y/%m/%d")
    return f"{folder}/{timestamp}/{uuid.uuid4()}{ext}"


async def upload_media(
    *,
    content: bytes,
    content_type: str,
    original_filename: str,
    folder: str = "posts",
) -> str:
    """Subir un archivo al bucket de media y devolver la URL pública.

    Raises:
        ValueError: tipo de archivo no permitido o tamaño excesivo.
        RuntimeError: error del cliente GCS.
    """
    if not settings.gcs_bucket_name:
        raise RuntimeError("GCS_BUCKET_NAME no configurado")

    # Validar tipo
    is_image = content_type in ALLOWED_IMAGE_TYPES
    is_video = content_type in ALLOWED_VIDEO_TYPES
    if not is_image and not is_video:
        raise ValueError(f"Tipo de archivo no permitido: {content_type}")

    # Validar tamaño
    max_size = MAX_IMAGE_SIZE if is_image else MAX_VIDEO_SIZE
    if len(content) > max_size:
        raise ValueError(f"Archivo demasiado grande ({len(content)} bytes, máx {max_size})")

    # Import diferido para no cargar la SDK si no se usa
    from google.cloud import storage

    object_name = _build_object_name(folder, original_filename)
    client = storage.Client(project=settings.vertex_project_id or None)
    bucket = client.bucket(settings.gcs_bucket_name)
    blob = bucket.blob(object_name)

    try:
        blob.upload_from_string(content, content_type=content_type)
    except Exception as e:
        logger.error("Error subiendo a GCS: %s", e, exc_info=True)
        raise RuntimeError(f"No se pudo subir el archivo: {e}") from e

    public_url = f"https://storage.googleapis.com/{settings.gcs_bucket_name}/{object_name}"
    logger.info("Archivo subido: %s (%d bytes)", public_url, len(content))
    return public_url
