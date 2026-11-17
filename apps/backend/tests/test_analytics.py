"""[SUB-21-A] Analítica pedagógica por instrumento: servicio puro y endpoints."""

import uuid

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Category, Lesson, PracticeSession
from app.models.user import User
from app.services import analytics_service as svc

# --------------------------------------------------------------------------- #
# Unitarias: cálculo matemático puro (medias de precisión y percentiles)       #
# --------------------------------------------------------------------------- #


class TestAnalyticsService:
    def test_note_precision(self):
        assert svc.note_precision(9, 10) == 0.9
        assert svc.note_precision(0, 0) == 0.0  # sin notas no divide por cero
        assert svc.note_precision(5, 5) == 1.0

    def test_summarize_instrument_promedia_y_calcula_finalizacion(self):
        samples = [
            svc.SessionSample("quena", "L1", 80.0, 8, 10, 0.9, True),
            svc.SessionSample("quena", "L1", 100.0, 10, 10, 1.0, False),
        ]
        out = svc.summarize_instrument(samples)
        assert out["sessions"] == 2
        assert out["avg_score"] == 90.0
        assert out["avg_note_precision"] == 0.9  # (0.8 + 1.0) / 2
        assert out["avg_tempo_accuracy"] == 0.95
        assert out["completion_rate"] == 0.5  # 1 de 2 completadas

    def test_summarize_instrument_vacio_no_lanza(self):
        out = svc.summarize_instrument([])
        assert out == {
            "sessions": 0,
            "avg_score": 0.0,
            "avg_note_precision": 0.0,
            "avg_tempo_accuracy": 0.0,
            "completion_rate": 0.0,
        }

    def test_lesson_dropoff_ordena_por_mayor_desercion(self):
        samples = [
            # L1: 2 intentos, 1 completado -> dropoff 0.5
            svc.SessionSample("quena", "L1", 70.0, 7, 10, 0.8, True),
            svc.SessionSample("quena", "L1", 60.0, 6, 10, 0.7, False),
            # L2: 2 intentos, 0 completados -> dropoff 1.0
            svc.SessionSample("quena", "L2", 50.0, 5, 10, 0.6, False),
            svc.SessionSample("quena", "L2", 40.0, 4, 10, 0.5, False),
        ]
        out = svc.lesson_dropoff(samples)
        assert [r["lesson_id"] for r in out] == ["L2", "L1"]  # mayor deserción primero
        assert out[0]["dropoff_rate"] == 1.0
        assert out[1]["dropoff_rate"] == 0.5

    def test_percentile(self):
        values = [10.0, 20.0, 30.0, 40.0]
        assert svc.percentile(values, 0) == 10.0
        assert svc.percentile(values, 100) == 40.0
        assert svc.percentile(values, 50) == 25.0  # interpolación lineal
        assert svc.percentile([], 50) == 0.0


# --------------------------------------------------------------------------- #
# Helpers de siembra para las pruebas de integración                           #
# --------------------------------------------------------------------------- #


async def _seed(db: AsyncSession, user: User) -> dict:
    cat = Category(id=uuid.uuid4(), name="Escalas Analytics")
    db.add(cat)
    quena = Lesson(
        id=uuid.uuid4(),
        category_id=cat.id,
        title="Quena · Escala",
        description="d",
        instrument="quena",
        difficulty="principiante",
        tempo_bpm=80,
    )
    zampona = Lesson(
        id=uuid.uuid4(),
        category_id=cat.id,
        title="Zampoña · Diálogo",
        description="d",
        instrument="zampona",
        difficulty="principiante",
        tempo_bpm=90,
    )
    db.add_all([quena, zampona])

    def session(lesson_id, score, correct, completed):
        return PracticeSession(
            user_id=user.id,
            lesson_id=lesson_id,
            score=score,
            correct_notes=correct,
            total_notes=10,
            wrong_notes=10 - correct,
            missed_notes=0,
            average_tempo=80.0,
            expected_tempo=80,
            tempo_accuracy=0.9,
            total_time_seconds=60.0,
            completed=completed,
        )

    db.add_all(
        [
            session(quena.id, 90.0, 9, True),
            session(quena.id, 50.0, 5, False),
            session(zampona.id, 80.0, 8, True),
        ]
    )
    await db.commit()
    return {"quena": quena.id, "zampona": zampona.id}


# --------------------------------------------------------------------------- #
# Integración: endpoints con datos agregados y rol administrador               #
# --------------------------------------------------------------------------- #


class TestInstrumentMetricsEndpoint:
    async def test_agrega_metricas_por_instrumento(
        self, client: AsyncClient, admin_headers: dict, db_session: AsyncSession, test_user: User
    ):
        await _seed(db_session, test_user)

        resp = await client.get("/api/v1/analytics/instruments", headers=admin_headers)
        assert resp.status_code == 200, resp.text
        data = {row["instrument"]: row for row in resp.json()}

        assert data["quena"]["sessions"] == 2
        assert data["quena"]["completion_rate"] == 0.5
        assert data["quena"]["avg_note_precision"] == 0.7  # (0.9 + 0.5) / 2
        assert data["zampona"]["sessions"] == 1
        assert data["zampona"]["completion_rate"] == 1.0

    async def test_filtro_por_instrumento(
        self, client: AsyncClient, admin_headers: dict, db_session: AsyncSession, test_user: User
    ):
        await _seed(db_session, test_user)

        resp = await client.get(
            "/api/v1/analytics/instruments",
            headers=admin_headers,
            params={"instrument": "quena"},
        )
        assert resp.status_code == 200
        instruments = [row["instrument"] for row in resp.json()]
        assert instruments == ["quena"]

    async def test_sin_datos_devuelve_lista_vacia_200(
        self, client: AsyncClient, admin_headers: dict
    ):
        resp = await client.get(
            "/api/v1/analytics/instruments",
            headers=admin_headers,
            params={"instrument": "tarka"},
        )
        assert resp.status_code == 200
        assert resp.json() == []

    async def test_requiere_rol_administrador(self, client: AsyncClient, auth_headers: dict):
        resp = await client.get("/api/v1/analytics/instruments", headers=auth_headers)
        assert resp.status_code in (401, 403)


class TestLessonDropoffEndpoint:
    async def test_desercion_por_leccion(
        self, client: AsyncClient, admin_headers: dict, db_session: AsyncSession, test_user: User
    ):
        await _seed(db_session, test_user)

        resp = await client.get(
            "/api/v1/analytics/lessons/dropoff",
            headers=admin_headers,
            params={"instrument": "quena"},
        )
        assert resp.status_code == 200, resp.text
        rows = resp.json()
        assert len(rows) == 1
        assert rows[0]["attempts"] == 2
        assert rows[0]["completed"] == 1
        assert rows[0]["dropoff_rate"] == 0.5
        assert rows[0]["title"] == "Quena · Escala"
