"""GET /api/v1/practice/history (HU-10 / SUB-10-B): paginated practice history."""

import time
import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Category, Lesson, PracticeSession
from app.services import practice_service

URL = "/api/v1/practice/history"


@pytest.fixture
async def lesson(db_session: AsyncSession):
    cat = Category(id=uuid.uuid4(), name="Cat History", order=1)
    db_session.add(cat)
    await db_session.flush()
    row = Lesson(
        id=uuid.uuid4(),
        category_id=cat.id,
        title="Lesson history",
        description="desc",
        difficulty="principiante",
        tempo_bpm=80,
        order=0,
        is_active=True,
    )
    db_session.add(row)
    await db_session.commit()
    return row


def _session(user_id, lesson_id, *, score=80.0, created_at=None, ai_feedback=None):
    return PracticeSession(
        id=uuid.uuid4(),
        user_id=user_id,
        lesson_id=lesson_id,
        score=score,
        correct_notes=8,
        total_notes=10,
        wrong_notes=1,
        missed_notes=1,
        average_tempo=80,
        expected_tempo=80,
        tempo_accuracy=95.0,
        total_time_seconds=30.0,
        errors_detail=[],
        ai_feedback=ai_feedback,
        completed=True,
        created_at=created_at or datetime.now(UTC),
    )


async def _seed(db_session, user_id, lesson_id, count):
    base = datetime.now(UTC) - timedelta(days=count)
    db_session.add_all(
        [
            _session(user_id, lesson_id, score=float(i % 100), created_at=base + timedelta(hours=i))
            for i in range(count)
        ]
    )
    await db_session.commit()


class TestPracticeHistoryEndpoint:
    async def test_requires_authentication(self, client: AsyncClient):
        r = await client.get(URL)
        assert r.status_code in (401, 403)

    async def test_empty_history_returns_empty_page(self, client: AsyncClient, auth_headers: dict):
        r = await client.get(URL, headers=auth_headers)
        assert r.status_code == 200
        assert r.json() == {"items": [], "total": 0, "page": 1, "size": 20, "pages": 1}

    async def test_orders_by_created_at_desc_and_paginates(
        self, client, auth_headers, db_session, test_user, lesson
    ):
        await _seed(db_session, test_user.id, lesson.id, 25)

        first = (await client.get(URL, headers=auth_headers, params={"page": 1, "size": 10})).json()
        second = (
            await client.get(URL, headers=auth_headers, params={"page": 3, "size": 10})
        ).json()

        assert first["total"] == 25
        assert first["pages"] == 3
        assert first["size"] == 10
        assert len(first["items"]) == 10
        assert len(second["items"]) == 5
        dates = [i["created_at"] for i in first["items"]]
        assert dates == sorted(dates, reverse=True)
        assert first["items"][0]["lesson_title"] == "Lesson history"
        assert first["items"][0]["lesson_instrument"] == "quena"

    async def test_defaults_to_page_1_size_20(
        self, client, auth_headers, db_session, test_user, lesson
    ):
        await _seed(db_session, test_user.id, lesson.id, 30)
        body = (await client.get(URL, headers=auth_headers)).json()
        assert body["page"] == 1
        assert body["size"] == 20
        assert len(body["items"]) == 20

    async def test_only_returns_own_sessions(
        self, client, auth_headers, db_session, test_user, lesson
    ):
        from app.models.user import User

        other = User(
            id=uuid.uuid4(),
            email="other@example.com",
            username="other",
            full_name="Other",
            hashed_password="x",
            auth_provider="local",
            is_active=True,
            is_verified=True,
        )
        db_session.add(other)
        await db_session.commit()
        await _seed(db_session, other.id, lesson.id, 3)
        await _seed(db_session, test_user.id, lesson.id, 2)

        body = (await client.get(URL, headers=auth_headers)).json()
        assert body["total"] == 2
        assert {i["user_id"] for i in body["items"]} == {str(test_user.id)}

    @pytest.mark.parametrize(
        "params",
        [{"page": 0}, {"page": -1}, {"size": 101}, {"size": 0}],
    )
    async def test_invalid_params_return_422(self, client, auth_headers, params):
        r = await client.get(URL, headers=auth_headers, params=params)
        assert r.status_code == 422

    async def test_size_100_is_accepted(self, client, auth_headers):
        r = await client.get(URL, headers=auth_headers, params={"size": 100})
        assert r.status_code == 200

    async def test_ai_feedback_hidden_for_non_premium(
        self, client, auth_headers, db_session, test_user, lesson
    ):
        db_session.add(_session(test_user.id, lesson.id, ai_feedback="secret feedback"))
        await db_session.commit()
        body = (await client.get(URL, headers=auth_headers)).json()
        assert body["items"][0]["ai_feedback"] is None


class TestPracticeHistoryService:
    async def test_unit_with_mocked_session(self):
        """Unit: the service issues a count + a page query and maps rows."""
        user_id = uuid.uuid4()
        row = _session(user_id, uuid.uuid4(), score=70.0)
        row.lesson = None

        count_result = MagicMock()
        count_result.scalar.return_value = 41
        page_result = MagicMock()
        page_result.scalars.return_value.all.return_value = [row]
        db = MagicMock()
        db.execute = AsyncMock(side_effect=[count_result, page_result])

        out = await practice_service.get_practice_history(db, user_id, 2, 20)

        assert out["total"] == 41
        assert out["page"] == 2
        assert out["size"] == 20
        assert out["pages"] == 3
        assert [i["score"] for i in out["items"]] == [70.0]
        assert db.execute.await_count == 2

    async def test_legacy_signature_keeps_working(self, db_session, test_user, lesson):
        """The legacy /api/practice/history keeps lesson_id filtering."""
        await _seed(db_session, test_user.id, lesson.id, 3)
        out = await practice_service.get_practice_history(
            db_session, test_user.id, lesson_id=lesson.id, page=1, size=2
        )
        assert out["total"] == 3
        assert len(out["items"]) == 2


class TestPracticeHistoryLegacyEndpoint:
    async def test_legacy_endpoint_still_responds(
        self, client, auth_headers, db_session, test_user, lesson
    ):
        await _seed(db_session, test_user.id, lesson.id, 3)
        r = await client.get("/api/practice/history", headers=auth_headers, params={"limit": 2})
        assert r.status_code == 200
        body = r.json()
        assert body["total"] == 3
        assert len(body["items"]) == 2
        assert set(body) == {"items", "total", "page", "pages"}


class TestPracticeHistoryPerformance:
    async def test_1000_records_page_under_50ms(
        self, client, auth_headers, db_session, test_user, lesson
    ):
        """Integration: 1000 sessions, one page responds in < 50 ms.

        The suite runs on in-memory SQLite; the composite index
        (user_id, created_at DESC) is declared on the model so create_all builds it.
        """
        await _seed(db_session, test_user.id, lesson.id, 1000)
        await client.get(URL, headers=auth_headers)  # warm-up

        start = time.perf_counter()
        r = await client.get(URL, headers=auth_headers, params={"page": 5, "size": 20})
        elapsed_ms = (time.perf_counter() - start) * 1000

        assert r.status_code == 200
        assert r.json()["total"] == 1000
        assert elapsed_ms < 50, f"took {elapsed_ms:.1f} ms"

    async def test_composite_index_declared_on_model(self):
        from sqlalchemy.dialects import postgresql
        from sqlalchemy.schema import CreateIndex

        index = next(
            i
            for i in PracticeSession.__table__.indexes
            if i.name == "ix_practice_sessions_user_id_created_at"
        )
        ddl = str(CreateIndex(index).compile(dialect=postgresql.dialect()))
        assert "(user_id, created_at DESC)" in ddl
