"""Servicio de lógica de negocio para lecciones y categorías."""

import math
import uuid

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.lesson import Category, Lesson, NoteSequence
from app.schemas.lesson import (
    CategoryCreate,
    CategoryUpdate,
    LessonCreate,
    LessonListItem,
    LessonUpdate,
    LessonWithNotes,
    NoteSequenceCreate,
    NoteSequenceResponse,
)

# ===================== CATEGORÍAS =====================


async def get_categories(db: AsyncSession, include_inactive: bool = False) -> list[Category]:
    """Obtener todas las categorías ordenadas por campo 'order'."""
    query = select(Category).order_by(Category.order)
    if not include_inactive:
        query = query.where(Category.is_active == True)  # noqa: E712
    result = await db.execute(query)
    return list(result.scalars().all())


async def get_categories_with_count(db: AsyncSession) -> list[dict]:
    """Obtener categorías activas con conteo de lecciones activas."""
    query = (
        select(
            Category,
            func.count(Lesson.id).label("lessons_count"),
        )
        .outerjoin(Lesson, (Lesson.category_id == Category.id) & (Lesson.is_active == True))  # noqa: E712
        .where(Category.is_active == True)  # noqa: E712
        .group_by(Category.id)
        .order_by(Category.order)
    )
    result = await db.execute(query)
    rows = result.all()
    categories = []
    for cat, count in rows:
        categories.append(
            {
                "id": cat.id,
                "name": cat.name,
                "description": cat.description,
                "icon": cat.icon,
                "order": cat.order,
                "lessons_count": count,
            }
        )
    return categories


async def get_category_by_id(db: AsyncSession, category_id: uuid.UUID) -> Category | None:
    """Obtener categoría por ID."""
    result = await db.execute(select(Category).where(Category.id == category_id))
    return result.scalar_one_or_none()


async def create_category(db: AsyncSession, data: CategoryCreate) -> Category:
    """Crear nueva categoría."""
    category = Category(**data.model_dump())
    db.add(category)
    await db.flush()
    await db.refresh(category)
    return category


async def update_category(db: AsyncSession, category: Category, data: CategoryUpdate) -> Category:
    """Actualizar categoría existente."""
    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(category, field, value)
    await db.flush()
    await db.refresh(category)
    return category


async def soft_delete_category(db: AsyncSession, category: Category) -> Category:
    """Soft delete: desactivar categoría."""
    category.is_active = False
    await db.flush()
    await db.refresh(category)
    return category


# ===================== LECCIONES =====================

# Suscripción: niveles GRATIS. El resto (intermedio/avanzado/experto) es premium.
FREE_DIFFICULTIES = {"principiante"}


def lesson_requires_premium(lesson: Lesson) -> bool:
    """True si la lección exige suscripción premium (nivel no-principiante o
    marcada explícitamente como premium)."""
    return bool(lesson.is_premium) or ((lesson.difficulty or "").lower() not in FREE_DIFFICULTIES)


async def get_genres(db: AsyncSession) -> list[str]:
    """Géneros distintos presentes en lecciones activas (orden alfabético)."""
    result = await db.execute(
        select(Lesson.genre)
        .where(Lesson.genre.isnot(None), Lesson.is_active == True)  # noqa: E712
        .distinct()
        .order_by(Lesson.genre)
    )
    return [g for (g,) in result.all() if g]


async def get_lessons_paginated(
    db: AsyncSession,
    page: int = 1,
    limit: int = 20,
    category_id: uuid.UUID | None = None,
    difficulty: str | None = None,
    genre: str | None = None,
    search: str | None = None,
    user_id: uuid.UUID | None = None,
    include_inactive: bool = False,
) -> dict:
    """Obtener lecciones paginadas con filtros."""
    from app.models.lesson import PracticeSession

    query = select(Lesson).options(selectinload(Lesson.category))

    if not include_inactive:
        query = query.where(Lesson.is_active == True)  # noqa: E712
    if category_id:
        query = query.where(Lesson.category_id == category_id)
    if difficulty:
        query = query.where(Lesson.difficulty == difficulty)
    if genre:
        query = query.where(Lesson.genre == genre)
    if search:
        search_term = f"%{search}%"
        query = query.where(
            (Lesson.title.ilike(search_term)) | (Lesson.description.ilike(search_term))
        )

    # Contar total
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Paginación
    pages = max(1, math.ceil(total / limit))
    offset = (page - 1) * limit
    query = query.order_by(Lesson.order, Lesson.created_at).offset(offset).limit(limit)

    result = await db.execute(query)
    lessons = list(result.scalars().all())

    # Mejor score del usuario para TODAS las lecciones de la página en una sola
    # query (evita el N+1 de consultar score por cada lección dentro del loop).
    best_scores: dict[uuid.UUID, float] = {}
    if user_id and lessons:
        lesson_ids = [lesson.id for lesson in lessons]
        best_q = (
            select(PracticeSession.lesson_id, func.max(PracticeSession.score))
            .where(
                PracticeSession.user_id == user_id,
                PracticeSession.lesson_id.in_(lesson_ids),
            )
            .group_by(PracticeSession.lesson_id)
        )
        best_result = await db.execute(best_q)
        best_scores = dict(best_result.all())

    items = []
    for lesson in lessons:
        items.append(
            {
                "id": lesson.id,
                "category_id": lesson.category_id,
                "title": lesson.title,
                "description": lesson.description,
                "difficulty": lesson.difficulty,
                "tempo_bpm": lesson.tempo_bpm,
                "time_signature": lesson.time_signature,
                "key_signature": lesson.key_signature,
                "genre": lesson.genre,
                "artist": lesson.artist,
                "thumbnail_url": lesson.thumbnail_url,
                "audio_preview_url": lesson.audio_preview_url,
                "duration_seconds": lesson.duration_seconds,
                "order": lesson.order,
                "is_active": lesson.is_active,
                "is_premium": lesson.is_premium,
                "total_plays": lesson.total_plays,
                "average_score": lesson.average_score,
                "created_by": lesson.created_by,
                "created_at": lesson.created_at,
                "updated_at": lesson.updated_at,
                "category_name": lesson.category.name if lesson.category else None,
                "notes_count": len(lesson.notes) if lesson.notes else 0,
                "user_best_score": best_scores.get(lesson.id),
                "requires_premium": lesson_requires_premium(lesson),
            }
        )

    return {"items": items, "total": total, "page": page, "pages": pages}


# Mapeo skill_level (auto-declarado en onboarding) → difficulty (campo en Lesson).
SKILL_LEVEL_TO_DIFFICULTY = {
    "beginner": "principiante",
    "intermediate": "intermedio",
    "advanced": "avanzado",
}


async def get_recommended_lessons(
    db: AsyncSession,
    user_id: uuid.UUID,
    skill_level: str | None,
    limit: int = 6,
    is_premium: bool = False,
) -> list[dict]:
    """Recomendaciones personalizadas que COMPLEMENTAN la ruta de aprendizaje.

    A diferencia de la ruta (próximo paso secuencial), esto sugiere en qué
    enfocarse, priorizando:
      1. Reforzar lecciones intentadas con bajo puntaje (<70%), peor primero.
      2. Algo nuevo de tu nivel declarado.
      3. Explorar lecciones nuevas populares.
      4. Repasar lo intentado entre 70-89%.
    Excluye lo ya dominado (>=90%). Devuelve el mejor puntaje del usuario.
    """
    from app.models.lesson import PracticeSession

    # Mejor puntaje del usuario por lección.
    score_rows = (
        await db.execute(
            select(PracticeSession.lesson_id, func.max(PracticeSession.score))
            .where(PracticeSession.user_id == user_id)
            .group_by(PracticeSession.lesson_id)
        )
    ).all()
    best_by_lesson: dict[uuid.UUID, float] = {lid: float(score) for lid, score in score_rows}

    lessons = list(
        (
            await db.execute(
                select(Lesson)
                .options(selectinload(Lesson.category))
                .where(Lesson.is_active == True)  # noqa: E712
            )
        )
        .scalars()
        .all()
    )

    target_diff = SKILL_LEVEL_TO_DIFFICULTY.get(skill_level or "")

    def rank(lesson: Lesson):
        best = best_by_lesson.get(lesson.id)
        attempted = best is not None
        if attempted and best >= 90:
            return None  # ya dominada → no recomendar
        if attempted and best < 70:
            return (0, best)  # reforzar (peor puntaje primero)
        if not attempted and target_diff and lesson.difficulty == target_diff:
            return (1, -lesson.total_plays)  # nuevo de tu nivel
        if not attempted:
            return (2, -lesson.total_plays)  # explorar nuevo
        return (3, -lesson.total_plays)  # repasar (70-89%)

    ranked = []
    for lesson in lessons:
        # No recomendar contenido premium a usuarios sin suscripción: no podrían
        # abrirlo. Los usuarios premium ven todo.
        if not is_premium and lesson_requires_premium(lesson):
            continue
        r = rank(lesson)
        if r is not None:
            ranked.append((r, lesson))
    ranked.sort(key=lambda x: x[0])
    chosen = [lesson for _, lesson in ranked[:limit]]

    items = []
    for lesson in chosen:
        items.append(
            {
                "id": lesson.id,
                "category_id": lesson.category_id,
                "title": lesson.title,
                "description": lesson.description,
                "difficulty": lesson.difficulty,
                "tempo_bpm": lesson.tempo_bpm,
                "time_signature": lesson.time_signature,
                "key_signature": lesson.key_signature,
                "genre": lesson.genre,
                "artist": lesson.artist,
                "thumbnail_url": lesson.thumbnail_url,
                "audio_preview_url": lesson.audio_preview_url,
                "duration_seconds": lesson.duration_seconds,
                "order": lesson.order,
                "is_active": lesson.is_active,
                "is_premium": lesson.is_premium,
                "total_plays": lesson.total_plays,
                "average_score": lesson.average_score,
                "created_by": lesson.created_by,
                "created_at": lesson.created_at,
                "updated_at": lesson.updated_at,
                "category_name": lesson.category.name if lesson.category else None,
                "notes_count": 0,  # liviano
                "user_best_score": best_by_lesson.get(lesson.id),
                "requires_premium": lesson_requires_premium(lesson),
            }
        )

    return items


async def get_lesson_by_id(db: AsyncSession, lesson_id: uuid.UUID) -> Lesson | None:
    """Obtener lección por ID con notas y categoría."""
    result = await db.execute(
        select(Lesson)
        .options(
            selectinload(Lesson.notes),
            selectinload(Lesson.category),
        )
        .where(Lesson.id == lesson_id)
    )
    return result.scalar_one_or_none()


async def get_lesson_detail(
    db: AsyncSession, lesson_id: uuid.UUID, user_id: uuid.UUID | None = None
) -> dict | None:
    """Obtener detalle de lección con notas y progreso del usuario."""
    from app.models.lesson import PracticeSession

    lesson = await get_lesson_by_id(db, lesson_id)
    if not lesson:
        return None

    detail = {
        "id": lesson.id,
        "category_id": lesson.category_id,
        "title": lesson.title,
        "description": lesson.description,
        "difficulty": lesson.difficulty,
        "tempo_bpm": lesson.tempo_bpm,
        "time_signature": lesson.time_signature,
        "key_signature": lesson.key_signature,
        "thumbnail_url": lesson.thumbnail_url,
        "audio_preview_url": lesson.audio_preview_url,
        "duration_seconds": lesson.duration_seconds,
        "order": lesson.order,
        "is_active": lesson.is_active,
        "is_premium": lesson.is_premium,
        "total_plays": lesson.total_plays,
        "average_score": lesson.average_score,
        "created_by": lesson.created_by,
        "created_at": lesson.created_at,
        "updated_at": lesson.updated_at,
        "category_name": lesson.category.name if lesson.category else None,
        "creator_name": lesson.creator.full_name if lesson.creator else None,
        "notes": lesson.notes,
        "user_best_score": None,
        "user_attempts": 0,
    }

    if user_id:
        # Mejor score
        best_q = select(func.max(PracticeSession.score)).where(
            PracticeSession.user_id == user_id,
            PracticeSession.lesson_id == lesson_id,
        )
        best_result = await db.execute(best_q)
        detail["user_best_score"] = best_result.scalar()

        # Cantidad de intentos
        count_q = select(func.count()).where(
            PracticeSession.user_id == user_id,
            PracticeSession.lesson_id == lesson_id,
        )
        count_result = await db.execute(count_q)
        detail["user_attempts"] = count_result.scalar() or 0

    return detail


async def get_lesson_sequence(db: AsyncSession, lesson_id: uuid.UUID) -> list[NoteSequence]:
    """Obtener solo la secuencia de notas de una lección (endpoint ligero)."""
    result = await db.execute(
        select(NoteSequence)
        .where(NoteSequence.lesson_id == lesson_id)
        .order_by(NoteSequence.position)
    )
    return list(result.scalars().all())


async def create_lesson(db: AsyncSession, data: LessonCreate, admin_id: uuid.UUID) -> Lesson:
    """Crear lección con su secuencia de notas."""
    # Validar positions consecutivas
    if data.notes:
        positions = [n.position for n in data.notes]
        expected = list(range(1, len(data.notes) + 1))
        if sorted(positions) != expected:
            raise ValueError("Las posiciones de las notas deben ser consecutivas empezando en 1")

    lesson = Lesson(
        category_id=data.category_id,
        title=data.title,
        description=data.description,
        difficulty=data.difficulty,
        tempo_bpm=data.tempo_bpm,
        time_signature=data.time_signature,
        key_signature=data.key_signature,
        thumbnail_url=data.thumbnail_url,
        audio_preview_url=data.audio_preview_url,
        duration_seconds=data.duration_seconds,
        is_premium=data.is_premium,
        order=data.order,
        created_by=admin_id,
    )
    db.add(lesson)
    await db.flush()

    # Crear notas
    for note_data in data.notes:
        note = NoteSequence(lesson_id=lesson.id, **note_data.model_dump())
        db.add(note)

    await db.flush()
    await db.refresh(lesson)
    return lesson


async def update_lesson(db: AsyncSession, lesson: Lesson, data: LessonUpdate) -> Lesson:
    """Actualizar datos de lección (sin notas)."""
    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(lesson, field, value)
    await db.flush()
    await db.refresh(lesson)
    return lesson


async def replace_lesson_notes(
    db: AsyncSession, lesson_id: uuid.UUID, notes: list[NoteSequenceCreate]
) -> list[NoteSequence]:
    """Reemplazar toda la secuencia de notas de una lección."""
    # Validar positions consecutivas
    if notes:
        positions = [n.position for n in notes]
        expected = list(range(1, len(notes) + 1))
        if sorted(positions) != expected:
            raise ValueError("Las posiciones de las notas deben ser consecutivas empezando en 1")

    # Eliminar notas existentes
    existing = await db.execute(select(NoteSequence).where(NoteSequence.lesson_id == lesson_id))
    for note in existing.scalars().all():
        await db.delete(note)

    # Crear nuevas notas
    new_notes = []
    for note_data in notes:
        note = NoteSequence(lesson_id=lesson_id, **note_data.model_dump())
        db.add(note)
        new_notes.append(note)

    await db.flush()
    return new_notes


async def soft_delete_lesson(db: AsyncSession, lesson: Lesson) -> Lesson:
    """Soft delete: desactivar lección."""
    lesson.is_active = False
    await db.flush()
    await db.refresh(lesson)
    return lesson


async def get_admin_lessons_paginated(
    db: AsyncSession,
    page: int = 1,
    limit: int = 20,
    category_id: uuid.UUID | None = None,
    difficulty: str | None = None,
    search: str | None = None,
) -> dict:
    """Obtener todas las lecciones para admin (incluyendo inactivas)."""
    query = select(Lesson).options(
        selectinload(Lesson.category),
        selectinload(Lesson.notes),
    )

    if category_id:
        query = query.where(Lesson.category_id == category_id)
    if difficulty:
        query = query.where(Lesson.difficulty == difficulty)
    if search:
        search_term = f"%{search}%"
        query = query.where(
            (Lesson.title.ilike(search_term)) | (Lesson.description.ilike(search_term))
        )

    # Contar total
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    pages = max(1, math.ceil(total / limit))
    offset = (page - 1) * limit
    query = query.order_by(Lesson.order, Lesson.created_at).offset(offset).limit(limit)

    result = await db.execute(query)
    lessons = list(result.scalars().all())

    items = []
    for lesson in lessons:
        items.append(
            {
                "id": lesson.id,
                "category_id": lesson.category_id,
                "title": lesson.title,
                "description": lesson.description,
                "difficulty": lesson.difficulty,
                "tempo_bpm": lesson.tempo_bpm,
                "time_signature": lesson.time_signature,
                "key_signature": lesson.key_signature,
                "genre": lesson.genre,
                "artist": lesson.artist,
                "thumbnail_url": lesson.thumbnail_url,
                "audio_preview_url": lesson.audio_preview_url,
                "duration_seconds": lesson.duration_seconds,
                "order": lesson.order,
                "is_active": lesson.is_active,
                "is_premium": lesson.is_premium,
                "total_plays": lesson.total_plays,
                "average_score": lesson.average_score,
                "created_by": lesson.created_by,
                "created_at": lesson.created_at,
                "updated_at": lesson.updated_at,
                "category_name": lesson.category.name if lesson.category else None,
                "notes_count": len(lesson.notes) if lesson.notes else 0,
                "creator_name": lesson.creator.full_name if lesson.creator else None,
            }
        )

    return {"items": items, "total": total, "page": page, "pages": pages}


# ===================== SERVICIO DE LECCIONES ANDINAS (HU-04) =====================

SUPPORTED_INSTRUMENTS = {"quena", "zampona", "tarka"}
SUPPORTED_DIFFICULTIES = {"principiante", "intermedio", "avanzado"}


class LessonService:
    """Servicio de catálogo y reproducción interactiva de lecciones andinas."""

    @staticmethod
    async def get_lessons(
        db: AsyncSession,
        instrument: str | None = None,
        difficulty: str | None = None,
        skip: int = 0,
        limit: int = 20,
        user_id: uuid.UUID | None = None,
    ) -> list[LessonListItem]:
        """Obtiene lecciones activas filtradas por instrumento andino y dificultad."""
        if instrument is not None:
            inst = instrument.strip().lower()
            if inst not in SUPPORTED_INSTRUMENTS:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Instrumento inválido: '{instrument}'. Valores permitidos: quena, zampona, tarka",
                )
        else:
            inst = None

        if difficulty is not None:
            diff = difficulty.strip().lower()
            if diff not in SUPPORTED_DIFFICULTIES:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Dificultad inválida: '{difficulty}'. Valores permitidos: principiante, intermedio, avanzado",
                )
        else:
            diff = None

        query = (
            select(Lesson)
            .options(
                selectinload(Lesson.category),
                selectinload(Lesson.notes),
            )
            .where(Lesson.is_active == True)  # noqa: E712
        )

        if inst:
            query = query.where(func.lower(Lesson.instrument) == inst)
        if diff:
            query = query.where(func.lower(Lesson.difficulty) == diff)

        query = query.order_by(Lesson.order, Lesson.created_at).offset(skip).limit(limit)
        result = await db.execute(query)
        lessons = list(result.scalars().all())

        best_scores: dict[uuid.UUID, float] = {}
        if user_id and lessons:
            from app.models.lesson import PracticeSession

            lesson_ids = [lesson.id for lesson in lessons]
            best_q = (
                select(PracticeSession.lesson_id, func.max(PracticeSession.score))
                .where(
                    PracticeSession.user_id == user_id,
                    PracticeSession.lesson_id.in_(lesson_ids),
                )
                .group_by(PracticeSession.lesson_id)
            )
            best_result = await db.execute(best_q)
            best_scores = dict(best_result.all())

        items: list[LessonListItem] = []
        for lesson in lessons:
            items.append(
                LessonListItem(
                    id=lesson.id,
                    category_id=lesson.category_id,
                    title=lesson.title,
                    description=lesson.description,
                    instrument=lesson.instrument,
                    difficulty=lesson.difficulty,
                    tempo_bpm=lesson.tempo_bpm,
                    time_signature=lesson.time_signature,
                    key_signature=lesson.key_signature,
                    genre=lesson.genre,
                    artist=lesson.artist,
                    thumbnail_url=lesson.thumbnail_url,
                    audio_preview_url=lesson.audio_preview_url,
                    duration_seconds=lesson.duration_seconds,
                    order=lesson.order,
                    is_active=lesson.is_active,
                    is_premium=lesson.is_premium,
                    total_plays=lesson.total_plays,
                    average_score=lesson.average_score,
                    created_by=lesson.created_by,
                    created_at=lesson.created_at,
                    updated_at=lesson.updated_at,
                    category_name=lesson.category.name if lesson.category else None,
                    notes_count=len(lesson.notes) if lesson.notes else 0,
                    user_best_score=best_scores.get(lesson.id),
                    requires_premium=lesson_requires_premium(lesson),
                )
            )
        return items

    @staticmethod
    async def get_lesson_by_id(
        db: AsyncSession,
        lesson_id: uuid.UUID,
        user_id: uuid.UUID | None = None,
    ) -> LessonWithNotes:
        """Obtiene una lección por ID con su secuencia completa de notas serializadas."""
        query = (
            select(Lesson)
            .options(
                selectinload(Lesson.category),
                selectinload(Lesson.notes),
                selectinload(Lesson.creator),
            )
            .where(Lesson.id == lesson_id)
        )
        result = await db.execute(query)
        lesson = result.scalar_one_or_none()
        if not lesson:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Lección no encontrada",
            )

        user_best_score = None
        user_attempts = 0
        if user_id:
            from app.models.lesson import PracticeSession

            best_q = select(func.max(PracticeSession.score)).where(
                PracticeSession.user_id == user_id,
                PracticeSession.lesson_id == lesson_id,
            )
            best_res = await db.execute(best_q)
            user_best_score = best_res.scalar()

            attempts_q = select(func.count(PracticeSession.id)).where(
                PracticeSession.user_id == user_id,
                PracticeSession.lesson_id == lesson_id,
            )
            attempts_res = await db.execute(attempts_q)
            user_attempts = attempts_res.scalar() or 0

        note_responses = [
            NoteSequenceResponse(
                id=n.id,
                position=n.position,
                note=n.note,
                duration=n.duration,
                is_rest=n.is_rest,
                finger=n.finger,
                hand=n.hand,
                velocity=n.velocity,
                is_chord=n.is_chord,
                chord_group=n.chord_group,
            )
            for n in (lesson.notes or [])
        ]

        return LessonWithNotes(
            id=lesson.id,
            category_id=lesson.category_id,
            title=lesson.title,
            description=lesson.description,
            instrument=lesson.instrument,
            difficulty=lesson.difficulty,
            tempo_bpm=lesson.tempo_bpm,
            time_signature=lesson.time_signature,
            key_signature=lesson.key_signature,
            genre=lesson.genre,
            artist=lesson.artist,
            thumbnail_url=lesson.thumbnail_url,
            audio_preview_url=lesson.audio_preview_url,
            duration_seconds=lesson.duration_seconds,
            order=lesson.order,
            is_active=lesson.is_active,
            is_premium=lesson.is_premium,
            total_plays=lesson.total_plays,
            average_score=lesson.average_score,
            created_by=lesson.created_by,
            created_at=lesson.created_at,
            updated_at=lesson.updated_at,
            category_name=lesson.category.name if lesson.category else None,
            creator_name=lesson.creator.full_name if lesson.creator else None,
            notes=note_responses,
            user_best_score=user_best_score,
            user_attempts=user_attempts,
        )
