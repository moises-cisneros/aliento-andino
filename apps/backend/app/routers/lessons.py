"""Router público de lecciones: explorar categorías y lecciones."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies.auth import get_current_admin, get_current_user
from app.models.user import User
from app.schemas.lesson import (
    CategoryWithCount,
    LessonCreate,
    LessonListItem,
    LessonUpdate,
    LessonWithNotes,
    NoteSequenceResponse,
    PaginatedResponse,
)
from app.services import lesson_service

router = APIRouter(tags=["Lecciones"])


# ===================== API V1 (HU-04) =====================


@router.get("/api/v1/lessons", response_model=list[LessonListItem])
async def get_v1_lessons(
    instrument: str | None = Query(
        None, description="Filtro por instrumento andino (quena, zampona, tarka)"
    ),
    difficulty: str | None = Query(
        None, description="Filtro por dificultad (principiante, intermedio, avanzado)"
    ),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[LessonListItem]:
    """Lista lecciones filtradas por instrumento andino y nivel de dificultad."""
    return await lesson_service.LessonService.get_lessons(
        db=db,
        instrument=instrument,
        difficulty=difficulty,
        skip=skip,
        limit=limit,
        user_id=current_user.id,
    )


@router.get("/api/v1/lessons/{lesson_id}", response_model=LessonWithNotes)
async def get_v1_lesson_detail(
    lesson_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LessonWithNotes:
    """Detalle de una lección andina con su secuencia de notas serializadas."""
    return await lesson_service.LessonService.get_lesson_by_id(
        db=db,
        lesson_id=lesson_id,
        user_id=current_user.id,
    )


@router.post("/api/v1/lessons", response_model=LessonWithNotes, status_code=status.HTTP_201_CREATED)
async def create_v1_lesson(
    data: LessonCreate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
) -> LessonWithNotes:
    """Crear nueva lección andina con su secuencia de notas (requiere rol admin)."""
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
    detail = await lesson_service.get_lesson_detail(db, lesson.id)
    if not detail:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al recuperar la lección creada",
        )
    return detail


@router.put("/api/v1/lessons/{lesson_id}", response_model=LessonWithNotes)
async def update_v1_lesson(
    lesson_id: uuid.UUID,
    data: LessonUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
) -> LessonWithNotes:
    """Actualizar lección andina y opcionalmente reemplazar su secuencia de notas (requiere rol admin)."""
    lesson = await lesson_service.get_lesson_by_id(db, lesson_id)
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lección no encontrada",
        )
    await lesson_service.update_lesson(db, lesson, data)
    if data.notes is not None:
        try:
            await lesson_service.replace_lesson_notes(db, lesson_id, data.notes)
            db.expire(lesson)
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(e),
            )
    detail = await lesson_service.get_lesson_detail(db, lesson_id)
    if not detail:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lección no encontrada",
        )
    return detail


# ===================== LEGACY API (/api/lessons) =====================


@router.get("/api/lessons/categories", response_model=list[CategoryWithCount])
async def list_categories(
    db: AsyncSession = Depends(get_db),
    _current_user: User = Depends(get_current_user),
):
    """Lista todas las categorías activas con conteo de lecciones."""
    return await lesson_service.get_categories_with_count(db)


@router.get("/api/lessons/genres", response_model=list[str])
async def list_genres(
    db: AsyncSession = Depends(get_db),
    _current_user: User = Depends(get_current_user),
):
    """Lista los géneros musicales disponibles (para filtrar el catálogo)."""
    return await lesson_service.get_genres(db)


@router.get("/api/lessons", response_model=PaginatedResponse)
async def list_lessons(
    category_id: uuid.UUID | None = Query(None),
    difficulty: str | None = Query(None),
    genre: str | None = Query(None),
    search: str | None = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista lecciones con filtros, paginación y mejor score del usuario."""
    return await lesson_service.get_lessons_paginated(
        db,
        page=page,
        limit=limit,
        category_id=category_id,
        difficulty=difficulty,
        genre=genre,
        search=search,
        user_id=current_user.id,
    )


@router.get("/api/lessons/recommended", response_model=list[LessonListItem])
async def list_recommended(
    limit: int = Query(6, ge=1, le=20),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lecciones recomendadas según el skill_level del usuario."""
    return await lesson_service.get_recommended_lessons(
        db,
        user_id=current_user.id,
        skill_level=current_user.skill_level,
        limit=limit,
        is_premium=current_user.is_premium,
    )


@router.get("/api/lessons/{lesson_id}", response_model=LessonWithNotes)
async def get_lesson_detail(
    lesson_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Detalle de una lección con secuencia de notas y progreso del usuario."""
    detail = await lesson_service.get_lesson_detail(db, lesson_id, user_id=current_user.id)
    if not detail:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lección no encontrada",
        )
    return detail


@router.get("/api/lessons/{lesson_id}/sequence", response_model=list[NoteSequenceResponse])
async def get_lesson_sequence(
    lesson_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener solo la secuencia de notas (endpoint ligero para práctica).

    Gating: las lecciones premium (no-principiante) requieren suscripción.
    """
    lesson = await lesson_service.get_lesson_by_id(db, lesson_id)
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lección no encontrada",
        )
    if lesson_service.lesson_requires_premium(lesson) and not current_user.is_premium:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Esta lección es premium. Suscribite para practicarla.",
        )
    return await lesson_service.get_lesson_sequence(db, lesson_id)
