"""Tests de las funciones puras de gamificación (XP, niveles, semana)."""

from datetime import UTC, datetime

import pytest

from app.services.ranking_service import (
    calculate_level,
    calculate_session_xp,
    get_current_week_monday,
    xp_for_level,
)


class TestCalculateSessionXp:
    @pytest.mark.parametrize(
        "score, difficulty, completed, expected",
        [
            # base(10) + precision + completion(15 si completed), * multiplicador
            (100.0, "principiante", True, 75),  # (10+50+15)*1.0
            (100.0, "avanzado", True, 150),  # (10+50+15)*2.0
            (90.0, "intermedio", True, 82),  # (10+30+15)*1.5 = 82.5 -> 82
            (85.0, "intermedio", True, 67),  # (10+20+15)*1.5 = 67.5 -> 67
            (50.0, "principiante", False, 10),  # (10+0+0)*1.0
            (75.0, "avanzado", False, 40),  # (10+10+0)*2.0
        ],
    )
    def test_xp_values(self, score, difficulty, completed, expected):
        assert calculate_session_xp(score, difficulty, completed) == expected

    def test_unknown_difficulty_defaults_to_multiplier_one(self):
        # dificultad desconocida -> multiplicador 1.0
        assert calculate_session_xp(100.0, "imposible", True) == 75

    def test_completion_bonus_only_when_completed(self):
        with_bonus = calculate_session_xp(60.0, "principiante", True)
        without_bonus = calculate_session_xp(60.0, "principiante", False)
        assert with_bonus - without_bonus == 15


class TestLevels:
    @pytest.mark.parametrize(
        "total_xp, expected_level",
        [(0, 1), (99, 1), (100, 2), (399, 2), (400, 3), (900, 4)],
    )
    def test_calculate_level(self, total_xp, expected_level):
        assert calculate_level(total_xp) == expected_level

    @pytest.mark.parametrize(
        "level, expected_xp",
        [(1, 0), (2, 100), (3, 400), (4, 900)],
    )
    def test_xp_for_level(self, level, expected_xp):
        assert xp_for_level(level) == expected_xp

    def test_level_and_xp_are_inverse(self):
        # El XP justo para alcanzar un nivel debe mapear de vuelta a ese nivel.
        for level in range(1, 10):
            assert calculate_level(xp_for_level(level)) == level


class TestWeekMonday:
    def test_returns_a_monday(self):
        monday = get_current_week_monday()
        assert monday.weekday() == 0

    def test_not_in_the_future(self):
        assert get_current_week_monday() <= datetime.now(UTC).date()


# ===================== SUB-12-A / HU-12 TESTS =====================

import uuid
from datetime import timedelta

from fastapi import HTTPException
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Category, Lesson, PracticeSession
from app.models.user import User
from app.services.ranking_service import (
    RankingService,
    assign_ranks,
    get_leaderboard,
)
from app.utils.security import hash_password


class TestAssignRanks:
    """Pruebas unitarias para el algoritmo de asignación de puestos y empates."""

    def test_empty_list(self):
        assert assign_ranks([]) == []

    def test_strictly_decreasing(self):
        items = [{"user_id": 1, "xp": 100}, {"user_id": 2, "xp": 80}, {"user_id": 3, "xp": 60}]
        ranked = assign_ranks(items)
        assert [r["rank"] for r in ranked] == [1, 2, 3]

    def test_tie_in_first_place(self):
        items = [{"user_id": 1, "xp": 100}, {"user_id": 2, "xp": 100}, {"user_id": 3, "xp": 80}]
        ranked = assign_ranks(items)
        # Empate en primer puesto: ambos rank 1, siguiente puesto salta a 3
        assert [r["rank"] for r in ranked] == [1, 1, 3]

    def test_multiple_ties(self):
        items = [
            {"user_id": 1, "xp": 100},
            {"user_id": 2, "xp": 90},
            {"user_id": 3, "xp": 90},
            {"user_id": 4, "xp": 80},
            {"user_id": 5, "xp": 80},
            {"user_id": 6, "xp": 70},
        ]
        ranked = assign_ranks(items)
        assert [r["rank"] for r in ranked] == [1, 2, 2, 4, 4, 6]

    def test_all_equal_scores(self):
        items = [{"user_id": 1, "xp": 50}, {"user_id": 2, "xp": 50}, {"user_id": 3, "xp": 50}]
        ranked = assign_ranks(items)
        assert [r["rank"] for r in ranked] == [1, 1, 1]


class TestLeaderboardValidation:
    """Pruebas unitarias para validación de scope e instrumentos andinos."""

    @pytest.mark.asyncio
    async def test_invalid_scope_raises_400(self, db_session: AsyncSession):
        with pytest.raises(HTTPException) as exc_info:
            await get_leaderboard(db=db_session, scope="monthly")
        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Scope válido: weekly, all_time"

    @pytest.mark.asyncio
    async def test_invalid_instrument_raises_400(self, db_session: AsyncSession):
        with pytest.raises(HTTPException) as exc_info:
            await get_leaderboard(db=db_session, instrument="guitarra", scope="weekly")
        assert exc_info.value.status_code == 400
        assert "no válido" in exc_info.value.detail


def _make_user(email: str, username: str) -> User:
    return User(
        id=uuid.uuid4(),
        email=email,
        username=username,
        full_name=username.capitalize(),
        hashed_password=hash_password("TestPass123"),
        auth_provider="local",
        is_active=True,
        is_verified=True,
    )


def _make_category(name: str = "Técnica Andina") -> Category:
    return Category(
        id=uuid.uuid4(),
        name=name,
        description="Categoría de prueba",
        order=1,
        is_active=True,
    )


def _make_lesson(
    category_id: uuid.UUID,
    instrument: str,
    title: str,
    difficulty: str = "principiante",
) -> Lesson:
    return Lesson(
        id=uuid.uuid4(),
        category_id=category_id,
        title=title,
        description=f"Lección de {instrument}",
        instrument=instrument,
        difficulty=difficulty,
        tempo_bpm=80,
    )


def _make_session(
    user_id: uuid.UUID,
    lesson_id: uuid.UUID,
    score: float,
    dt: datetime,
    completed: bool = True,
) -> PracticeSession:
    return PracticeSession(
        id=uuid.uuid4(),
        user_id=user_id,
        lesson_id=lesson_id,
        score=score,
        correct_notes=10,
        total_notes=10,
        wrong_notes=0,
        missed_notes=0,
        average_tempo=80.0,
        expected_tempo=80,
        tempo_accuracy=100.0,
        total_time_seconds=60.0,
        completed=completed,
        created_at=dt,
    )


@pytest.mark.asyncio
class TestLeaderboardIntegration:
    """Pruebas de integración del leaderboard con base de datos."""

    async def test_empty_leaderboard(self, db_session: AsyncSession, test_user: User):
        result = await get_leaderboard(
            db=db_session,
            user_id=test_user.id,
            instrument="quena",
            scope="weekly",
        )
        assert result.items == []
        assert result.user_rank is None
        assert result.instrument == "quena"
        assert result.scope == "weekly"

    async def test_instrument_discrimination(self, db_session: AsyncSession):
        cat = _make_category()
        db_session.add(cat)
        await db_session.flush()

        l_quena = _make_lesson(cat.id, "quena", "Quena 1")
        l_zampona = _make_lesson(cat.id, "zampona", "Zampoña 1")
        l_tarka = _make_lesson(cat.id, "tarka", "Tarka 1")
        db_session.add_all([l_quena, l_zampona, l_tarka])

        u1 = _make_user("u1@example.com", "quenista")
        u2 = _make_user("u2@example.com", "zamponista")
        u3 = _make_user("u3@example.com", "tarkista")
        db_session.add_all([u1, u2, u3])
        await db_session.flush()

        now = datetime.now(UTC)
        s1 = _make_session(u1.id, l_quena.id, 95.0, now)
        s2 = _make_session(u2.id, l_zampona.id, 90.0, now)
        s3 = _make_session(u3.id, l_tarka.id, 85.0, now)
        db_session.add_all([s1, s2, s3])
        await db_session.commit()

        # Filtro Quena solo devuelve quenista
        res_q = await get_leaderboard(db=db_session, instrument="quena", scope="weekly")
        assert len(res_q.items) == 1
        assert res_q.items[0].username == "quenista"
        assert res_q.items[0].rank == 1

        # Filtro Zampoña solo devuelve zamponista
        res_z = await get_leaderboard(db=db_session, instrument="zampona", scope="weekly")
        assert len(res_z.items) == 1
        assert res_z.items[0].username == "zamponista"
        assert res_z.items[0].rank == 1

        # Filtro Tarka solo devuelve tarkista
        res_t = await get_leaderboard(db=db_session, instrument="tarka", scope="weekly")
        assert len(res_t.items) == 1
        assert res_t.items[0].username == "tarkista"
        assert res_t.items[0].rank == 1

        # Sin filtro devuelve los 3
        res_all = await get_leaderboard(db=db_session, instrument=None, scope="weekly")
        assert len(res_all.items) == 3

    async def test_weekly_scope_filters_old_sessions(self, db_session: AsyncSession):
        cat = _make_category()
        db_session.add(cat)
        await db_session.flush()

        l = _make_lesson(cat.id, "quena", "Quena Lección")
        u = _make_user("quena_weekly@example.com", "quenista_semana")
        db_session.add_all([l, u])
        await db_session.flush()

        # Práctica vieja (2 semanas atrás)
        old_date = datetime.now(UTC) - timedelta(days=14)
        s_old = _make_session(u.id, l.id, 100.0, old_date)

        # Práctica de esta semana
        now = datetime.now(UTC)
        s_recent = _make_session(u.id, l.id, 75.0, now)
        db_session.add_all([s_old, s_recent])
        await db_session.commit()

        # Weekly solo debe contar la práctica de esta semana
        res_weekly = await get_leaderboard(
            db=db_session, user_id=u.id, instrument="quena", scope="weekly"
        )
        assert len(res_weekly.items) == 1
        weekly_xp = res_weekly.items[0].xp

        # All-time suma ambas prácticas
        res_all = await get_leaderboard(
            db=db_session, user_id=u.id, instrument="quena", scope="all_time"
        )
        assert len(res_all.items) == 1
        all_time_xp = res_all.items[0].xp
        assert all_time_xp > weekly_xp

    async def test_user_rank_calculation(self, db_session: AsyncSession):
        cat = _make_category()
        db_session.add(cat)
        await db_session.flush()

        l = _make_lesson(cat.id, "quena", "Quena Escala")
        u_top = _make_user("top@example.com", "top_player")
        u_mid = _make_user("mid@example.com", "mid_player")
        u_idle = _make_user("idle@example.com", "idle_player")
        db_session.add_all([l, u_top, u_mid, u_idle])
        await db_session.flush()

        now = datetime.now(UTC)
        db_session.add(_make_session(u_top.id, l.id, 100.0, now))
        db_session.add(_make_session(u_mid.id, l.id, 80.0, now))
        await db_session.commit()

        # u_top tiene rank 1
        res_top = await RankingService.get_leaderboard(
            db=db_session, instrument="quena", scope="weekly", user_id=u_top.id
        )
        assert res_top.user_rank == 1

        # u_mid tiene rank 2
        res_mid = await RankingService.get_leaderboard(
            db=db_session, instrument="quena", scope="weekly", user_id=u_mid.id
        )
        assert res_mid.user_rank == 2

        # u_idle no tiene prácticas -> user_rank None ("Sin clasificar")
        res_idle = await RankingService.get_leaderboard(
            db=db_session, instrument="quena", scope="weekly", user_id=u_idle.id
        )
        assert res_idle.user_rank is None

    async def test_user_rank_when_outside_top_limit(self, db_session: AsyncSession):
        cat = _make_category()
        db_session.add(cat)
        await db_session.flush()

        l = _make_lesson(cat.id, "quena", "Quena Escala Limit")
        u_top = _make_user("top_limit@example.com", "top_limit")
        u_second = _make_user("second_limit@example.com", "second_limit")
        db_session.add_all([l, u_top, u_second])
        await db_session.flush()

        now = datetime.now(UTC)
        db_session.add(_make_session(u_top.id, l.id, 100.0, now))
        db_session.add(_make_session(u_second.id, l.id, 75.0, now))
        await db_session.commit()

        # Solicitamos solo limit=1, u_second no está en items (solo u_top)
        res = await get_leaderboard(
            db=db_session,
            instrument="quena",
            scope="weekly",
            limit=1,
            user_id=u_second.id,
        )
        assert len(res.items) == 1
        assert res.items[0].user_id == u_top.id
        # Pero su user_rank se calcula mediante subquery como 2
        assert res.user_rank == 2

        # Prueba con scope="all_time" fuera del límite
        res_all_time = await get_leaderboard(
            db=db_session,
            instrument="quena",
            scope="all_time",
            limit=1,
            user_id=u_second.id,
        )
        assert res_all_time.user_rank == 2

        # Prueba con instrument=None fuera del límite
        res_all_inst = await get_leaderboard(
            db=db_session,
            instrument=None,
            scope="weekly",
            limit=1,
            user_id=u_second.id,
        )
        assert res_all_inst.user_rank == 2

    async def test_seeded_50_users_leaderboard(self, db_session: AsyncSession):
        """Validación de integración requerida: sembrado con 50 usuarios."""
        cat = _make_category()
        db_session.add(cat)
        await db_session.flush()

        lesson = _make_lesson(cat.id, "quena", "Quena 50 Users")
        db_session.add(lesson)
        await db_session.flush()

        now = datetime.now(UTC)
        users = []
        sessions = []
        for i in range(50):
            user = _make_user(f"user50_{i}@example.com", f"user50_{i:02d}")
            users.append(user)
        db_session.add_all(users)
        await db_session.flush()

        # Asignar puntajes escalonados para que cada usuario tenga diferente XP
        for i, user in enumerate(users):
            score = 50.0 + (i * 1.0)  # 50.0 a 99.0
            sessions.append(_make_session(user.id, lesson.id, score, now))

        db_session.add_all(sessions)
        await db_session.commit()

        res = await get_leaderboard(
            db=db_session,
            instrument="quena",
            scope="weekly",
            limit=50,
            user_id=users[49].id,  # el usuario con mayor puntaje
        )

        assert len(res.items) == 50
        assert res.user_rank == 1
        # Verificar que el ranking está estrictamente ordenado en forma descendente
        for idx in range(len(res.items) - 1):
            assert res.items[idx].xp >= res.items[idx + 1].xp
            assert res.items[idx].rank <= res.items[idx + 1].rank


@pytest.mark.asyncio
class TestLeaderboardE2E:
    """Pruebas E2E del endpoint REST GET /api/v1/rankings/leaderboard."""

    async def test_e2e_get_leaderboard_success(self, client: AsyncClient, auth_headers: dict):
        resp = await client.get(
            "/api/v1/rankings/leaderboard?instrument=quena&scope=weekly",
            headers=auth_headers,
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "items" in data
        assert "user_rank" in data
        assert data["instrument"] == "quena"
        assert data["scope"] == "weekly"

    async def test_e2e_legacy_path_success(self, client: AsyncClient, auth_headers: dict):
        resp = await client.get(
            "/api/rankings/leaderboard?instrument=zampona&scope=weekly",
            headers=auth_headers,
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "items" in data
        assert data["instrument"] == "zampona"

    async def test_e2e_invalid_scope_returns_400(self, client: AsyncClient, auth_headers: dict):
        resp = await client.get(
            "/api/v1/rankings/leaderboard?scope=monthly",
            headers=auth_headers,
        )
        assert resp.status_code == 400
        assert resp.json()["detail"] == "Scope válido: weekly, all_time"

    async def test_e2e_invalid_instrument_returns_400(
        self, client: AsyncClient, auth_headers: dict
    ):
        resp = await client.get(
            "/api/v1/rankings/leaderboard?instrument=piano",
            headers=auth_headers,
        )
        assert resp.status_code == 400
        assert "no válido" in resp.json()["detail"]

    async def test_e2e_unauthenticated_returns_401(self, client: AsyncClient):
        resp = await client.get("/api/v1/rankings/leaderboard")
        assert resp.status_code in (401, 403)
