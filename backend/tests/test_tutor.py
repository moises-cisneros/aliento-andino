"""Agente tutor de IA: endpoint y herramientas de servidor."""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.user import User
from app.services import tutor_service


class TestTutorEndpoint:
    async def test_chat_degraded_without_vertex(
        self, client: AsyncClient, auth_headers: dict, monkeypatch
    ):
        # Sin Vertex configurado, el tutor responde en modo degradado (sin acciones)
        # pero el endpoint nunca falla.
        monkeypatch.setattr(settings, "vertex_project_id", "")
        resp = await client.post(
            "/api/tutor/chat",
            headers=auth_headers,
            json={"message": "¿cómo practico una lección?"},
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert isinstance(body["reply"], str) and body["reply"]
        assert body["actions"] == []

    async def test_chat_acepta_current_route(
        self, client: AsyncClient, auth_headers: dict, monkeypatch
    ):
        # El endpoint acepta la pantalla actual (contexto para no navegar de más).
        monkeypatch.setattr(settings, "vertex_project_id", "")
        resp = await client.post(
            "/api/tutor/chat",
            headers=auth_headers,
            json={"message": "¿dónde guardo?", "current_route": "/social"},
        )
        assert resp.status_code == 200, resp.text

    async def test_chat_requires_auth(self, client: AsyncClient):
        resp = await client.post("/api/tutor/chat", json={"message": "hola"})
        assert resp.status_code == 401

    async def test_chat_valida_mensaje_vacio(
        self, client: AsyncClient, auth_headers: dict
    ):
        resp = await client.post(
            "/api/tutor/chat", headers=auth_headers, json={"message": ""}
        )
        assert resp.status_code == 422


class TestTutorServerTools:
    async def test_get_user_progress_tool(
        self, db_session: AsyncSession, test_user: User
    ):
        result = await tutor_service._tool_get_user_progress(db_session, test_user)
        assert "level" in result
        assert "skill_level" in result
        assert "total_practice_sessions" in result

    async def test_list_lessons_tool_returns_list(self, db_session: AsyncSession):
        result = await tutor_service._tool_list_lessons(db_session)
        assert "lessons" in result
        assert isinstance(result["lessons"], list)

    def test_routes_and_targets_are_consistent(self):
        # Las rutas y elementos resaltables existen y no están vacíos: el prompt
        # del sistema se construye a partir de ellos.
        assert tutor_service._ROUTES
        assert tutor_service._HIGHLIGHT_TARGETS
        assert "/lessons" in tutor_service._ROUTES
        prompt = tutor_service._system_prompt()
        assert "/lessons" in prompt
        assert "first_lesson_card" in prompt
        assert "save_post_button" in prompt
