"""Tests del microservicio ML (health, benchmark de pitch y feedback pedagógico)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from server import app

OLD_CONSTANTS = {18.4, 12.5, 45.2}

client = TestClient(app)


def test_health():
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {
        "status": "healthy",
        "service": "aliento-andino-ml",
        "version": "1.0.0",
    }


def _benchmark(**overrides):
    body = {"instrument": "quena", "target_hz": 440.0, "detected_hz": 440.0}
    body.update(overrides)
    return client.post("/pitch/benchmark", json=body)


def test_benchmark_tuned():
    res = _benchmark(instrument="Quena", detected_hz=441.0)
    assert res.status_code == 200
    data = res.json()
    assert data["instrument"] == "quena"
    assert data["target_hz"] == 440.0
    assert data["detected_hz"] == 441.0
    assert data["cents_deviation"] == pytest.approx(3.93, abs=0.01)
    assert data["is_tuned"] is True
    assert data["status"] == "tuned"
    assert data["latency_ms"] >= 0
    assert data["latency_ms"] not in OLD_CONSTANTS


def test_benchmark_out_of_tune():
    res = _benchmark(instrument="zampona", detected_hz=466.16)
    assert res.status_code == 200
    data = res.json()
    assert data["instrument"] == "zampona"
    assert data["cents_deviation"] == pytest.approx(100.0, abs=0.1)
    assert data["is_tuned"] is False
    assert data["status"] == "out_of_tune"
    assert data["latency_ms"] >= 0
    assert data["latency_ms"] not in OLD_CONSTANTS


def test_benchmark_custom_tolerance():
    res = _benchmark(detected_hz=446.0, tolerance_cents=30.0)
    data = res.json()
    assert res.status_code == 200
    assert data["cents_deviation"] == pytest.approx(23.5, abs=0.1)
    assert data["is_tuned"] is True


def test_benchmark_silent():
    res = _benchmark(instrument="tarka", detected_hz=0.0)
    assert res.status_code == 200
    data = res.json()
    assert data["instrument"] == "tarka"
    assert data["cents_deviation"] == 0.0
    assert data["is_tuned"] is False
    assert data["status"] == "silent"
    assert data["latency_ms"] >= 0
    assert data["latency_ms"] not in OLD_CONSTANTS


def test_benchmark_unsupported_instrument():
    res = _benchmark(instrument="guitarra")
    assert res.status_code == 400
    assert "no soportado" in res.json()["detail"]


def test_pedagogical_feedback_valid():
    res = client.post(
        "/tutor/pedagogical-feedback",
        json={"prompt": "Estoy desafinado 30 cents", "instrument": "Tarka"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["instrument"] == "tarka"
    assert data["status"] == "generated"
    assert data["model"]
    assert "embocadura" in data["feedback"] or "columna de aire" in data["feedback"] or "tara" in data["feedback"]
    assert data["latency_ms"] >= 0
    assert data["latency_ms"] not in OLD_CONSTANTS


def test_pedagogical_feedback_default_instrument():
    res = client.post("/tutor/pedagogical-feedback", json={"prompt": "hola"})
    assert res.status_code == 200
    assert res.json()["instrument"] == "quena"


def test_pedagogical_feedback_unsupported_instrument():
    res = client.post(
        "/tutor/pedagogical-feedback",
        json={"prompt": "hola", "instrument": "piano"},
    )
    assert res.status_code == 400
    assert "no soportado" in res.json()["detail"]


# ---------------------------------------------------------------------------
# Tests Tarea E — pedagogical_feedback por instrumento (issue #152)
# ---------------------------------------------------------------------------

PALABRAS_PROHIBIDAS = [
    "acorde", "chord", "polif", "cúpula", "cupula",
    "pelotita", "piano", "teclado", "mano izquierda", "mano derecha",
]


def _feedback_text(prompt: str, instrument: str) -> str:
    """Helper: devuelve el texto de feedback para un instrumento dado."""
    res = client.post(
        "/tutor/pedagogical-feedback",
        json={"prompt": prompt, "instrument": instrument},
    )
    assert res.status_code == 200
    return res.json()["feedback"].lower()


def test_feedback_quena_menciona_orificios_y_bisel():
    """La quena debe mencionar orificios y/o bisel."""
    text = _feedback_text("tengo problemas con la digitacion", "quena")
    assert "orificio" in text or "bisel" in text or "embocadura" in text


def test_feedback_zampona_no_menciona_orificios():
    """La zampoña NUNCA debe mencionar 'orificio'."""
    for prompt in [
        "tengo problemas con la digitacion",
        "estoy desafinado 30 cents",
        "mi postura es incorrecta",
        "hola",
    ]:
        text = _feedback_text(prompt, "zampona")
        assert "orificio" not in text, (
            f"La zampoña no debe mencionar 'orificio'. Prompt: '{prompt}'. Feedback: '{text}'"
        )


def test_feedback_zampona_menciona_ira_arca():
    """La zampoña debe mencionar Ira y/o Arca en algún contexto relevante."""
    text = _feedback_text("hola", "zampona")
    assert "ira" in text or "arca" in text or "soplo" in text or "flujo" in text


def test_feedback_tarka_menciona_tara_y_aire():
    """La tarka debe mencionar 'tara' y/o 'columna de aire'."""
    text = _feedback_text("hola", "tarka")
    assert "tara" in text or "columna de aire" in text or "timbre" in text


def test_feedback_instrumento_desconocido_fallback():
    """Un instrumento desconocido debe devolver 400 (validado antes del fallback)."""
    res = client.post(
        "/tutor/pedagogical-feedback",
        json={"prompt": "hola", "instrument": "guitarra"},
    )
    assert res.status_code == 400
    assert "no soportado" in res.json()["detail"]
    # Verificar que el mensaje de error no contiene palabras prohibidas
    detail = res.json()["detail"].lower()
    for palabra in PALABRAS_PROHIBIDAS:
        assert palabra not in detail, f"Palabra prohibida '{palabra}' en el detalle de error"


def test_feedback_sin_palabras_prohibidas():
    """Ningún output de feedback debe contener palabras prohibidas."""
    casos = [
        ("tengo problemas con la digitacion", "quena"),
        ("estoy desafinado 30 cents", "quena"),
        ("mi postura es incorrecta", "quena"),
        ("hola", "quena"),
        ("tengo problemas", "zampona"),
        ("estoy desafinado", "zampona"),
        ("postura incorrecta", "zampona"),
        ("hola", "zampona"),
        ("tengo problemas con la digitacion", "tarka"),
        ("estoy desafinado", "tarka"),
        ("postura", "tarka"),
        ("hola", "tarka"),
    ]
    for prompt, instrument in casos:
        text = _feedback_text(prompt, instrument)
        for palabra in PALABRAS_PROHIBIDAS:
            assert palabra not in text, (
                f"Palabra prohibida '{palabra}' encontrada en feedback de {instrument}. "
                f"Prompt: '{prompt}'. Feedback: '{text}'"
            )
