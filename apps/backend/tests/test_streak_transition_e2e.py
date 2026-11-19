"""Pruebas E2E de transiciones de calendario y cálculo de rachas de práctica (HU-13).

Cubre los criterios de la Issue #141 (Parte de #136):
1. Registro de práctica en Día 1 -> racha activa = 1.
2. Registro de práctica en Día 2 -> racha activa = 2.
3. Registro de práctica en Día 3 -> racha activa = 3 y otorgamiento del logro de racha ('streak_3').
4. Idempotencia en el mismo día calendario (múltiples prácticas el mismo día no inflan la racha).
5. Recuperación con congelador de racha (streak freeze) ante un día de ausencia.
6. Ruptura y reinicio de racha tras inactividad prolongada.
"""

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Category, Lesson
from app.models.ranking import Achievement, UserAchievement, UserXP
from app.models.user import User
from app.services import ranking_service


@pytest.fixture
async def sample_lesson(db_session: AsyncSession) -> Lesson:
    """Crea una lección de prueba en base de datos."""
    cat = Category(
        id=uuid.uuid4(),
        name=f"Escalas Básicas {uuid.uuid4().hex[:6]}",
        order=1,
    )
    db_session.add(cat)
    await db_session.commit()

    lesson = Lesson(
        id=uuid.uuid4(),
        category_id=cat.id,
        title="Escala de Sol Mayor",
        description="Ejercicio de digitación en Quena",
        instrument="quena",
        difficulty="principiante",
        tempo_bpm=80,
    )
    db_session.add(lesson)
    await db_session.commit()
    await db_session.refresh(lesson)
    return lesson


@pytest.fixture
async def seed_streak_achievements(db_session: AsyncSession) -> None:
    """Inserta el logro de racha de 3 días 'streak_3' si no existe."""
    existing = await db_session.execute(select(Achievement).where(Achievement.code == "streak_3"))
    if not existing.scalar_one_or_none():
        ach = Achievement(
            id=uuid.uuid4(),
            code="streak_3",
            name="En Racha",
            description="Practicá 3 días seguidos",
            icon="local_fire_department",
            category="streak",
            xp_reward=30,
            requirement_type="streak",
            requirement_value=3,
            rarity="common",
            order=1,
            is_active=True,
        )
        db_session.add(ach)
        await db_session.commit()


class TestStreakTransitionService:
    """Validación del servicio de racha con avance de fechas calendario en UTC."""

    @pytest.mark.asyncio
    async def test_three_consecutive_days_awards_streak_3_achievement(
        self, db_session: AsyncSession, test_user: User, seed_streak_achievements
    ):
        """Simula Día 1, Día 2 y Día 3 consecutivos comprobando racha y logro."""
        base_time = datetime(2026, 4, 1, 10, 0, tzinfo=UTC)

        # ----------------- DÍA 1 -----------------
        res1 = await ranking_service.process_practice_xp(
            db=db_session,
            user_id=test_user.id,
            score=85.0,
            difficulty="principiante",
            is_completed=True,
            total_time_seconds=90.0,
            now=base_time,
        )
        await db_session.commit()

        assert res1["current_streak"] == 1
        xp1 = (
            await db_session.execute(select(UserXP).where(UserXP.user_id == test_user.id))
        ).scalar_one()
        assert xp1.current_streak == 1
        assert xp1.streak_freezes >= 1  # Congelador de bienvenida

        # Práctica extra el mismo día: la racha debe mantenerse en 1
        res1_extra = await ranking_service.process_practice_xp(
            db=db_session,
            user_id=test_user.id,
            score=90.0,
            difficulty="principiante",
            is_completed=True,
            total_time_seconds=60.0,
            now=base_time + timedelta(hours=4),
        )
        await db_session.commit()
        assert res1_extra["current_streak"] == 1

        # ----------------- DÍA 2 -----------------
        day2_time = base_time + timedelta(days=1)
        res2 = await ranking_service.process_practice_xp(
            db=db_session,
            user_id=test_user.id,
            score=88.0,
            difficulty="principiante",
            is_completed=True,
            total_time_seconds=110.0,
            now=day2_time,
        )
        await db_session.commit()

        assert res2["current_streak"] == 2
        xp2 = (
            await db_session.execute(select(UserXP).where(UserXP.user_id == test_user.id))
        ).scalar_one()
        assert xp2.current_streak == 2

        # ----------------- DÍA 3 -----------------
        day3_time = base_time + timedelta(days=2)
        res3 = await ranking_service.process_practice_xp(
            db=db_session,
            user_id=test_user.id,
            score=95.0,
            difficulty="principiante",
            is_completed=True,
            total_time_seconds=120.0,
            now=day3_time,
        )
        await db_session.commit()

        # Criterio 3: Racha activa = 3
        assert res3["current_streak"] == 3
        xp3 = (
            await db_session.execute(select(UserXP).where(UserXP.user_id == test_user.id))
        ).scalar_one()
        assert xp3.current_streak == 3
        assert xp3.longest_streak >= 3

        # Criterio 3: Otorgamiento del logro de racha de 3 días
        unlocked_codes = [ach.code for ach in res3["new_achievements"]]
        assert "streak_3" in unlocked_codes

        # Validar persistencia en UserAchievement
        ach_q = await db_session.execute(
            select(UserAchievement)
            .join(Achievement)
            .where(
                UserAchievement.user_id == test_user.id,
                Achievement.code == "streak_3",
            )
        )
        user_ach = ach_q.scalar_one_or_none()
        assert user_ach is not None

    @pytest.mark.asyncio
    async def test_freeze_consumed_on_one_day_gap(self, db_session: AsyncSession, test_user: User):
        """Un día omitido consume el congelador de bienvenida preservando la racha."""
        t1 = datetime(2026, 6, 1, 9, 0, tzinfo=UTC)
        # Día 1
        await ranking_service.process_practice_xp(
            db=db_session,
            user_id=test_user.id,
            score=80.0,
            difficulty="principiante",
            is_completed=True,
            total_time_seconds=60.0,
            now=t1,
        )
        await db_session.commit()

        # Día 3 (Día 2 omitido): congelador salva la racha
        t3 = t1 + timedelta(days=2)
        res3 = await ranking_service.process_practice_xp(
            db=db_session,
            user_id=test_user.id,
            score=80.0,
            difficulty="principiante",
            is_completed=True,
            total_time_seconds=60.0,
            now=t3,
        )
        await db_session.commit()

        assert res3["current_streak"] == 2
        xp = (
            await db_session.execute(select(UserXP).where(UserXP.user_id == test_user.id))
        ).scalar_one()
        assert xp.current_streak == 2
        assert xp.streak_freezes == 0  # Se consumió el congelador

    @pytest.mark.asyncio
    async def test_streak_resets_after_long_inactivity(
        self, db_session: AsyncSession, test_user: User
    ):
        """Inactividad mayor a 1 día rompe la racha reiniciándola en 1."""
        t1 = datetime(2026, 7, 1, 9, 0, tzinfo=UTC)
        # Día 1
        await ranking_service.process_practice_xp(
            db=db_session,
            user_id=test_user.id,
            score=80.0,
            difficulty="principiante",
            is_completed=True,
            total_time_seconds=60.0,
            now=t1,
        )
        await db_session.commit()

        # Día 5 (3 días omitidos): racha se rompe
        t5 = t1 + timedelta(days=4)
        res5 = await ranking_service.process_practice_xp(
            db=db_session,
            user_id=test_user.id,
            score=80.0,
            difficulty="principiante",
            is_completed=True,
            total_time_seconds=60.0,
            now=t5,
        )
        await db_session.commit()

        assert res5["current_streak"] == 1


class TestStreakTransitionApiIntegration:
    """Validación del flujo E2E a través del endpoint HTTP /api/practice/submit."""

    @pytest.mark.asyncio
    async def test_api_submit_practice_streak_progression(
        self,
        client: AsyncClient,
        auth_headers: dict,
        sample_lesson: Lesson,
        seed_streak_achievements,
        db_session: AsyncSession,
    ):
        """Envía 3 sesiones de práctica en 3 días sucesivos usando /api/practice/submit."""
        day1 = datetime(2026, 5, 10, 14, 0, tzinfo=UTC)

        # 1. Envío Día 1
        res1 = await client.post(
            "/api/practice/submit",
            json={
                "lesson_id": str(sample_lesson.id),
                "score": 85.0,
                "correct_notes": 18,
                "total_notes": 20,
                "wrong_notes": 2,
                "missed_notes": 0,
                "average_tempo": 80.0,
                "total_time_seconds": 95.0,
                "completed": True,
                "practice_datetime": day1.isoformat(),
            },
            headers=auth_headers,
        )
        assert res1.status_code == 200
        data1 = res1.json()
        assert data1["current_streak"] == 1

        # 2. Envío Día 2
        day2 = day1 + timedelta(days=1)
        res2 = await client.post(
            "/api/practice/submit",
            json={
                "lesson_id": str(sample_lesson.id),
                "score": 88.0,
                "correct_notes": 19,
                "total_notes": 20,
                "wrong_notes": 1,
                "missed_notes": 0,
                "average_tempo": 82.0,
                "total_time_seconds": 90.0,
                "completed": True,
                "practice_datetime": day2.isoformat(),
            },
            headers=auth_headers,
        )
        assert res2.status_code == 200
        data2 = res2.json()
        assert data2["current_streak"] == 2

        # 3. Envío Día 3
        day3 = day1 + timedelta(days=2)
        res3 = await client.post(
            "/api/practice/submit",
            json={
                "lesson_id": str(sample_lesson.id),
                "score": 96.0,
                "correct_notes": 20,
                "total_notes": 20,
                "wrong_notes": 0,
                "missed_notes": 0,
                "average_tempo": 85.0,
                "total_time_seconds": 88.0,
                "completed": True,
                "practice_datetime": day3.isoformat(),
            },
            headers=auth_headers,
        )
        assert res3.status_code == 200
        data3 = res3.json()
        assert data3["current_streak"] == 3
        # Logro obtenido
        assert any(ach.get("code") == "streak_3" for ach in data3["new_achievements"])

        # 4. Verificar en leaderboard de rachas (/api/rankings/streaks)
        res_streaks = await client.get("/api/rankings/streaks", headers=auth_headers)
        assert res_streaks.status_code == 200
        streaks_data = res_streaks.json()
        assert streaks_data["my_streak"] == 3
