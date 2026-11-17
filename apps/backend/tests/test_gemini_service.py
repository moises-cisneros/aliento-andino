"""Tests del servicio de feedback IA (Gemini).

Cubre la construcción del prompt (función pura, sin red) y la degradación
con gracia cuando Vertex AI no está configurado.
"""

from app.config import settings
from app.services import gemini_service
from app.services.gemini_service import _build_prompt

_BASE_KWARGS = dict(
    lesson_title="Escala de Do mayor",
    difficulty="principiante",
    tempo_bpm=90,
    score=87.5,
    correct_notes=18,
    wrong_notes=2,
    missed_notes=0,
    total_notes=20,
    average_tempo=84.0,
    tempo_accuracy=93.3,
    total_time_seconds=42.0,
)


class TestBuildPrompt:
    def test_includes_core_session_data(self):
        prompt = _build_prompt(skill_level="beginner", errors_detail=None, **_BASE_KWARGS)
        assert "Escala de Do mayor" in prompt
        assert "87.5" in prompt
        assert "18/20" in prompt

    def test_instructs_neutral_spanish(self):
        prompt = _build_prompt(skill_level="beginner", errors_detail=None, **_BASE_KWARGS)
        assert "español latinoamericano neutro" in prompt
        # Debe pedir explícitamente evitar regionalismos rioplatenses.
        assert "vos" in prompt

    def test_maps_skill_level_to_spanish(self):
        prompt = _build_prompt(skill_level="advanced", errors_detail=None, **_BASE_KWARGS)
        assert "avanzado" in prompt

    def test_none_skill_level_defaults_to_principiante(self):
        prompt = _build_prompt(skill_level=None, errors_detail=None, **_BASE_KWARGS)
        assert "principiante" in prompt

    def test_note_errors_are_sampled(self):
        errors = [{"expected": "C4", "played": "D4", "position": i} for i in range(20)]
        prompt = _build_prompt(skill_level="beginner", errors_detail=errors, **_BASE_KWARGS)
        assert "Muestra de errores" in prompt
        # Se limita a 10 muestras: pos0..pos9 sí, pos15 no.
        assert "pos0:C4→D4" in prompt
        assert "pos15" not in prompt

    def test_hand_tracking_section(self):
        errors = [
            {
                "type": "hand_tracking",
                "left_hand_pct": 70,
                "right_hand_pct": 30,
                "frames_with_hand_pct": 85,
                "frames_total": 1200,
            }
        ]
        prompt = _build_prompt(skill_level="beginner", errors_detail=errors, **_BASE_KWARGS)
        assert "TRACKING DE MANOS" in prompt
        assert "1200 frames" in prompt

    def test_legacy_dict_errors_supported(self):
        prompt = _build_prompt(
            skill_level="beginner",
            errors_detail={"C4": "D4", "E4": "F4"},
            **_BASE_KWARGS,
        )
        assert "Muestra de errores" in prompt


class TestGenerateFeedbackDegradation:
    async def test_returns_none_when_vertex_not_configured(self, monkeypatch):
        # Sin VERTEX_PROJECT_ID no debe lanzar excepción, solo devolver None.
        monkeypatch.setattr(settings, "vertex_project_id", "")
        result = await gemini_service.generate_practice_feedback(
            skill_level="beginner", errors_detail=None, **_BASE_KWARGS
        )
        assert result is None
