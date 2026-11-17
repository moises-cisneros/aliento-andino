"""Lote 4: desafíos semanales (progreso calculado desde practice_sessions)."""

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import PracticeSession
from app.models.ranking import UserXP
from app.services.ranking_service import get_current_week_monday

pytestmark = pytest.mark.asyncio


def _session(uid: uuid.UUID, score: float, day) -> PracticeSession:
    """Sesión de práctica al mediodía UTC del día dado (lección única)."""
    dt = datetime.combine(day, datetime.min.time()).replace(tzinfo=UTC) + timedelta(hours=12)
    return PracticeSession(
        id=uuid.uuid4(),
        user_id=uid,
        lesson_id=uuid.uuid4(),
        score=score,
        correct_notes=1,
        total_notes=1,
        wrong_notes=0,
        missed_notes=0,
        average_tempo=100.0,
        expected_tempo=100,
        tempo_accuracy=100.0,
        total_time_seconds=120.0,
        completed=True,
        created_at=dt,
    )


class TestWeeklyChallenges:
    async def test_no_data_all_zero(self, client: AsyncClient, auth_headers: dict):
        resp = await client.get("/api/challenges/weekly", headers=auth_headers)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert len(data["challenges"]) == 4
        for c in data["challenges"]:
            assert c["progress"] == 0
            assert c["completed"] is False
        assert 1 <= data["days_remaining"] <= 7

    async def test_progress_counts(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        me = (await client.get("/api/auth/me", headers=auth_headers)).json()
        uid = uuid.UUID(me["id"])
        monday = get_current_week_monday()
        today = datetime.now(UTC).date()
        # Días de esta semana hasta hoy (hasta 4 para no excederse).
        days = [monday + timedelta(days=k) for k in range(4) if monday + timedelta(days=k) <= today]
        # 1 sesión por día; las 2 primeras con 90 (cuentan para "80%+").
        for idx, d in enumerate(days):
            db_session.add(_session(uid, 90.0 if idx < 2 else 50.0, d))
        await db_session.commit()

        resp = await client.get("/api/challenges/weekly", headers=auth_headers)
        assert resp.status_code == 200, resp.text
        ch = {c["key"]: c for c in resp.json()["challenges"]}

        assert ch["days"]["progress"] == min(len(days), 5)
        assert ch["sessions"]["progress"] == min(len(days), 10)
        # lecciones distintas con score>=80 = las 2 primeras (o menos si hay <2 días).
        assert ch["lessons80"]["progress"] == min(2, len(days))

    async def test_xp_challenge_completes_and_caps(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        me = (await client.get("/api/auth/me", headers=auth_headers)).json()
        uid = uuid.UUID(me["id"])
        monday = get_current_week_monday()
        db_session.add(UserXP(user_id=uid, weekly_xp=600, week_start_date=monday))
        await db_session.commit()

        resp = await client.get("/api/challenges/weekly", headers=auth_headers)
        assert resp.status_code == 200, resp.text
        xp = next(c for c in resp.json()["challenges"] if c["key"] == "xp")
        assert xp["progress"] == 500  # capeado al objetivo
        assert xp["completed"] is True

    async def test_stale_weekly_xp_counts_zero(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        # weekly_xp de una semana vieja NO cuenta para el desafío de esta semana.
        me = (await client.get("/api/auth/me", headers=auth_headers)).json()
        uid = uuid.UUID(me["id"])
        old_monday = get_current_week_monday() - timedelta(days=7)
        db_session.add(UserXP(user_id=uid, weekly_xp=999, week_start_date=old_monday))
        await db_session.commit()

        resp = await client.get("/api/challenges/weekly", headers=auth_headers)
        xp = next(c for c in resp.json()["challenges"] if c["key"] == "xp")
        assert xp["progress"] == 0
        assert xp["completed"] is False

    async def test_requires_auth(self, client: AsyncClient):
        resp = await client.get("/api/challenges/weekly")
        assert resp.status_code in (401, 403)
