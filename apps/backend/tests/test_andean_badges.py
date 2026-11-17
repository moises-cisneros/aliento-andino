"""HU-13: insignias andinas desbloqueadas a partir del historial de prácticas."""

import uuid

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Category, Lesson, PracticeSession
from app.models.ranking import Achievement, UserAchievement
from app.models.user import User
from app.services import ranking_service
from app.utils.security import hash_password
from seed_achievements import ACHIEVEMENTS_SEED

pytestmark = pytest.mark.asyncio

ANDEAN_CODES = {
    "andean_first_clean_breath",
    "andean_siku_master",
    "andean_air_control_30s",
    "andean_pentatonic_scale",
}


async def _setup(db: AsyncSession, tag: str):
    user = User(
        id=uuid.uuid4(),
        email=f"{tag}@example.com",
        username=tag,
        full_name=tag,
        hashed_password=hash_password("TestPass123"),
        auth_provider="local",
        is_active=True,
        is_verified=True,
    )
    cat = Category(id=uuid.uuid4(), name=f"cat-{tag}", order=1)
    db.add_all([user, cat])
    for data in ACHIEVEMENTS_SEED:
        if data["code"] in ANDEAN_CODES:
            db.add(Achievement(**data))
    await db.commit()
    return user.id, cat.id


async def _lesson(db: AsyncSession, cat_id, instrument="quena", title="Lección") -> uuid.UUID:
    lesson = Lesson(
        id=uuid.uuid4(),
        category_id=cat_id,
        title=title,
        description="d",
        instrument=instrument,
        difficulty="principiante",
        tempo_bpm=80,
        order=0,
        is_active=True,
    )
    db.add(lesson)
    await db.commit()
    return lesson.id


async def _session(db: AsyncSession, user_id, lesson_id, score=90.0, seconds=20.0) -> None:
    db.add(
        PracticeSession(
            id=uuid.uuid4(),
            user_id=user_id,
            lesson_id=lesson_id,
            score=score,
            correct_notes=9,
            total_notes=10,
            wrong_notes=1,
            missed_notes=0,
            average_tempo=80,
            expected_tempo=80,
            tempo_accuracy=0.9,
            total_time_seconds=seconds,
            completed=True,
        )
    )
    await db.commit()


async def _unlocked(db: AsyncSession, user_id) -> set[str]:
    xp = await ranking_service.get_or_create_user_xp(db, user_id)
    await ranking_service.check_achievements(db, user_id, xp)
    rows = await db.execute(
        select(Achievement.code)
        .join(UserAchievement, UserAchievement.achievement_id == Achievement.id)
        .where(UserAchievement.user_id == user_id)
    )
    return {c for (c,) in rows.all()} & ANDEAN_CODES


class TestAndeanBadges:
    async def test_seed_defines_the_four_andean_badges(self):
        names = {a["name"] for a in ACHIEVEMENTS_SEED if a["code"] in ANDEAN_CODES}
        assert names == {
            "Primer Soplo Limpio",
            "Maestro del Siku",
            "Control de Aire 30s",
            "Escala Pentatónica Completa",
        }

    async def test_no_sessions_unlocks_nothing(self, db_session: AsyncSession):
        uid, _ = await _setup(db_session, "ab0")
        assert await _unlocked(db_session, uid) == set()

    async def test_first_clean_breath_needs_score_90(self, db_session: AsyncSession):
        uid, cat = await _setup(db_session, "ab1")
        lid = await _lesson(db_session, cat)
        await _session(db_session, uid, lid, score=89.0)
        assert await _unlocked(db_session, uid) == set()
        await _session(db_session, uid, lid, score=90.0)
        assert await _unlocked(db_session, uid) == {"andean_first_clean_breath"}

    async def test_air_control_needs_30s_and_score_80(self, db_session: AsyncSession):
        uid, cat = await _setup(db_session, "ab2")
        lid = await _lesson(db_session, cat)
        await _session(db_session, uid, lid, score=75.0, seconds=45.0)
        await _session(db_session, uid, lid, score=85.0, seconds=29.0)
        assert "andean_air_control_30s" not in await _unlocked(db_session, uid)
        await _session(db_session, uid, lid, score=80.0, seconds=30.0)
        assert "andean_air_control_30s" in await _unlocked(db_session, uid)

    async def test_siku_master_needs_10_distinct_zampona_lessons(self, db_session: AsyncSession):
        uid, cat = await _setup(db_session, "ab3")
        quena = await _lesson(db_session, cat, "quena")
        await _session(db_session, uid, quena, score=95.0)
        zampona = [await _lesson(db_session, cat, "zampona") for _ in range(10)]
        for lid in zampona[:9]:
            await _session(db_session, uid, lid, score=75.0)
        await _session(db_session, uid, zampona[0], score=75.0)  # repetir no suma
        assert "andean_siku_master" not in await _unlocked(db_session, uid)
        await _session(db_session, uid, zampona[9], score=75.0)
        assert "andean_siku_master" in await _unlocked(db_session, uid)

    async def test_siku_master_ignores_failed_sessions(self, db_session: AsyncSession):
        uid, cat = await _setup(db_session, "ab4")
        for _ in range(10):
            lid = await _lesson(db_session, cat, "zampona")
            await _session(db_session, uid, lid, score=60.0)
        assert "andean_siku_master" not in await _unlocked(db_session, uid)

    async def test_pentatonic_scale_by_lesson_title(self, db_session: AsyncSession):
        uid, cat = await _setup(db_session, "ab5")
        other = await _lesson(db_session, cat, title="Mi Pequeña Quena")
        await _session(db_session, uid, other, score=95.0)
        assert "andean_pentatonic_scale" not in await _unlocked(db_session, uid)
        penta = await _lesson(db_session, cat, title="Escala Pentatónica Completa")
        await _session(db_session, uid, penta, score=70.0)
        assert "andean_pentatonic_scale" in await _unlocked(db_session, uid)

    async def test_badge_unlocks_only_once_and_listing_reports_it(self, db_session: AsyncSession):
        uid, cat = await _setup(db_session, "ab6")
        lid = await _lesson(db_session, cat)
        await _session(db_session, uid, lid, score=95.0)
        await _unlocked(db_session, uid)
        await _unlocked(db_session, uid)
        count = (
            (
                await db_session.execute(
                    select(UserAchievement).where(UserAchievement.user_id == uid)
                )
            )
            .scalars()
            .all()
        )
        assert len(count) == len({u.achievement_id for u in count})
        listing = await ranking_service.get_all_achievements(db_session, uid)
        by_code = {a["code"]: a for a in listing["achievements"]}
        assert by_code["andean_first_clean_breath"]["is_unlocked"] is True
        assert by_code["andean_first_clean_breath"]["unlocked_at"] is not None
        assert by_code["andean_siku_master"]["is_unlocked"] is False
