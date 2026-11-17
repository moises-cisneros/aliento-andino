"""Router para catálogo de digitaciones oficiales por instrumento andino (HU-05, SUB-05-B)."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin, get_current_user
from app.models.user import User
from app.schemas.fingering import FingeringCreate, FingeringResponse
from app.services.fingering_service import FingeringService

router = APIRouter(prefix="/api/v1/fingerings", tags=["Digitaciones Andinas"])


@router.get("", response_model=list[FingeringResponse])
async def list_fingerings(
    instrument: str | None = Query(
        None, description="Filtrar por instrumento andino: quena, zampona, tarka"
    ),
    db: AsyncSession = Depends(get_db),
    _current_user: User = Depends(get_current_user),
) -> list[FingeringResponse]:
    """Lista el catálogo oficial de digitaciones por instrumento."""
    return await FingeringService.get_fingerings(db=db, instrument=instrument)


@router.post("", response_model=FingeringResponse, status_code=status.HTTP_201_CREATED)
async def create_fingering(
    data: FingeringCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
) -> FingeringResponse:
    """Registra una nueva digitación andina en el catálogo oficial (requiere rol admin)."""
    return await FingeringService.create_fingering(db=db, data=data)


@router.delete("/{fingering_id}", status_code=status.HTTP_200_OK)
async def delete_fingering(
    fingering_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
) -> dict[str, str]:
    """Elimina una digitación del catálogo oficial (requiere rol admin)."""
    deleted = await FingeringService.delete_fingering(db=db, fingering_id=fingering_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Digitación no encontrada",
        )
    return {"message": "Digitación eliminada exitosamente"}
