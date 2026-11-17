"""Lote 4: congeladores de racha (streak freeze) en process_practice_xp."""

import uuid
from datetime import UTC, date, datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Category, Lesson
from app.models.ranking import UserXP
from app.models.user import User
from app.services.ranking_service import (
    MAX_STREAK_FREEZES,
    StreakUpdateResult,
    process_practice_xp,
    update_user_streak,
)
from app.utils.security import hash_password

pytestmark = pytest.mark.asyncio


def _today():
    return datetime.now(UTC).date()


async def _mk_user(db: AsyncSession, email: str, username: str) -> User:
    u = User(
        id=uuid.uuid4(),
        email=email,
        username=username,
        full_name=username.capitalize(),
        hashed_password=hash_password("TestPass123"),
        auth_provider="local",
        is_active=True,
        is_verified=True,
    )
    db.add(u)
    await db.commit()
    return u


async def _practice(db: AsyncSession, uid: uuid.UUID):
    return await process_practice_xp(
        db,
        uid,
        score=80.0,
        difficulty="principiante",
        is_completed=True,
        total_time_seconds=120.0,
    )


class TestStreakFreeze:
    async def test_welcome_freeze_on_first_practice(self, db_session: AsyncSession):
        u = await _mk_user(db_session, "sf1@example.com", "sfone")
        await _practice(db_session, u.id)
        xp = (await db_session.execute(select(UserXP).where(UserXP.user_id == u.id))).scalar_one()
        assert xp.current_streak == 1
        assert xp.streak_freezes >= 1  # congelador de bienvenida

    async def test_freeze_repairs_one_missed_day(self, db_session: AsyncSession):
        u = await _mk_user(db_session, "sf2@example.com", "sftwo")
        xp = UserXP(
            user_id=u.id,
            current_streak=5,
            longest_streak=5,
            streak_freezes=1,
            last_practice_date=_today() - timedelta(days=2),
        )
        db_session.add(xp)
        await db_session.commit()

        await _practice(db_session, u.id)
        await db_session.refresh(xp)
        assert xp.current_streak == 6  # la racha continuó
        assert xp.streak_freezes == 0  # se consumió el congelador
        assert xp.last_practice_date == _today()

    async def test_no_freeze_breaks_streak(self, db_session: AsyncSession):
        u = await _mk_user(db_session, "sf3@example.com", "sfthree")
        xp = UserXP(
            user_id=u.id,
            current_streak=5,
            streak_freezes=0,
            last_practice_date=_today() - timedelta(days=2),
        )
        db_session.add(xp)
        await db_session.commit()

        await _practice(db_session, u.id)
        await db_session.refresh(xp)
        assert xp.current_streak == 1  # sin congelador: se rompe

    async def test_freeze_not_used_for_multiday_gap(self, db_session: AsyncSession):
        u = await _mk_user(db_session, "sf4@example.com", "sffour")
        xp = UserXP(
            user_id=u.id,
            current_streak=5,
            streak_freezes=1,
            last_practice_date=_today() - timedelta(days=3),
        )
        db_session.add(xp)
        await db_session.commit()

        await _practice(db_session, u.id)
        await db_session.refresh(xp)
        assert xp.current_streak == 1  # 2+ días perdidos: se rompe igual
        assert xp.streak_freezes == 1  # NO se consume para gaps grandes

    async def test_consecutive_day_increments(self, db_session: AsyncSession):
        u = await _mk_user(db_session, "sf5@example.com", "sffive")
        xp = UserXP(
            user_id=u.id,
            current_streak=3,
            streak_freezes=0,
            last_practice_date=_today() - timedelta(days=1),
        )
        db_session.add(xp)
        await db_session.commit()

        await _practice(db_session, u.id)
        await db_session.refresh(xp)
        assert xp.current_streak == 4

    async def test_milestone_grants_freeze_at_seven(self, db_session: AsyncSession):
        u = await _mk_user(db_session, "sf6@example.com", "sfsix")
        xp = UserXP(
            user_id=u.id,
            current_streak=6,
            streak_freezes=0,
            last_practice_date=_today() - timedelta(days=1),
        )
        db_session.add(xp)
        await db_session.commit()

        await _practice(db_session, u.id)
        await db_session.refresh(xp)
        assert xp.current_streak == 7
        assert xp.streak_freezes == 1  # hito de 7 días -> +1 congelador

    async def test_freeze_capped(self, db_session: AsyncSession):
        u = await _mk_user(db_session, "sf7@example.com", "sfseven")
        xp = UserXP(
            user_id=u.id,
            current_streak=6,
            streak_freezes=MAX_STREAK_FREEZES,
            last_practice_date=_today() - timedelta(days=1),
        )
        db_session.add(xp)
        await db_session.commit()

        await _practice(db_session, u.id)
        await db_session.refresh(xp)
        assert xp.streak_freezes == MAX_STREAK_FREEZES  # no supera el tope

    async def test_practice_twice_same_day_no_double_spend(self, db_session: AsyncSession):
        u = await _mk_user(db_session, "sf8@example.com", "sfeight")
        xp = UserXP(
            user_id=u.id,
            current_streak=5,
            streak_freezes=1,
            last_practice_date=_today() - timedelta(days=2),
        )
        db_session.add(xp)
        await db_session.commit()

        await _practice(db_session, u.id)  # repara: streak 6, freezes 0
        await _practice(db_session, u.id)  # mismo día: sin cambios
        await db_session.refresh(xp)
        assert xp.current_streak == 6
        assert xp.streak_freezes == 0


LIMA = timezone(timedelta(hours=-5))


async def _seed_xp(db: AsyncSession, email: str, username: str, **fields) -> UserXP:
    u = await _mk_user(db, email, username)
    xp = UserXP(user_id=u.id, **fields)
    db.add(xp)
    await db.commit()
    return xp


def _at(day: date, hour: int = 10, tz=UTC) -> datetime:
    return datetime(day.year, day.month, day.day, hour, 0, tzinfo=tz)


class TestUpdateUserStreak:
    async def test_consecutive_day_adds_one(self, db_session: AsyncSession):
        d = date(2026, 3, 10)
        xp = await _seed_xp(
            db_session,
            "us1@example.com",
            "usone",
            current_streak=4,
            longest_streak=4,
            streak_freezes=1,
            last_practice_date=d - timedelta(days=1),
        )
        res = await update_user_streak(db_session, xp.user_id, _at(d))
        assert res == StreakUpdateResult(
            current_streak=5, streak_preserved_by_freeze=False, freeze_consumed=False
        )
        assert xp.streak_freezes == 1

    async def test_one_day_gap_with_freeze_preserves_and_consumes(self, db_session: AsyncSession):
        d = date(2026, 3, 10)
        xp = await _seed_xp(
            db_session,
            "us2@example.com",
            "ustwo",
            current_streak=4,
            longest_streak=4,
            streak_freezes=2,
            last_practice_date=d - timedelta(days=2),
        )
        res = await update_user_streak(db_session, xp.user_id, _at(d))
        assert res.current_streak == 5
        assert res.streak_preserved_by_freeze is True
        assert res.freeze_consumed is True
        assert xp.streak_freezes == 1

    async def test_gap_without_freeze_resets_to_one(self, db_session: AsyncSession):
        d = date(2026, 3, 10)
        xp = await _seed_xp(
            db_session,
            "us3@example.com",
            "usthree",
            current_streak=9,
            longest_streak=9,
            streak_freezes=0,
            last_practice_date=d - timedelta(days=2),
        )
        res = await update_user_streak(db_session, xp.user_id, _at(d))
        assert res == StreakUpdateResult(
            current_streak=1, streak_preserved_by_freeze=False, freeze_consumed=False
        )
        assert xp.longest_streak == 9

    async def test_same_local_day_twice_keeps_counter(self, db_session: AsyncSession):
        d = date(2026, 3, 10)
        xp = await _seed_xp(
            db_session,
            "us4@example.com",
            "usfour",
            current_streak=3,
            longest_streak=3,
            streak_freezes=1,
            last_practice_date=d - timedelta(days=1),
        )
        await update_user_streak(db_session, xp.user_id, _at(d, 8))
        res = await update_user_streak(db_session, xp.user_id, _at(d, 22))
        assert res.current_streak == 4
        assert res.freeze_consumed is False
        assert xp.streak_freezes == 1

    async def test_uses_the_local_calendar_day_of_the_datetime(self, db_session: AsyncSession):
        # 02:00 UTC del 11 = 21:00 del 10 en Lima: el día local sigue siendo el 10.
        xp = await _seed_xp(
            db_session,
            "us5@example.com",
            "usfive",
            current_streak=2,
            longest_streak=2,
            streak_freezes=0,
            last_practice_date=date(2026, 3, 9),
        )
        moment = datetime(2026, 3, 11, 2, 0, tzinfo=UTC).astimezone(LIMA)
        res = await update_user_streak(db_session, xp.user_id, moment)
        assert res.current_streak == 3
        assert xp.last_practice_date == date(2026, 3, 10)

    async def test_first_practice_starts_streak_with_welcome_freeze(self, db_session: AsyncSession):
        u = await _mk_user(db_session, "us6@example.com", "ussix")
        res = await update_user_streak(db_session, u.id, _at(date(2026, 3, 10)))
        assert res.current_streak == 1
        xp = (await db_session.execute(select(UserXP).where(UserXP.user_id == u.id))).scalar_one()
        assert xp.streak_freezes == 1

    async def test_freeze_consumption_persists_in_database(self, db_session: AsyncSession):
        d = date(2026, 3, 10)
        xp = await _seed_xp(
            db_session,
            "us7@example.com",
            "usseven",
            current_streak=4,
            longest_streak=4,
            streak_freezes=1,
            last_practice_date=d - timedelta(days=2),
        )
        uid = xp.user_id
        await update_user_streak(db_session, uid, _at(d))
        await db_session.commit()
        db_session.expire_all()
        fresh = (await db_session.execute(select(UserXP).where(UserXP.user_id == uid))).scalar_one()
        assert (fresh.current_streak, fresh.streak_freezes, fresh.longest_streak) == (5, 0, 5)
        assert fresh.last_practice_date == d


class TestStreakThreeDayCycleViaApi:
    """E2E: tres prácticas por API en días distintos (el reloj se simula
    retrocediendo `last_practice_date`)."""

    async def test_consecutive_day_then_one_day_gap_preserved_by_freeze(
        self,
        client: AsyncClient,
        auth_headers: dict,
        db_session: AsyncSession,
        test_user,
    ):
        cat = Category(id=uuid.uuid4(), name="Cat Streak", order=1)
        db_session.add(cat)
        await db_session.flush()
        lesson = Lesson(
            id=uuid.uuid4(),
            category_id=cat.id,
            title="Lección racha",
            description="desc",
            difficulty="principiante",
            tempo_bpm=80,
            order=0,
            is_active=True,
        )
        db_session.add(lesson)
        await db_session.commit()
        uid = test_user.id
        lesson_id = str(lesson.id)

        async def practice() -> None:
            r = await client.post(
                "/api/v1/practice/session",
                headers=auth_headers,
                json={
                    "lesson_id": lesson_id,
                    "client_id": str(uuid.uuid4()),
                    "score": 90,
                    "correct_notes": 9,
                    "total_notes": 10,
                    "wrong_notes": 1,
                    "missed_notes": 0,
                    "average_tempo": 80,
                    "total_time_seconds": 30,
                    "errors_detail": [],
                    "completed": True,
                },
            )
            assert r.status_code == 200, r.text

        async def state() -> tuple[int, int]:
            db_session.expire_all()
            xp = (
                await db_session.execute(select(UserXP).where(UserXP.user_id == uid))
            ).scalar_one()
            return xp.current_streak, xp.streak_freezes

        async def rewind(days: int) -> None:
            xp = (
                await db_session.execute(select(UserXP).where(UserXP.user_id == uid))
            ).scalar_one()
            xp.last_practice_date = _today() - timedelta(days=days)
            await db_session.commit()

        await practice()  # día 1
        assert await state() == (1, 1)  # congelador de bienvenida

        await rewind(1)  # "ayer" practicó
        await practice()  # día 2 consecutivo
        assert await state() == (2, 1)

        await rewind(2)  # faltó un día
        await practice()  # día 4: el congelador salva la racha
        assert await state() == (3, 0)
