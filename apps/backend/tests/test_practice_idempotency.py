"""Idempotencia de /practice/submit: reenviar con el mismo client_id (sync
offline) no duplica la sesión ni vuelve a otorgar XP."""

import uuid
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Category, Lesson


@pytest.fixture
async def one_lesson(db_session: AsyncSession):
    cat = Category(id=uuid.uuid4(), name="Cat Idem", order=1)
    db_session.add(cat)
    await db_session.flush()
    lesson = Lesson(
        id=uuid.uuid4(),
        category_id=cat.id,
        title="Lección idem",
        description="desc",
        difficulty="principiante",
        tempo_bpm=80,
        order=0,
        is_active=True,
    )
    db_session.add(lesson)
    await db_session.commit()
    return lesson


def _payload(lesson_id: str, client_id: str | None) -> dict:
    body = {
        "lesson_id": lesson_id,
        "score": 90,
        "correct_notes": 9,
        "total_notes": 10,
        "wrong_notes": 1,
        "missed_notes": 0,
        "average_tempo": 80,
        "total_time_seconds": 30,
        "errors_detail": [],
        "completed": True,
    }
    if client_id is not None:
        body["client_id"] = client_id
    return body


class TestPracticeIdempotency:
    async def test_same_client_id_returns_same_session_and_no_extra_xp(
        self, client: AsyncClient, auth_headers: dict, one_lesson
    ):
        from app.routers import practice as practice_router

        cid = str(uuid.uuid4())
        payload = _payload(str(one_lesson.id), cid)

        with patch.object(
            practice_router.gemini_service,
            "generate_practice_feedback",
            new=AsyncMock(return_value=None),
        ):
            r1 = await client.post("/api/practice/submit", headers=auth_headers, json=payload)
            r2 = await client.post("/api/practice/submit", headers=auth_headers, json=payload)

        assert r1.status_code == 200, r1.text
        assert r2.status_code == 200, r2.text

        # El reintento devuelve LA MISMA sesión (no se creó una nueva)...
        assert r1.json()["session"]["id"] == r2.json()["session"]["id"]
        # ...y el primero otorgó XP pero el reintento no.
        assert r1.json()["xp_earned"] > 0
        assert r2.json()["xp_earned"] == 0

    async def test_submit_without_client_id_still_works(
        self, client: AsyncClient, auth_headers: dict, one_lesson
    ):
        from app.routers import practice as practice_router

        with patch.object(
            practice_router.gemini_service,
            "generate_practice_feedback",
            new=AsyncMock(return_value=None),
        ):
            r = await client.post(
                "/api/practice/submit",
                headers=auth_headers,
                json=_payload(str(one_lesson.id), None),
            )
        assert r.status_code == 200, r.text
