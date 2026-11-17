"""Tests para los endpoints nuevos: skill_level, recommended, notifications,
practice session GET, gemini_service mockeado, uploads."""

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Category, Lesson, PracticeSession
from app.models.notification import Notification, NotificationToken
from app.models.user import User

# ============== REGISTER CON SKILL_LEVEL ==============


class TestRegisterWithSkillLevel:
    async def test_register_persists_skill_level(self, client: AsyncClient):
        response = await client.post(
            "/api/auth/register",
            json={
                "email": "skill@example.com",
                "username": "skilluser",
                "full_name": "Skill User",
                "password": "SecurePass123",
                "password_confirm": "SecurePass123",
                "skill_level": "intermediate",
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["user"]["skill_level"] == "intermediate"

    async def test_register_rejects_invalid_skill_level(self, client: AsyncClient):
        response = await client.post(
            "/api/auth/register",
            json={
                "email": "skill@example.com",
                "username": "skilluser",
                "full_name": "Skill User",
                "password": "SecurePass123",
                "password_confirm": "SecurePass123",
                "skill_level": "expert",  # inválido
            },
        )
        assert response.status_code == 422

    async def test_register_without_skill_level_is_null(self, client: AsyncClient):
        response = await client.post(
            "/api/auth/register",
            json={
                "email": "skill@example.com",
                "username": "skilluser",
                "full_name": "Skill User",
                "password": "SecurePass123",
                "password_confirm": "SecurePass123",
            },
        )
        assert response.status_code == 201
        assert response.json()["user"]["skill_level"] is None


# ============== UPDATE PROFILE CON SKILL_LEVEL Y PREFS ==============


class TestUpdateProfile:
    async def test_update_skill_level(self, client: AsyncClient, auth_headers: dict):
        response = await client.put(
            "/api/auth/me",
            headers=auth_headers,
            json={"skill_level": "advanced"},
        )
        assert response.status_code == 200
        assert response.json()["skill_level"] == "advanced"

    async def test_update_notifications_prefs(self, client: AsyncClient, auth_headers: dict):
        response = await client.put(
            "/api/auth/me",
            headers=auth_headers,
            json={
                "notifications_push_enabled": False,
                "notifications_email_enabled": False,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["notifications_push_enabled"] is False
        assert data["notifications_email_enabled"] is False


# ============== /api/lessons/recommended ==============


@pytest.fixture
async def beginner_lessons(db_session: AsyncSession):
    """Crear categoría + 3 lecciones de cada dificultad."""
    cat = Category(id=uuid.uuid4(), name="Test Cat", order=1)
    db_session.add(cat)
    await db_session.flush()

    lessons = []
    for diff in ("principiante", "intermedio", "avanzado"):
        for i in range(3):
            l = Lesson(
                id=uuid.uuid4(),
                category_id=cat.id,
                title=f"{diff}-{i}",
                description="desc",
                difficulty=diff,
                tempo_bpm=80,
                order=i,
                is_active=True,
                total_plays=i * 10,
            )
            db_session.add(l)
            lessons.append(l)
    await db_session.commit()
    return lessons


class TestRecommendedLessons:
    async def test_recommended_filters_by_skill(
        self,
        client: AsyncClient,
        auth_headers: dict,
        test_user: User,
        db_session: AsyncSession,
        beginner_lessons,
    ):
        # Set skill_level=beginner directamente en BD (más confiable que PUT
        # porque db_session y el endpoint pueden usar conexiones distintas en SQLite :memory:)
        from sqlalchemy import update

        await db_session.execute(
            update(User).where(User.id == test_user.id).values(skill_level="beginner")
        )
        await db_session.commit()

        # Verificar via /me que se persistió
        me_resp = await client.get("/api/auth/me", headers=auth_headers)
        assert me_resp.json()["skill_level"] == "beginner", (
            f"skill_level no persistió, got {me_resp.json()['skill_level']}"
        )

        response = await client.get("/api/lessons/recommended?limit=10", headers=auth_headers)
        assert response.status_code == 200
        items = response.json()
        assert len(items) > 0
        for item in items:
            assert item["difficulty"] == "principiante", (
                f"Expected principiante, got {item['difficulty']} in {item['title']}"
            )

    async def test_recommended_without_skill_returns_popular(
        self,
        client: AsyncClient,
        auth_headers: dict,
        beginner_lessons,
    ):
        response = await client.get("/api/lessons/recommended?limit=10", headers=auth_headers)
        assert response.status_code == 200
        # Sin skill_level devuelve cualquier dificultad ordenado por total_plays desc
        items = response.json()
        assert len(items) > 0


# ============== /api/practice/sessions/{id} ==============


class TestGetPracticeSession:
    async def test_submit_persists_background_ai_feedback(
        self,
        client: AsyncClient,
        auth_headers: dict,
        test_user: User,
        db_session: AsyncSession,
        beginner_lessons,
    ):
        from datetime import timedelta

        from sqlalchemy import update

        from app.routers import practice as practice_router

        # El feedback con IA es una función PREMIUM: el usuario debe tener
        # suscripción activa para que el endpoint dispare la tarea de IA.
        await db_session.execute(
            update(User)
            .where(User.id == test_user.id)
            .values(
                subscription_status="premium",
                subscription_expires_at=datetime.now(UTC) + timedelta(days=30),
            )
        )
        await db_session.commit()

        feedback = "Muy buen trabajo. Practicá lentamente la próxima escala."
        with (
            patch.object(practice_router, "async_session", return_value=db_session),
            patch.object(
                practice_router.gemini_service,
                "generate_practice_feedback",
                new=AsyncMock(return_value=feedback),
            ),
        ):
            response = await client.post(
                "/api/practice/submit",
                headers=auth_headers,
                json={
                    "lesson_id": str(beginner_lessons[0].id),
                    "score": 87,
                    "correct_notes": 7,
                    "total_notes": 8,
                    "wrong_notes": 1,
                    "missed_notes": 0,
                    "average_tempo": 60,
                    "total_time_seconds": 20,
                    "errors_detail": [],
                    "completed": True,
                },
            )

        assert response.status_code == 200
        session_id = response.json()["session"]["id"]
        saved = await client.get(f"/api/practice/sessions/{session_id}", headers=auth_headers)
        assert saved.status_code == 200
        assert saved.json()["ai_feedback"] == feedback

    async def test_get_session_returns_ai_feedback(
        self,
        client: AsyncClient,
        auth_headers: dict,
        test_user: User,
        db_session: AsyncSession,
        beginner_lessons,
    ):
        from datetime import timedelta

        from sqlalchemy import update

        # El feedback con IA es premium tanto al generarse como al leerse:
        # el usuario debe tener suscripción activa para recibirlo.
        await db_session.execute(
            update(User)
            .where(User.id == test_user.id)
            .values(
                subscription_status="premium",
                subscription_expires_at=datetime.now(UTC) + timedelta(days=30),
            )
        )
        await db_session.commit()

        lesson = beginner_lessons[0]
        session = PracticeSession(
            id=uuid.uuid4(),
            user_id=test_user.id,
            lesson_id=lesson.id,
            score=85.0,
            correct_notes=8,
            total_notes=10,
            wrong_notes=1,
            missed_notes=1,
            average_tempo=80.0,
            expected_tempo=80,
            tempo_accuracy=100.0,
            total_time_seconds=30.0,
            ai_feedback="Buen trabajo, seguí practicando.",
            completed=True,
        )
        db_session.add(session)
        await db_session.commit()

        response = await client.get(f"/api/practice/sessions/{session.id}", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["ai_feedback"] == "Buen trabajo, seguí practicando."
        assert data["score"] == 85.0

    async def test_get_session_hides_ai_feedback_for_free_user(
        self,
        client: AsyncClient,
        auth_headers: dict,
        test_user: User,
        db_session: AsyncSession,
        beginner_lessons,
    ):
        """Privilegio premium: un usuario sin suscripción no recibe el
        ai_feedback aunque la columna tenga valor (defensa en profundidad)."""
        lesson = beginner_lessons[0]
        session = PracticeSession(
            id=uuid.uuid4(),
            user_id=test_user.id,
            lesson_id=lesson.id,
            score=85.0,
            correct_notes=8,
            total_notes=10,
            wrong_notes=1,
            missed_notes=1,
            average_tempo=80.0,
            expected_tempo=80,
            tempo_accuracy=100.0,
            total_time_seconds=30.0,
            ai_feedback="Feedback que NO debería ver un usuario gratis.",
            completed=True,
        )
        db_session.add(session)
        await db_session.commit()

        response = await client.get(f"/api/practice/sessions/{session.id}", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        # El test_user por defecto es free → ai_feedback oculto.
        assert data["ai_feedback"] is None
        assert data["score"] == 85.0

    async def test_get_session_404_if_not_owner(
        self,
        client: AsyncClient,
        auth_headers: dict,
        db_session: AsyncSession,
        beginner_lessons,
    ):
        # Crear sesión de OTRO usuario
        other = User(
            id=uuid.uuid4(),
            email="other@example.com",
            username="other",
            full_name="Other",
            hashed_password="x",
        )
        db_session.add(other)
        await db_session.flush()
        session = PracticeSession(
            id=uuid.uuid4(),
            user_id=other.id,
            lesson_id=beginner_lessons[0].id,
            score=50.0,
            correct_notes=5,
            total_notes=10,
            wrong_notes=3,
            missed_notes=2,
            average_tempo=70.0,
            expected_tempo=80,
            tempo_accuracy=88.0,
            total_time_seconds=40.0,
            completed=False,
        )
        db_session.add(session)
        await db_session.commit()

        response = await client.get(f"/api/practice/sessions/{session.id}", headers=auth_headers)
        assert response.status_code == 404


# ============== /api/notifications ==============


class TestNotifications:
    async def test_list_empty(self, client: AsyncClient, auth_headers: dict):
        response = await client.get("/api/notifications", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["items"] == []
        assert data["unread_count"] == 0

    async def test_unread_count(
        self,
        client: AsyncClient,
        auth_headers: dict,
        test_user: User,
        db_session: AsyncSession,
    ):
        # Crear 2 unread + 1 read
        for _ in range(2):
            db_session.add(
                Notification(
                    user_id=test_user.id,
                    type="like",
                    title="t",
                    body="b",
                    is_read=False,
                )
            )
        db_session.add(
            Notification(
                user_id=test_user.id,
                type="like",
                title="t",
                body="b",
                is_read=True,
            )
        )
        await db_session.commit()

        response = await client.get("/api/notifications/unread-count", headers=auth_headers)
        assert response.status_code == 200
        assert response.json()["unread_count"] == 2

    async def test_mark_all_read(
        self,
        client: AsyncClient,
        auth_headers: dict,
        test_user: User,
        db_session: AsyncSession,
    ):
        for _ in range(3):
            db_session.add(
                Notification(
                    user_id=test_user.id,
                    type="follow",
                    title="t",
                    body="b",
                )
            )
        await db_session.commit()

        response = await client.post("/api/notifications/mark-all-read", headers=auth_headers)
        assert response.status_code == 200

        # Confirmar
        count_resp = await client.get("/api/notifications/unread-count", headers=auth_headers)
        assert count_resp.json()["unread_count"] == 0

    async def test_register_token(
        self, client: AsyncClient, auth_headers: dict, db_session: AsyncSession
    ):
        response = await client.post(
            "/api/notifications/register-token",
            headers=auth_headers,
            json={"token": "fcm-test-token-abc", "platform": "android"},
        )
        assert response.status_code == 200

        # Verificar en BD
        result = await db_session.execute(
            select(NotificationToken).where(NotificationToken.token == "fcm-test-token-abc")
        )
        assert result.scalar_one_or_none() is not None


# ============== GEMINI SERVICE (MOCK) ==============


class TestGeminiService:
    async def test_generate_feedback_returns_text(self):
        """Mockea la llamada a Gemini y verifica que el wrapper procesa bien la respuesta."""
        from app.services import gemini_service

        # Simular vertex_project_id presente para evitar el early return
        with patch.object(gemini_service.settings, "vertex_project_id", "test"):
            mock_response = type("R", (), {"text": "Excelente práctica."})()
            mock_aio = AsyncMock()
            mock_aio.models.generate_content.return_value = mock_response
            mock_client = type("C", (), {"aio": mock_aio})()

            with patch("google.genai.Client", return_value=mock_client):
                result = await gemini_service.generate_practice_feedback(
                    skill_level="beginner",
                    lesson_title="Test",
                    difficulty="principiante",
                    tempo_bpm=80,
                    score=85.0,
                    correct_notes=8,
                    wrong_notes=1,
                    missed_notes=1,
                    total_notes=10,
                    average_tempo=80.0,
                    tempo_accuracy=100.0,
                    total_time_seconds=30.0,
                )
            assert result == "Excelente práctica."
            prompt = mock_aio.models.generate_content.call_args.kwargs["contents"]
            config = mock_aio.models.generate_content.call_args.kwargs["config"]
            assert "español latinoamericano neutro" in prompt
            assert 'Evita regionalismos como "che", "vos"' in prompt
            assert "Máximo 3 oraciones cortas y 45 palabras" in prompt
            assert config.max_output_tokens == 120
            assert config.thinking_config.thinking_budget == 0

    async def test_generate_feedback_returns_none_when_unconfigured(self):
        """Si VERTEX_PROJECT_ID está vacío, devuelve None silenciosamente."""
        from app.services import gemini_service

        with patch.object(gemini_service.settings, "vertex_project_id", ""):
            result = await gemini_service.generate_practice_feedback(
                skill_level=None,
                lesson_title="x",
                difficulty="x",
                tempo_bpm=60,
                score=0.0,
                correct_notes=0,
                wrong_notes=0,
                missed_notes=0,
                total_notes=0,
                average_tempo=0.0,
                tempo_accuracy=0.0,
                total_time_seconds=0.0,
            )
            assert result is None


# ============== UPLOADS (MOCK) ==============


class TestUploads:
    async def test_upload_rejects_invalid_folder(self, client: AsyncClient, auth_headers: dict):
        files = {"file": ("test.png", b"fake-png-content", "image/png")}
        response = await client.post(
            "/api/uploads/media?folder=evil",
            headers=auth_headers,
            files=files,
        )
        assert response.status_code == 400

    async def test_upload_rejects_bad_content_type(self, client: AsyncClient, auth_headers: dict):
        # Mockear el upload a GCS para evitar la llamada real
        with patch(
            "app.services.storage_service.upload_media",
            new=AsyncMock(side_effect=ValueError("Tipo de archivo no permitido")),
        ):
            files = {"file": ("test.exe", b"fake-exe", "application/octet-stream")}
            response = await client.post(
                "/api/uploads/media?folder=posts",
                headers=auth_headers,
                files=files,
            )
            assert response.status_code == 400

    async def test_upload_success_mocked(self, client: AsyncClient, auth_headers: dict):
        with patch(
            "app.services.storage_service.upload_media",
            new=AsyncMock(return_value="https://example.com/test.png"),
        ):
            files = {"file": ("test.png", b"fake-content", "image/png")}
            response = await client.post(
                "/api/uploads/media?folder=posts",
                headers=auth_headers,
                files=files,
            )
            assert response.status_code == 200
            assert response.json()["url"] == "https://example.com/test.png"
