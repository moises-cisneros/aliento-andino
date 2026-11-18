"""Tests for lessons endpoints (HU-04, SUB-04-A)."""

import uuid

import pytest
from fastapi import HTTPException
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Category, Lesson, NoteSequence
from app.services.lesson_service import LessonService


@pytest.fixture
async def sample_category(db_session: AsyncSession) -> Category:
    """Fixture de categoría básica."""
    cat = Category(
        id=uuid.uuid4(),
        name="Escalas Andinas",
        description="Fundamentos de digitación y sonido",
        order=1,
        is_active=True,
    )
    db_session.add(cat)
    await db_session.commit()
    await db_session.refresh(cat)
    return cat


@pytest.fixture
async def sample_catalog(db_session: AsyncSession, sample_category: Category) -> dict[str, Lesson]:
    """Fixture con lecciones de Quena, Zampoña y Tarka en distintos niveles."""
    lessons: dict[str, Lesson] = {}

    quena_basic = Lesson(
        id=uuid.uuid4(),
        category_id=sample_category.id,
        title="Escala de Sol Mayor en Quena",
        description="Digitación fundamental para Quena",
        instrument="quena",
        difficulty="principiante",
        tempo_bpm=80,
        time_signature="4/4",
        key_signature="G",
        order=1,
        is_active=True,
    )
    db_session.add(quena_basic)

    # Notas para Quena
    notes_quena = [
        NoteSequence(
            id=uuid.uuid4(),
            lesson_id=quena_basic.id,
            position=1,
            note="G4",
            duration=1.0,
            is_rest=False,
            velocity=80,
        ),
        NoteSequence(
            id=uuid.uuid4(),
            lesson_id=quena_basic.id,
            position=2,
            note="A4",
            duration=1.0,
            is_rest=False,
            velocity=80,
        ),
        NoteSequence(
            id=uuid.uuid4(),
            lesson_id=quena_basic.id,
            position=3,
            note="B4",
            duration=1.0,
            is_rest=False,
            velocity=80,
        ),
    ]
    db_session.add_all(notes_quena)
    lessons["quena_basic"] = quena_basic

    zampona_inter = Lesson(
        id=uuid.uuid4(),
        category_id=sample_category.id,
        title="Melodía en Zampoña Ira y Arca",
        description="Alternancia de tubos y respiración",
        instrument="zampona",
        difficulty="intermedio",
        tempo_bpm=95,
        time_signature="4/4",
        key_signature="Em",
        order=2,
        is_active=True,
    )
    db_session.add(zampona_inter)
    lessons["zampona_inter"] = zampona_inter

    tarka_adv = Lesson(
        id=uuid.uuid4(),
        category_id=sample_category.id,
        title="Huayno Tradicional en Tarka",
        description="Ataque y control de sobretonos",
        instrument="tarka",
        difficulty="avanzado",
        tempo_bpm=110,
        time_signature="2/4",
        key_signature="C",
        order=3,
        is_active=True,
    )
    db_session.add(tarka_adv)
    lessons["tarka_adv"] = tarka_adv

    await db_session.commit()
    return lessons


class TestLessonsRequireAuth:
    """Lessons endpoints require authentication."""

    async def test_list_categories_no_auth(self, client: AsyncClient):
        response = await client.get("/api/lessons/categories")
        assert response.status_code in (401, 403)

    async def test_list_lessons_no_auth(self, client: AsyncClient):
        response = await client.get("/api/lessons")
        assert response.status_code in (401, 403)

    async def test_list_v1_lessons_no_auth(self, client: AsyncClient):
        response = await client.get("/api/v1/lessons")
        assert response.status_code in (401, 403)

    async def test_get_v1_lesson_detail_no_auth(self, client: AsyncClient):
        response = await client.get(f"/api/v1/lessons/{uuid.uuid4()}")
        assert response.status_code in (401, 403)


class TestListCategories:
    """Tests for GET /api/lessons/categories."""

    async def test_list_categories(self, client: AsyncClient, auth_headers: dict):
        response = await client.get("/api/lessons/categories", headers=auth_headers)
        assert response.status_code == 200
        assert isinstance(response.json(), list)


class TestListLessons:
    """Tests for GET /api/lessons (legacy endpoint)."""

    async def test_list_lessons(self, client: AsyncClient, auth_headers: dict):
        response = await client.get("/api/lessons", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "items" in data or isinstance(data, dict)

    async def test_list_lessons_pagination(self, client: AsyncClient, auth_headers: dict):
        response = await client.get(
            "/api/lessons",
            params={"page": 1, "limit": 5},
            headers=auth_headers,
        )
        assert response.status_code == 200

    async def test_list_lessons_filter_by_instrument(
        self, client: AsyncClient, auth_headers: dict, sample_catalog: dict[str, Lesson]
    ):
        response = await client.get(
            "/api/lessons",
            params={"instrument": "zampona"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        items = data.get("items", [])
        assert len(items) >= 1
        assert all(item["instrument"] == "zampona" for item in items)


class TestLessonServiceUnit:
    """Pruebas unitarias de la clase LessonService."""

    async def test_unit_get_lessons_filter_instrument(
        self, db_session: AsyncSession, sample_catalog: dict[str, Lesson]
    ):
        lessons = await LessonService.get_lessons(db=db_session, instrument="quena")
        assert len(lessons) >= 1
        assert all(l.instrument == "quena" for l in lessons)

    async def test_unit_get_lessons_filter_difficulty(
        self, db_session: AsyncSession, sample_catalog: dict[str, Lesson]
    ):
        lessons = await LessonService.get_lessons(db=db_session, difficulty="principiante")
        assert len(lessons) >= 1
        assert all(l.difficulty == "principiante" for l in lessons)

    async def test_unit_get_lessons_paginated_filter_instrument(
        self, db_session: AsyncSession, sample_catalog: dict[str, Lesson]
    ):
        from app.services.lesson_service import get_lessons_paginated

        res = await get_lessons_paginated(db=db_session, instrument="tarka")
        assert res["total"] >= 1
        assert all(item["instrument"] == "tarka" for item in res["items"])

    async def test_unit_get_lessons_invalid_instrument_raises_422(self, db_session: AsyncSession):
        with pytest.raises(HTTPException) as exc_info:
            await LessonService.get_lessons(db=db_session, instrument="charango")
        assert exc_info.value.status_code == 422
        assert "Instrumento inválido" in exc_info.value.detail

    async def test_unit_get_lessons_invalid_difficulty_raises_422(self, db_session: AsyncSession):
        with pytest.raises(HTTPException) as exc_info:
            await LessonService.get_lessons(db=db_session, difficulty="maestro")
        assert exc_info.value.status_code == 422
        assert "Dificultad inválida" in exc_info.value.detail

    async def test_unit_get_lesson_by_id_success(
        self, db_session: AsyncSession, sample_catalog: dict[str, Lesson]
    ):
        lesson_id = sample_catalog["quena_basic"].id
        result = await LessonService.get_lesson_by_id(db=db_session, lesson_id=lesson_id)
        assert result.id == lesson_id
        assert result.title == "Escala de Sol Mayor en Quena"
        assert result.instrument == "quena"
        assert len(result.notes) == 3
        assert [n.note for n in result.notes] == ["G4", "A4", "B4"]

    async def test_unit_get_lesson_by_id_not_found_raises_404(self, db_session: AsyncSession):
        with pytest.raises(HTTPException) as exc_info:
            await LessonService.get_lesson_by_id(db=db_session, lesson_id=uuid.uuid4())
        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "Lección no encontrada"


class TestLessonsV1ApiIntegration:
    """Pruebas de integración HTTP asíncrona para /api/v1/lessons."""

    async def test_integration_filter_instrument_and_difficulty(
        self, client: AsyncClient, auth_headers: dict, sample_catalog: dict[str, Lesson]
    ):
        response = await client.get(
            "/api/v1/lessons",
            params={"instrument": "quena", "difficulty": "principiante"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1
        item = data[0]
        assert item["instrument"] == "quena"
        assert item["difficulty"] == "principiante"
        assert item["title"] == "Escala de Sol Mayor en Quena"

    async def test_integration_filter_all_supported_instruments(
        self, client: AsyncClient, auth_headers: dict, sample_catalog: dict[str, Lesson]
    ):
        # Zampona
        res_zamp = await client.get(
            "/api/v1/lessons",
            params={"instrument": "zampona"},
            headers=auth_headers,
        )
        assert res_zamp.status_code == 200
        data_zamp = res_zamp.json()
        assert any(l["instrument"] == "zampona" for l in data_zamp)

        # Tarka
        res_tarka = await client.get(
            "/api/v1/lessons",
            params={"instrument": "tarka"},
            headers=auth_headers,
        )
        assert res_tarka.status_code == 200
        data_tarka = res_tarka.json()
        assert any(l["instrument"] == "tarka" for l in data_tarka)

    async def test_integration_invalid_instrument_returns_422(
        self, client: AsyncClient, auth_headers: dict
    ):
        response = await client.get(
            "/api/v1/lessons",
            params={"instrument": "guitar"},
            headers=auth_headers,
        )
        assert response.status_code == 422
        assert "Instrumento inválido" in response.json()["detail"]

    async def test_integration_invalid_difficulty_returns_422(
        self, client: AsyncClient, auth_headers: dict
    ):
        response = await client.get(
            "/api/v1/lessons",
            params={"difficulty": "imposible"},
            headers=auth_headers,
        )
        assert response.status_code == 422
        assert "Dificultad inválida" in response.json()["detail"]

    async def test_integration_get_lesson_with_notes_sequence(
        self, client: AsyncClient, auth_headers: dict, sample_catalog: dict[str, Lesson]
    ):
        lesson_id = str(sample_catalog["quena_basic"].id)
        response = await client.get(f"/api/v1/lessons/{lesson_id}", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == lesson_id
        assert data["instrument"] == "quena"
        assert len(data["notes"]) == 3
        positions = [n["position"] for n in data["notes"]]
        assert positions == [1, 2, 3]

    async def test_integration_get_lesson_not_found_returns_404(
        self, client: AsyncClient, auth_headers: dict
    ):
        random_id = str(uuid.uuid4())
        response = await client.get(f"/api/v1/lessons/{random_id}", headers=auth_headers)
        assert response.status_code == 404
        assert response.json()["detail"] == "Lección no encontrada"


class TestLessonsV1E2E:
    """Flujo E2E completo: consulta de catálogo filtrado hasta detalle de lección."""

    async def test_e2e_catalog_to_lesson_detail_flow(
        self, client: AsyncClient, auth_headers: dict, sample_catalog: dict[str, Lesson]
    ):
        # 1. Explorar catálogo de lecciones para Quena nivel principiante
        catalog_res = await client.get(
            "/api/v1/lessons",
            params={"instrument": "quena", "difficulty": "principiante", "skip": 0, "limit": 10},
            headers=auth_headers,
        )
        assert catalog_res.status_code == 200
        catalog = catalog_res.json()
        assert len(catalog) >= 1

        chosen_lesson = catalog[0]
        chosen_id = chosen_lesson["id"]
        assert chosen_lesson["instrument"] == "quena"

        # 2. Consultar el reproductor / detalle de la lección seleccionada
        detail_res = await client.get(f"/api/v1/lessons/{chosen_id}", headers=auth_headers)
        assert detail_res.status_code == 200
        detail = detail_res.json()

        # 3. Validar consistencia relacional y serialización de notas
        assert detail["id"] == chosen_id
        assert detail["title"] == chosen_lesson["title"]
        assert detail["instrument"] == "quena"
        assert isinstance(detail["notes"], list)
        assert len(detail["notes"]) == chosen_lesson["notes_count"]
        assert detail["notes"][0]["note"] == "G4"


class TestLessonsV1AdminCrud:
    """Pruebas para endpoints administrativos de creación y edición (HU-05, SUB-05-A)."""

    async def test_create_v1_lesson_as_admin_with_notes(
        self, client: AsyncClient, admin_headers: dict, sample_category: Category
    ):
        payload = {
            "title": "Virgenes del Sol - Quena Avanzada",
            "description": "Estudio de digitaciones y velocidad en Quena.",
            "instrument": "quena",
            "category_id": str(sample_category.id),
            "difficulty": "avanzado",
            "tempo_bpm": 110,
            "time_signature": "4/4",
            "key_signature": "Am",
            "genre": "Danza Andina",
            "artist": "Jorge Bravo de Rueda",
            "notes": [
                {
                    "position": 1,
                    "note": "A4",
                    "duration": 0.5,
                    "is_rest": False,
                    "velocity": 90,
                },
                {
                    "position": 2,
                    "note": "C5",
                    "duration": 0.5,
                    "is_rest": False,
                    "velocity": 90,
                },
                {
                    "position": 3,
                    "note": "REST",
                    "duration": 1.0,
                    "is_rest": True,
                    "velocity": 0,
                },
            ],
        }

        response = await client.post("/api/v1/lessons", json=payload, headers=admin_headers)
        assert response.status_code == 201
        data = response.json()
        assert data["title"] == "Virgenes del Sol - Quena Avanzada"
        assert data["instrument"] == "quena"
        assert len(data["notes"]) == 3
        assert data["notes"][0]["note"] == "A4"
        assert data["notes"][2]["is_rest"] is True

    async def test_create_v1_lesson_as_non_admin_fails_403(
        self, client: AsyncClient, auth_headers: dict, sample_category: Category
    ):
        payload = {
            "title": "Lección No Autorizada",
            "description": "Intento de creación por usuario normal.",
            "instrument": "tarka",
            "category_id": str(sample_category.id),
            "difficulty": "principiante",
            "tempo_bpm": 80,
            "notes": [],
        }

        response = await client.post("/api/v1/lessons", json=payload, headers=auth_headers)
        assert response.status_code == 403

    async def test_update_v1_lesson_as_admin(
        self,
        client: AsyncClient,
        admin_headers: dict,
        sample_catalog: dict[str, Lesson],
    ):
        lesson_id = str(sample_catalog["quena_basic"].id)
        update_payload = {
            "title": "Escala de Sol Mayor en Quena (Revisada)",
            "tempo_bpm": 95,
        }

        response = await client.put(
            f"/api/v1/lessons/{lesson_id}",
            json=update_payload,
            headers=admin_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Escala de Sol Mayor en Quena (Revisada)"
        assert data["tempo_bpm"] == 95

    async def test_update_v1_lesson_with_new_notes(
        self,
        client: AsyncClient,
        admin_headers: dict,
        sample_catalog: dict[str, Lesson],
    ):
        lesson_id = str(sample_catalog["quena_basic"].id)
        update_payload = {
            "notes": [
                {
                    "position": 1,
                    "note": "D5",
                    "duration": 2.0,
                    "is_rest": False,
                }
            ]
        }

        response = await client.put(
            f"/api/v1/lessons/{lesson_id}",
            json=update_payload,
            headers=admin_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["notes"]) == 1
        assert data["notes"][0]["note"] == "D5"

    async def test_update_v1_lesson_not_found_returns_404(
        self, client: AsyncClient, admin_headers: dict
    ):
        random_id = str(uuid.uuid4())
        response = await client.put(
            f"/api/v1/lessons/{random_id}",
            json={"title": "No existe"},
            headers=admin_headers,
        )
        assert response.status_code == 404


class TestAndeanCurricularCatalog:
    """Verificación del catálogo curricular pedagógico andino (HU #142)."""

    def test_catalog_structure_and_andean_distribution(self):
        from seed_lessons import (
            CATEGORIES,
            get_embocadura_lessons,
            get_escalas_lessons,
            get_melodias_lessons,
            get_ritmos_lessons,
        )

        dummy_cat_id = uuid.uuid4()
        dummy_admin = uuid.uuid4()

        cat_names = [c["name"] for c in CATEGORIES]
        assert cat_names == [
            "Embocadura y Sonido",
            "Escalas Andinas",
            "Melodías Tradicionales",
            "Ritmos y Huaynos",
        ]

        all_lessons = (
            get_embocadura_lessons(dummy_cat_id, dummy_admin)
            + get_escalas_lessons(dummy_cat_id, dummy_admin)
            + get_melodias_lessons(dummy_cat_id, dummy_admin)
            + get_ritmos_lessons(dummy_cat_id, dummy_admin)
        )

        assert len(all_lessons) == 36

        # Distribución equitativa: 12 por instrumento
        quena_lessons = [l for l in all_lessons if l["lesson"]["instrument"] == "quena"]
        zampona_lessons = [l for l in all_lessons if l["lesson"]["instrument"] == "zampona"]
        tarka_lessons = [l for l in all_lessons if l["lesson"]["instrument"] == "tarka"]

        assert len(quena_lessons) == 12
        assert len(zampona_lessons) == 12
        assert len(tarka_lessons) == 12

        # Todas las notas deben ser monofónicas (sin acordes de piano)
        for l_item in all_lessons:
            assert len(l_item["notes"]) >= 4
            for n in l_item["notes"]:
                assert n["is_chord"] is False
                assert n["chord_group"] is None
                assert isinstance(n["note"], str)
                assert n["duration"] > 0

        # Temas requeridos en Quena
        quena_titles = {l["lesson"]["title"] for l in quena_lessons}
        assert "El Cóndor Pasa (Tema Principal)" in quena_titles
        assert "Ojos Azules (Melodía Tradicional)" in quena_titles
        assert "Valicha (Huayno Cusqueño)" in quena_titles
        assert "Vírgenes del Sol (Fox Incaico)" in quena_titles
        assert "Primeros Soplos en Quena (Sol4 y La4)" in quena_titles
        assert "Claridad de Embocadura (Si4 y Do5)" in quena_titles

        # Temas requeridos en Zampoña
        zampona_titles = {l["lesson"]["title"] for l in zampona_lessons}
        assert "Kantu de Charazani (Melodía Ancestral)" in zampona_titles
        assert "Sikuriada de Italaque (Melodía de Siku)" in zampona_titles
        assert "Poco a Poco (Huayno en Siku)" in zampona_titles
        assert "Flor de Retama (Huayno en Zampoña)" in zampona_titles
        assert "Alternancia Básica Ira (6) y Arca (7)" in zampona_titles

        # Temas requeridos en Tarka
        tarka_titles = {l["lesson"]["title"] for l in tarka_lessons}
        assert "Emisión de la Tara (Timbre Rasposo)" in tarka_titles
        assert "Escala de Carnaval de 6 Orificios en Tarka" in tarka_titles
        assert "Carnaval de Anata (Melodía Central)" in tarka_titles
