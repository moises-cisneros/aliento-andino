"""Router de administración de lecciones y categorías (requiere is_admin)."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin
from app.models.user import User
from app.schemas.lesson import (
    AdminStatsOverview,
    CategoryCreate,
    CategoryResponse,
    CategoryUpdate,
    LessonCreate,
    LessonResponse,
    LessonUpdate,
    LessonWithNotes,
    NoteSequenceResponse,
    NotesUpdateRequest,
    PaginatedResponse,
)
from app.services import lesson_service, practice_service

router = APIRouter(prefix="/api/admin", tags=["Admin - Lecciones"])


# ===================== CATEGORÍAS =====================


@router.post("/categories", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
async def create_category(
    data: CategoryCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """Crear nueva categoría."""
    category = await lesson_service.create_category(db, data)
    return category


@router.put("/categories/{category_id}", response_model=CategoryResponse)
async def update_category(
    category_id: uuid.UUID,
    data: CategoryUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """Editar categoría existente."""
    category = await lesson_service.get_category_by_id(db, category_id)
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoría no encontrada",
        )
    return await lesson_service.update_category(db, category, data)


@router.delete("/categories/{category_id}", response_model=CategoryResponse)
async def delete_category(
    category_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """Soft delete: desactivar categoría."""
    category = await lesson_service.get_category_by_id(db, category_id)
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoría no encontrada",
        )
    return await lesson_service.soft_delete_category(db, category)


# ===================== LECCIONES =====================


@router.get("/lessons", response_model=PaginatedResponse)
async def list_admin_lessons(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    category_id: uuid.UUID | None = Query(None),
    difficulty: str | None = Query(None),
    search: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """Lista todas las lecciones para admin (incluyendo inactivas)."""
    return await lesson_service.get_admin_lessons_paginated(
        db,
        page=page,
        limit=limit,
        category_id=category_id,
        difficulty=difficulty,
        search=search,
    )


@router.get("/lessons/{lesson_id}", response_model=LessonWithNotes)
async def get_admin_lesson(
    lesson_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """Obtener detalle de una lección para admin (incluye inactivas)."""
    detail = await lesson_service.get_lesson_detail(db, lesson_id)
    if not detail:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lección no encontrada",
        )
    return detail


@router.post("/lessons", response_model=LessonWithNotes, status_code=status.HTTP_201_CREATED)
async def create_lesson(
    data: LessonCreate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Crear lección con su secuencia de notas."""
    # Verificar que la categoría existe
    category = await lesson_service.get_category_by_id(db, data.category_id)
    if not category:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La categoría especificada no existe",
        )

    try:
        lesson = await lesson_service.create_lesson(db, data, admin.id)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    # Recargar con relaciones
    detail = await lesson_service.get_lesson_detail(db, lesson.id)
    return detail


@router.put("/lessons/{lesson_id}", response_model=LessonResponse)
async def update_lesson(
    lesson_id: uuid.UUID,
    data: LessonUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """Editar datos de lección (sin notas)."""
    lesson = await lesson_service.get_lesson_by_id(db, lesson_id)
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lección no encontrada",
        )
    return await lesson_service.update_lesson(db, lesson, data)


@router.put("/lessons/{lesson_id}/notes", response_model=list[NoteSequenceResponse])
async def update_lesson_notes(
    lesson_id: uuid.UUID,
    data: NotesUpdateRequest,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """Reemplazar toda la secuencia de notas de una lección."""
    lesson = await lesson_service.get_lesson_by_id(db, lesson_id)
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lección no encontrada",
        )

    try:
        new_notes = await lesson_service.replace_lesson_notes(db, lesson_id, data.notes)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    return new_notes


@router.delete("/lessons/{lesson_id}", response_model=LessonResponse)
async def delete_lesson(
    lesson_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """Soft delete: desactivar lección."""
    lesson = await lesson_service.get_lesson_by_id(db, lesson_id)
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lección no encontrada",
        )
    return await lesson_service.soft_delete_lesson(db, lesson)


# ===================== STATS ADMIN =====================


@router.get("/stats/overview", response_model=AdminStatsOverview)
async def get_admin_stats(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """Estadísticas para el dashboard admin."""
    return await practice_service.get_admin_stats_overview(db)
