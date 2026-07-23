"""Tests del servicio FCM: batching en lotes de 500 y detección de tokens inválidos."""

import pytest

from app.services import fcm_service

# firebase_admin es dependencia opcional en el entorno de tests.
messaging = pytest.importorskip("firebase_admin.messaging")


class _FakeSendResponse:
    def __init__(self, success):
        self.success = success
        self.exception = None if success else _FakeException()


class _FakeException(Exception):
    code = "UNREGISTERED"


class _FakeMulticastResponse:
    def __init__(self, n_tokens, n_failures=0):
        self.success_count = n_tokens - n_failures
        self.responses = [_FakeSendResponse(True) for _ in range(n_tokens - n_failures)]
        self.responses += [_FakeSendResponse(False) for _ in range(n_failures)]


@pytest.fixture
def force_app_ready(monkeypatch):
    monkeypatch.setattr(fcm_service, "_ensure_app", lambda: True)


async def test_empty_tokens_short_circuits():
    sent, invalid = await fcm_service.send_to_tokens(
        tokens=[], title="t", body="b"
    )
    assert sent == 0
    assert invalid == []


async def test_batches_in_chunks_of_500(force_app_ready, monkeypatch):
    calls = []

    def fake_send(message):
        calls.append(len(message.tokens))
        return _FakeMulticastResponse(len(message.tokens))

    monkeypatch.setattr(messaging, "send_each_for_multicast", fake_send)

    tokens = [f"token-{i}" for i in range(600)]
    sent, invalid = await fcm_service.send_to_tokens(
        tokens=tokens, title="Hola", body="Mundo"
    )

    # 600 tokens -> dos lotes (500 + 100)
    assert calls == [500, 100]
    assert sent == 600
    assert invalid == []


async def test_collects_invalid_tokens_with_correct_index(force_app_ready, monkeypatch):
    def fake_send(message):
        # El último token de cada lote falla con código UNREGISTERED.
        n = len(message.tokens)
        return _FakeMulticastResponse(n, n_failures=1)

    monkeypatch.setattr(messaging, "send_each_for_multicast", fake_send)

    tokens = [f"token-{i}" for i in range(3)]
    sent, invalid = await fcm_service.send_to_tokens(
        tokens=tokens, title="t", body="b"
    )

    assert sent == 2
    assert len(invalid) == 1
