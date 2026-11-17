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


V1_URL = "/api/v1/practice/session"


async def _user_xp(db_session: AsyncSession, user_id) -> int:
    from sqlalchemy import select

    from app.models.ranking import UserXP

    row = (
        await db_session.execute(select(UserXP).where(UserXP.user_id == user_id))
    ).scalar_one_or_none()
    return row.total_xp if row else 0


class TestPracticeSessionV1:
    """POST /api/v1/practice/session (HU-09 / SUB-09-B)."""

    async def test_first_submit_persists_and_awards_xp_and_streak(
        self,
        client: AsyncClient,
        auth_headers: dict,
        db_session: AsyncSession,
        test_user,
        one_lesson,
    ):
        r = await client.post(
            V1_URL,
            headers=auth_headers,
            json=_payload(str(one_lesson.id), str(uuid.uuid4())),
        )

        assert r.status_code == 200, r.text
        body = r.json()
        assert body["score"] == 90
        assert body["lesson_id"] == str(one_lesson.id)
        assert body["xp_earned"] > 0
        assert await _user_xp(db_session, test_user.id) == body["xp_earned"]

        from sqlalchemy import select

        from app.models.ranking import UserXP

        xp = (
            await db_session.execute(select(UserXP).where(UserXP.user_id == test_user.id))
        ).scalar_one()
        assert xp.current_streak == 1

    async def test_same_client_id_is_idempotent_no_duplicate_xp(
        self,
        client: AsyncClient,
        auth_headers: dict,
        db_session: AsyncSession,
        test_user,
        one_lesson,
    ):
        payload = _payload(str(one_lesson.id), str(uuid.uuid4()))

        r1 = await client.post(V1_URL, headers=auth_headers, json=payload)
        xp_after_first = await _user_xp(db_session, test_user.id)
        r2 = await client.post(V1_URL, headers=auth_headers, json=payload)

        assert r1.status_code == 200, r1.text
        assert r2.status_code == 200, r2.text
        assert r1.json()["id"] == r2.json()["id"]
        assert r1.json()["xp_earned"] > 0
        assert r2.json()["xp_earned"] == 0
        assert await _user_xp(db_session, test_user.id) == xp_after_first

    async def test_retry_after_lost_response_does_not_duplicate(
        self,
        client: AsyncClient,
        auth_headers: dict,
        db_session: AsyncSession,
        test_user,
        one_lesson,
    ):
        """The first response is 'lost' (client never reads it); retrying the
        same payload N times must still leave a single session and one XP grant."""
        payload = _payload(str(one_lesson.id), str(uuid.uuid4()))

        responses = [
            await client.post(V1_URL, headers=auth_headers, json=payload) for _ in range(3)
        ]

        assert {r.status_code for r in responses} == {200}
        assert len({r.json()["id"] for r in responses}) == 1
        assert [r.json()["xp_earned"] > 0 for r in responses] == [True, False, False]
        from sqlalchemy import func, select

        from app.models.lesson import PracticeSession

        count = (
            await db_session.execute(select(func.count()).select_from(PracticeSession))
        ).scalar()
        assert count == 1

    @pytest.mark.parametrize("score", [-0.1, 100.1, 101, -5])
    async def test_score_out_of_range_returns_422(
        self, client: AsyncClient, auth_headers: dict, one_lesson, score
    ):
        body = _payload(str(one_lesson.id), str(uuid.uuid4()))
        body["score"] = score
        r = await client.post(V1_URL, headers=auth_headers, json=body)
        assert r.status_code == 422, r.text

    async def test_missing_client_id_returns_422(
        self, client: AsyncClient, auth_headers: dict, one_lesson
    ):
        r = await client.post(V1_URL, headers=auth_headers, json=_payload(str(one_lesson.id), None))
        assert r.status_code == 422, r.text

    async def test_unknown_lesson_returns_404(self, client: AsyncClient, auth_headers: dict):
        r = await client.post(
            V1_URL,
            headers=auth_headers,
            json=_payload(str(uuid.uuid4()), str(uuid.uuid4())),
        )
        assert r.status_code == 404, r.text

    async def test_requires_authentication(self, client: AsyncClient, one_lesson):
        r = await client.post(V1_URL, json=_payload(str(one_lesson.id), str(uuid.uuid4())))
        assert r.status_code in (401, 403)

    async def test_race_on_unique_client_id_returns_existing_session(
        self,
        client: AsyncClient,
        auth_headers: dict,
        db_session: AsyncSession,
        one_lesson,
    ):
        """If two requests pass the pre-check at once, the unique index rejects
        the loser: it must get the winner's session, not a 500."""
        from app.services import practice_service

        payload = _payload(str(one_lesson.id), str(uuid.uuid4()))
        first = await client.post(V1_URL, headers=auth_headers, json=payload)
        real_lookup = practice_service.get_session_by_client_id
        calls = {"n": 0}

        async def blind_first_lookup(*args, **kwargs):
            calls["n"] += 1
            if calls["n"] == 1:
                return None  # simulates the pre-check losing the race
            return await real_lookup(*args, **kwargs)

        with patch.object(practice_service, "get_session_by_client_id", new=blind_first_lookup):
            second = await client.post(V1_URL, headers=auth_headers, json=payload)

        assert second.status_code == 200, second.text
        assert second.json()["id"] == first.json()["id"]
        assert second.json()["xp_earned"] == 0


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
