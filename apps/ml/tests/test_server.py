"""Tests del microservicio ML (health, benchmark de pitch y feedback pedagógico)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from server import app  # noqa: E402

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
    assert "embocadura" in data["feedback"]
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
