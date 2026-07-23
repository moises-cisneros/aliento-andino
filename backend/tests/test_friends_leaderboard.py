"""Lote 4: leaderboard de amigos (ranking filtrado por el grafo de follows)."""

import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ranking import UserXP
from app.models.user import User
from app.utils.security import hash_password

pytestmark = pytest.mark.asyncio


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


class TestFriendsLeaderboard:
    async def test_filters_to_followed_and_self(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        u2 = _make_user("f2@example.com", "friendtwo")  # seguido
        u3 = _make_user("f3@example.com", "strangerthree")  # NO seguido, más XP
        db_session.add_all([u2, u3])
        await db_session.commit()

        me = (await client.get("/api/auth/me", headers=auth_headers)).json()

        db_session.add_all([
            UserXP(user_id=uuid.UUID(me["id"]), total_xp=200, level=2),
            UserXP(user_id=u2.id, total_xp=500, level=3),
            UserXP(user_id=u3.id, total_xp=1000, level=5),
        ])
        await db_session.commit()

        # Sigo a u2 (no a u3)
        follow = await client.post(
            f"/api/users/{u2.id}/follow", headers=auth_headers
        )
        assert follow.status_code == 200, follow.text

        resp = await client.get("/api/rankings/friends", headers=auth_headers)
        assert resp.status_code == 200, resp.text
        data = resp.json()

        ids = {e["user_id"] for e in data["leaderboard"]}
        assert me["id"] in ids  # yo aparezco
        assert str(u2.id) in ids  # el seguido aparece
        # El no-seguido NO aparece aunque tenga más XP (clave del filtro social).
        assert str(u3.id) not in ids

        # Orden por XP desc: u2 (500) antes que yo (200).
        order = [e["user_id"] for e in data["leaderboard"]]
        assert order.index(str(u2.id)) < order.index(me["id"])

        # Mi posición entre amigos: 1 con más XP que yo (u2) -> rank 2.
        assert data["my_rank"] == 2
        assert data["my_xp"] == 200

    async def test_includes_self_without_follows(
        self, client: AsyncClient, auth_headers: dict
    ):
        # Sin seguir a nadie y sin fila de XP previa, igual aparezco yo en #1.
        resp = await client.get("/api/rankings/friends", headers=auth_headers)
        assert resp.status_code == 200, resp.text
        data = resp.json()

        me = (await client.get("/api/auth/me", headers=auth_headers)).json()
        ids = {e["user_id"] for e in data["leaderboard"]}
        assert me["id"] in ids
        assert data["my_rank"] == 1

    async def test_requires_auth(self, client: AsyncClient):
        resp = await client.get("/api/rankings/friends")
        assert resp.status_code in (401, 403)
