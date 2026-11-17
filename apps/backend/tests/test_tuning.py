"""Pruebas unitarias y de integración para el módulo de calibración y tolerancias andinas."""

try:
    import pytest
except ImportError:

    class _MockMark:
        @staticmethod
        def asyncio(fn):
            return fn

    class _MockPytest:
        mark = _MockMark()

        @staticmethod
        def raises(expected_exception):
            import contextlib

            @contextlib.contextmanager
            def _ctx():
                class Holder:
                    value = None

                h = Holder()
                try:
                    yield h
                except expected_exception as e:
                    h.value = e
                else:
                    raise AssertionError(
                        f"Expected {expected_exception} but no exception was raised"
                    )

            return _ctx()

    pytest = _MockPytest()
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.services.tuning_service import TuningService


def test_tuning_service_tolerances():
    """Valida que el servicio devuelva tolerancias acústicas para Quena, Zampoña y Tarka."""
    tolerances = TuningService.get_all_tolerances()
    assert len(tolerances) == 3

    instruments = {t.instrument: t for t in tolerances}
    assert "quena" in instruments
    assert "zampona" in instruments
    assert "tarka" in instruments

    assert instruments["quena"].allowed_cents_tolerance == 15.0
    assert instruments["quena"].base_hz == 392.00

    assert instruments["zampona"].allowed_cents_tolerance == 20.0
    assert instruments["tarka"].allowed_cents_tolerance == 25.0


def test_tuning_service_invalid_instrument():
    """Valida que un instrumento no andino lance HTTPException 400."""
    from fastapi import HTTPException

    with pytest.raises(HTTPException) as exc_info:
        TuningService.get_instrument_tolerance("piano")

    assert exc_info.value.status_code == 400
    assert "Instrumento no admitido" in exc_info.value.detail


@pytest.mark.asyncio
async def test_get_tolerances_endpoint():
    """Prueba de integración HTTP para GET /api/v1/tuning/tolerances."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/api/v1/tuning/tolerances")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 3


@pytest.mark.asyncio
async def test_get_single_tolerance_endpoint():
    """Prueba de integración HTTP para GET /api/v1/tuning/tolerances/quena."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/api/v1/tuning/tolerances/quena")
        assert response.status_code == 200
        data = response.json()
        assert data["instrument"] == "quena"
        assert data["allowed_cents_tolerance"] == 15.0

        # Caso de error con instrumento no andino
        err_response = await client.get("/api/v1/tuning/tolerances/guitarra")
        assert err_response.status_code == 400
        assert "Instrumento no admitido" in err_response.json()["detail"]
