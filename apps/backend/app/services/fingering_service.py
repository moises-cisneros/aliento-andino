"""Servicio de lógica de negocio para catálogo de digitaciones andinas (HU-05, SUB-05-B)."""

import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.fingering import Fingering
from app.schemas.fingering import FingeringCreate


class FingeringService:
    """Gestor de catálogo oficial de digitaciones para Quena, Zampoña y Tarka."""

    @staticmethod
    async def get_fingerings(db: AsyncSession, instrument: str | None = None) -> list[Fingering]:
        """Obtiene todas las digitaciones registradas, opcionalmente filtradas por instrumento."""
        query = select(Fingering)
        if instrument:
            query = query.where(Fingering.instrument == instrument.strip().lower())
        query = query.order_by(
            Fingering.instrument, Fingering.octave, Fingering.note, Fingering.is_alternate
        )
        result = await db.execute(query)
        return list(result.scalars().all())

    @staticmethod
    async def get_fingering_by_id(db: AsyncSession, fingering_id: uuid.UUID) -> Fingering | None:
        """Obtiene una digitación específica por su ID."""
        result = await db.execute(select(Fingering).where(Fingering.id == fingering_id))
        return result.scalars().first()

    @staticmethod
    async def create_fingering(db: AsyncSession, data: FingeringCreate) -> Fingering:
        """Crea una digitación con validación estricta de unicidad para digitaciones principales.

        RF-04 / HU-31: No pueden existir dos digitaciones principales (is_alternate=False)
        para la misma nota e instrumento.
        """
        normalized_inst = data.instrument.strip().lower()
        normalized_note = data.note.strip().upper()

        if not data.is_alternate:
            existing = await db.execute(
                select(Fingering).where(
                    Fingering.instrument == normalized_inst,
                    Fingering.note == normalized_note,
                    Fingering.octave == data.octave,
                    Fingering.is_alternate.is_(False),
                )
            )
            if existing.scalars().first() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Digitación principal ya registrada para esta nota",
                )

        fingering = Fingering(
            instrument=normalized_inst,
            note=normalized_note,
            octave=data.octave,
            holes_covered=data.holes_covered,
            is_alternate=data.is_alternate,
            description=data.description,
        )
        db.add(fingering)
        await db.commit()
        await db.refresh(fingering)
        return fingering

    @staticmethod
    async def delete_fingering(db: AsyncSession, fingering_id: uuid.UUID) -> bool:
        """Elimina una digitación por ID."""
        fingering = await FingeringService.get_fingering_by_id(db, fingering_id)
        if not fingering:
            return False
        await db.delete(fingering)
        await db.commit()
        return True
