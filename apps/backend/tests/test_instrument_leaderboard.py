"""[SUB-12-A] Leaderboard por instrumento: servicio (posiciones, empates), 50 usuarios y REST."""

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Category, Lesson, PracticeSession
from app.models.user import User
from app.services import ranking_service as svc
from app.utils.security import hash_password

pytestmark = pytest.mark.asyncio


def _user(n: int) -> User:
    return User(
        id=uuid.uuid4(),
        email=f"lb{n}@example.com",
        username=f"lbuser{n}",
        full_name=f"LB User {n}",
        hashed_password=hash_password("TestPass123"),
        auth_provider="local",
        is_active=True,
        is_verified=True,
    )


def _session(user_id, lesson_id, score, completed=True, created_at=None) -> PracticeSession:
    session = PracticeSession(
        user_id=user_id,
        lesson_id=lesson_id,
        score=score,
        correct_notes=8,
        total_notes=10,
        wrong_notes=2,
        missed_notes=0,
        average_tempo=80.0,
        expected_tempo=80,
        tempo_accuracy=0.9,
        total_time_seconds=60.0,
        completed=completed,
    )
    if created_at is not None:
        session.created_at = created_at
    return session


async def _lessons(db: AsyncSession) -> dict[str, uuid.UUID]:
    cat = Category(id=uuid.uuid4(), name="Ranking HU-12")
    db.add(cat)
    lessons = {
        name: Lesson(
            id=uuid.uuid4(),
            category_id=cat.id,
            title=f"{name} lesson",
            description="d",
            instrument=name,
            difficulty="principiante",
            tempo_bpm=80,
        )
        for name in ("quena", "zampona", "tarka")
    }
    db.add_all(lessons.values())
    await db.commit()
    return {name: lesson.id for name, lesson in lessons.items()}


class TestGetLeaderboardService:
    async def test_ranks_by_xp_and_ties_share_position(self, db_session: AsyncSession):
        lessons = await _lessons(db_session)
        a, b, c, d = (_user(i) for i in range(4))
        db_session.add_all([a, b, c, d])
        await db_session.commit()
        # score 100 -> 75 XP, score 90 -> 55 XP, score 50 sin completar -> 10 XP
        db_session.add_all(
            [
                _session(a.id, lessons["quena"], 100),
                _session(b.id, lessons["quena"], 90),
                _session(c.id, lessons["quena"], 90),
                _session(d.id, lessons["quena"], 50, completed=False),
            ]
        )
        await db_session.commit()

        result = await svc.get_leaderboard(db_session, "quena", "weekly", 10, user_id=d.id)

        ranking = [(i["rank"], i["xp"]) for i in result["items"]]
        assert ranking == [(1, 75), (2, 55), (2, 55), (4, 10)]
        assert result["user_rank"] == 4

    async def test_filters_by_instrument(self, db_session: AsyncSession):
        lessons = await _lessons(db_session)
        a = _user(1)
        db_session.add(a)
        await db_session.commit()
        db_session.add(_session(a.id, lessons["zampona"], 100))
        await db_session.commit()

        quena = await svc.get_leaderboard(db_session, "quena", "weekly", 10, user_id=a.id)
        zampona = await svc.get_leaderboard(db_session, "zampona", "weekly", 10, user_id=a.id)

        assert quena == {"items": [], "user_rank": None}
        assert zampona["items"][0]["xp"] == 75

    async def test_weekly_excludes_last_week_but_all_time_keeps_it(self, db_session: AsyncSession):
        lessons = await _lessons(db_session)
        a = _user(1)
        db_session.add(a)
        await db_session.commit()
        old = svc.get_week_start_utc() - timedelta(days=1)  # domingo anterior
        db_session.add_all(
            [
                _session(a.id, lessons["quena"], 100, created_at=old),
                _session(a.id, lessons["quena"], 90, created_at=datetime.now(UTC)),
            ]
        )
        await db_session.commit()

        weekly = await svc.get_leaderboard(db_session, "quena", "weekly", 10)
        all_time = await svc.get_leaderboard(db_session, "quena", "all_time", 10)

        assert weekly["items"][0]["xp"] == 55
        assert all_time["items"][0]["xp"] == 130

    async def test_user_without_practice_has_no_rank(self, db_session: AsyncSession):
        lessons = await _lessons(db_session)
        a, idle = _user(1), _user(2)
        db_session.add_all([a, idle])
        await db_session.commit()
        db_session.add(_session(a.id, lessons["quena"], 90))
        await db_session.commit()

        result = await svc.get_leaderboard(db_session, "quena", "weekly", 10, user_id=idle.id)

        assert len(result["items"]) == 1
        assert result["user_rank"] is None

    async def test_unknown_scope_and_instrument_raise(self, db_session: AsyncSession):
        with pytest.raises(ValueError, match="Scope válido: weekly, all_time"):
            await svc.get_leaderboard(db_session, "quena", "monthly", 10)
        with pytest.raises(ValueError, match="Instrumento válido"):
            await svc.get_leaderboard(db_session, "guitarra", "weekly", 10)


class TestLeaderboardWith50Users:
    async def test_limit_and_positions_with_seeded_users(self, db_session: AsyncSession):
        lessons = await _lessons(db_session)
        users = [_user(i) for i in range(50)]
        db_session.add_all(users)
        await db_session.commit()
        # El usuario i practica i+1 veces con score 90 (55 XP c/u): XP estrictamente creciente.
        db_session.add_all(
            [
                _session(u.id, lessons["tarka"], 90)
                for i, u in enumerate(users)
                for _ in range(i + 1)
            ]
        )
        await db_session.commit()

        result = await svc.get_leaderboard(db_session, "tarka", "all_time", 10, user_id=users[0].id)

        assert [i["rank"] for i in result["items"]] == list(range(1, 11))
        assert result["items"][0]["user_id"] == users[49].id
        assert result["items"][0]["xp"] == 50 * 55
        assert result["user_rank"] == 50


class TestLeaderboardEndpoint:
    async def test_returns_structured_json_for_current_user(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession, test_user: User
    ):
        lessons = await _lessons(db_session)
        db_session.add(_session(test_user.id, lessons["quena"], 90))
        await db_session.commit()

        resp = await client.get(
            "/api/v1/rankings/leaderboard?instrument=quena&scope=weekly", headers=auth_headers
        )

        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["user_rank"] == 1
        assert body["items"][0]["username"] == test_user.username
        assert set(body["items"][0]) == {
            "rank",
            "user_id",
            "username",
            "full_name",
            "avatar_url",
            "xp",
        }

    async def test_unknown_scope_returns_400(self, client: AsyncClient, auth_headers: dict):
        resp = await client.get(
            "/api/v1/rankings/leaderboard?instrument=quena&scope=monthly", headers=auth_headers
        )
        assert resp.status_code == 400
        assert resp.json()["detail"] == "Scope válido: weekly, all_time"

    async def test_requires_authentication(self, client: AsyncClient):
        resp = await client.get("/api/v1/rankings/leaderboard?instrument=quena")
        assert resp.status_code in (401, 403)
