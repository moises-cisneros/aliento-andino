"""Lote 4: congeladores de racha (streak freeze) en process_practice_xp."""

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ranking import UserXP
from app.models.user import User
from app.services.ranking_service import MAX_STREAK_FREEZES, process_practice_xp
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
