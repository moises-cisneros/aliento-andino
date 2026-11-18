"""Tests para el catálogo oficial de digitaciones por instrumento andino (HU-05, SUB-05-B)."""

import uuid

import pytest
from httpx import AsyncClient
from pydantic import ValidationError

from app.schemas.fingering import FingeringCreate


class TestFingeringSchemaUnit:
    """Pruebas unitarias de validación del esquema Pydantic FingeringCreate."""

    def test_valid_quena_fingering_schema(self):
        data = FingeringCreate(
            instrument="quena",
            note="G",
            octave=4,
            holes_covered=[True, True, True, True, True, True, True],
            is_alternate=False,
            description="Sol4 fundamental con todos los orificios cubiertos",
        )
        assert data.instrument == "quena"
        assert len(data.holes_covered) == 7
        assert data.is_alternate is False

    def test_invalid_quena_holes_count_raises_validation_error(self):
        with pytest.raises(ValidationError) as exc:
            FingeringCreate(
                instrument="quena",
                note="A",
                octave=4,
                holes_covered=[True, True, True, True],  # solo 4 orificios en vez de 7
            )
        assert "exactamente 7 elementos" in str(exc.value)

    def test_valid_tarka_fingering_schema(self):
        data = FingeringCreate(
            instrument="tarka",
            note="C",
            octave=5,
            holes_covered=[True, True, True, True, True, True],
            is_alternate=False,
        )
        assert data.instrument == "tarka"
        assert len(data.holes_covered) == 6

    def test_invalid_tarka_holes_count_raises_validation_error(self):
        with pytest.raises(ValidationError) as exc:
            FingeringCreate(
                instrument="tarka",
                note="D",
                octave=5,
                holes_covered=[True, True, True],  # 3 en vez de 6
            )
        assert "exactamente 6 elementos" in str(exc.value)

    def test_invalid_instrument_raises_validation_error(self):
        with pytest.raises(ValidationError) as exc:
            FingeringCreate(
                instrument="charango",
                note="E",
                octave=4,
                holes_covered=[True, True, True, True, True, True],
            )
        assert "instrument debe ser uno de" in str(exc.value)

    def test_empty_holes_covered_raises_validation_error(self):
        with pytest.raises(ValidationError) as exc:
            FingeringCreate(
                instrument="quena",
                note="G",
                octave=4,
                holes_covered=[],
            )
        assert "holes_covered" in str(exc.value)


class TestFingeringApiIntegration:
    """Pruebas de integración de endpoints REST /api/v1/fingerings."""

    async def test_create_fingering_as_admin_returns_201(
        self, client: AsyncClient, admin_headers: dict
    ):
        payload = {
            "instrument": "quena",
            "note": "G",
            "octave": 4,
            "holes_covered": [True, True, True, True, True, True, True],
            "is_alternate": False,
            "description": "Digitación estándar de Sol4",
        }

        response = await client.post("/api/v1/fingerings", json=payload, headers=admin_headers)
        assert response.status_code == 201
        data = response.json()
        assert data["instrument"] == "quena"
        assert data["note"] == "G"
        assert data["octave"] == 4
        assert data["is_alternate"] is False
        assert len(data["holes_covered"]) == 7
        assert "id" in data

    async def test_create_fingering_as_non_admin_returns_403(
        self, client: AsyncClient, auth_headers: dict
    ):
        payload = {
            "instrument": "quena",
            "note": "A",
            "octave": 4,
            "holes_covered": [True, True, True, True, True, True, False],
            "is_alternate": False,
        }

        response = await client.post("/api/v1/fingerings", json=payload, headers=auth_headers)
        assert response.status_code == 403

    async def test_duplicate_primary_fingering_returns_409_conflict(
        self, client: AsyncClient, admin_headers: dict
    ):
        payload = {
            "instrument": "quena",
            "note": "A",
            "octave": 4,
            "holes_covered": [True, True, True, True, True, True, False],
            "is_alternate": False,
            "description": "Digitación principal La4",
        }

        # Primer registro exitoso
        res1 = await client.post("/api/v1/fingerings", json=payload, headers=admin_headers)
        assert res1.status_code == 201

        # Segundo registro idéntico con is_alternate=False debe fallar con 409
        res2 = await client.post("/api/v1/fingerings", json=payload, headers=admin_headers)
        assert res2.status_code == 409
        assert res2.json()["detail"] == "Digitación principal ya registrada para esta nota"

    async def test_alternate_fingering_allowed_for_same_note(
        self, client: AsyncClient, admin_headers: dict
    ):
        base_payload = {
            "instrument": "tarka",
            "note": "C",
            "octave": 5,
            "holes_covered": [True, True, True, True, True, True],
            "is_alternate": False,
        }
        res_main = await client.post("/api/v1/fingerings", json=base_payload, headers=admin_headers)
        assert res_main.status_code == 201

        # Digitación alterna permitida para la misma nota e instrumento
        alt_payload = {
            "instrument": "tarka",
            "note": "C",
            "octave": 5,
            "holes_covered": [True, True, True, True, True, False],
            "is_alternate": True,
            "description": "Digitación alterna con medio orificio",
        }
        res_alt = await client.post("/api/v1/fingerings", json=alt_payload, headers=admin_headers)
        assert res_alt.status_code == 201
        data = res_alt.json()
        assert data["is_alternate"] is True

    async def test_list_fingerings_and_filter_by_instrument(
        self, client: AsyncClient, admin_headers: dict, auth_headers: dict
    ):
        # Crear digitación de Quena
        await client.post(
            "/api/v1/fingerings",
            json={
                "instrument": "quena",
                "note": "D",
                "octave": 5,
                "holes_covered": [True, True, True, False, False, False, False],
                "is_alternate": False,
            },
            headers=admin_headers,
        )

        # Crear digitación de Zampoña
        await client.post(
            "/api/v1/fingerings",
            json={
                "instrument": "zampona",
                "note": "G",
                "octave": 4,
                "holes_covered": ["ira", 1],
                "is_alternate": False,
            },
            headers=admin_headers,
        )

        # Listar todas
        res_all = await client.get("/api/v1/fingerings", headers=auth_headers)
        assert res_all.status_code == 200
        all_items = res_all.json()
        assert len(all_items) >= 2

        # Filtrar por Quena
        res_quena = await client.get("/api/v1/fingerings?instrument=quena", headers=auth_headers)
        assert res_quena.status_code == 200
        quena_items = res_quena.json()
        assert all(f["instrument"] == "quena" for f in quena_items)

    async def test_delete_fingering_as_admin(self, client: AsyncClient, admin_headers: dict):
        create_res = await client.post(
            "/api/v1/fingerings",
            json={
                "instrument": "quena",
                "note": "F#",
                "octave": 5,
                "holes_covered": [True, False, False, False, False, False, False],
                "is_alternate": False,
            },
            headers=admin_headers,
        )
        assert create_res.status_code == 201
        fingering_id = create_res.json()["id"]

        del_res = await client.delete(f"/api/v1/fingerings/{fingering_id}", headers=admin_headers)
        assert del_res.status_code == 200
        assert del_res.json()["message"] == "Digitación eliminada exitosamente"

        # Borrar ID inexistente retorna 404
        del_again = await client.delete(f"/api/v1/fingerings/{uuid.uuid4()}", headers=admin_headers)
        assert del_again.status_code == 404


class TestFingeringSeederAndRelationships:
    """Pruebas para el semillero oficial de digitaciones andinas y relaciones."""

    async def test_seed_fingerings_is_idempotent_and_covers_all_instruments(self, db_session):
        from sqlalchemy import select

        from app.models.fingering import Fingering
        from seed_fingerings import seed_fingerings

        # 1. Primera ejecución: insertar
        inserted, _ = await seed_fingerings(db_session)
        assert inserted >= 30

        # Verificar presencia de los 3 instrumentos andinos
        res = await db_session.execute(select(Fingering))
        all_fingerings = res.scalars().all()
        instruments = {f.instrument for f in all_fingerings}
        assert instruments == {"quena", "zampona", "tarka"}

        # 2. Segunda ejecución: idempotencia
        inserted_again, skipped = await seed_fingerings(db_session)
        assert inserted_again == 0
        assert skipped == len(all_fingerings)

    async def test_note_sequence_fingering_relationship_and_breath_mark(self, db_session):
        from app.models.fingering import Fingering
        from app.models.lesson import Category, Lesson, NoteSequence

        category = Category(name="Prueba Vientos", description="Categoría temporal", order=1)
        db_session.add(category)
        await db_session.flush()

        fingering = Fingering(
            instrument="quena",
            note="G",
            octave=4,
            holes_covered=[True, True, True, True, True, True, True],
            description="Sol4 fundamental",
        )
        db_session.add(fingering)
        await db_session.flush()

        lesson = Lesson(
            category_id=category.id,
            title="Prueba de Digitaciones y Respiración",
            description="Lección de prueba",
            instrument="quena",
            difficulty="principiante",
            tempo_bpm=80,
            time_signature="4/4",
            key_signature="G",
            order=1,
            is_active=True,
        )
        db_session.add(lesson)
        await db_session.flush()

        note_seq = NoteSequence(
            lesson_id=lesson.id,
            position=1,
            note="G4",
            duration=1.0,
            is_rest=False,
            breath_mark=True,
            velocity=85,
            fingering_id=fingering.id,
            fingering_data={"holes": [True] * 7},
        )
        db_session.add(note_seq)
        await db_session.commit()

        # Verificar persistencia y relaciones
        await db_session.refresh(note_seq)
        assert note_seq.breath_mark is True
        assert note_seq.fingering_id == fingering.id
        assert note_seq.fingering is not None
        assert note_seq.fingering.note == "G"
        assert note_seq.fingering_data == {"holes": [True] * 7}
