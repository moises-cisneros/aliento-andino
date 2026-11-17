"""Router para uploads de media (imágenes/videos de posts, avatares)."""

import logging

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from pydantic import BaseModel

from app.dependencies.auth import get_current_user
from app.models.user import User
from app.services import storage_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/uploads", tags=["Uploads"])


class UploadResponse(BaseModel):
    url: str


@router.post(
    "/media",
    response_model=UploadResponse,
    summary="Subir imagen o video a Cloud Storage",
)
async def upload_media(
    file: UploadFile = File(...),
    folder: str = "posts",
    current_user: User = Depends(get_current_user),
):
    """Subir un archivo y obtener su URL pública.

    Tipos permitidos: jpeg, png, webp, mp4, mov, webm.
    Tamaños: imagen ≤ 10MB, video ≤ 50MB.
    """
    if folder not in {"posts", "avatars", "lessons"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="folder inválido (permitidos: posts, avatars, lessons)",
        )

    if folder == "lessons" and not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo admins pueden subir a la carpeta lessons",
        )

    content = await file.read()

    try:
        url = await storage_service.upload_media(
            content=content,
            content_type=file.content_type or "application/octet-stream",
            original_filename=file.filename or "upload.bin",
            folder=folder,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except RuntimeError as e:
        logger.error("Upload falló: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al subir el archivo",
        )

    return UploadResponse(url=url)
