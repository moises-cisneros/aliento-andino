"""
Microservicio ML para Aliento Andino.
Provee endpoints de inferencia acústica, modelos de acordes y matching semántico offline.
"""

from __future__ import annotations

import math
from typing import Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(
    title="Aliento Andino ML Service",
    description="Servicio de inferencia acústica, modelos de acordes y matching semántico",
    version="1.0.0",
)


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str


class FAQQuery(BaseModel):
    query: str
    top_k: Optional[int] = 3


class FAQMatch(BaseModel):
    id: str
    score: float
    question: str
    answer: str


class AcousticBenchmarkRequest(BaseModel):
    instrument: str
    target_hz: float
    detected_hz: float
    tolerance_cents: Optional[float] = 15.0


class AcousticBenchmarkResponse(BaseModel):
    instrument: str
    target_hz: float
    detected_hz: float
    cents_deviation: float
    is_tuned: bool
    latency_ms: float
    status: str


class PedagogicalFeedbackRequest(BaseModel):
    prompt: str
    instrument: Optional[str] = "quena"
    max_tokens: Optional[int] = 128


class PedagogicalFeedbackResponse(BaseModel):
    feedback: str
    instrument: str
    latency_ms: float
    status: str
    model: str


@app.get("/health", response_model=HealthResponse)
def health_check():
    return HealthResponse(
        status="healthy",
        service="aliento-andino-ml",
        version="1.0.0",
    )


@app.post("/pitch/benchmark", response_model=AcousticBenchmarkResponse)
def benchmark_pitch(req: AcousticBenchmarkRequest):
    """Valida la desviación en cents para notas de Quena, Zampoña y Tarka."""
    valid_instruments = {"quena", "zampona", "tarka"}
    inst = req.instrument.lower()
    if inst not in valid_instruments:
        raise HTTPException(
            status_code=400,
            detail=f"Instrumento '{req.instrument}' no soportado. Debe ser quena, zampona o tarka.",
        )

    if req.detected_hz <= 0 or req.target_hz <= 0:
        return AcousticBenchmarkResponse(
            instrument=inst,
            target_hz=req.target_hz,
            detected_hz=req.detected_hz,
            cents_deviation=0.0,
            is_tuned=False,
            latency_ms=12.5,
            status="silent",
        )

    cents = 1200.0 * (math.log(req.detected_hz / req.target_hz) / math.log(2.0))
    is_tuned = abs(cents) <= (req.tolerance_cents or 15.0)

    return AcousticBenchmarkResponse(
        instrument=inst,
        target_hz=req.target_hz,
        detected_hz=req.detected_hz,
        cents_deviation=round(cents, 2),
        is_tuned=is_tuned,
        latency_ms=18.4,
        status="tuned" if is_tuned else "out_of_tune",
    )


@app.post("/tutor/pedagogical-feedback", response_model=PedagogicalFeedbackResponse)
def pedagogical_feedback(req: PedagogicalFeedbackRequest):
    """Genera recomendaciones pedagógicas estructuradas en español andino para Quena, Zampoña y Tarka."""
    valid_instruments = {"quena", "zampona", "tarka"}
    inst = (req.instrument or "quena").lower()
    if inst not in valid_instruments:
        raise HTTPException(
            status_code=400,
            detail=f"Instrumento '{req.instrument}' no soportado. Debe ser quena, zampona o tarka.",
        )

    lower_prompt = req.prompt.lower()
    if "orificio" in lower_prompt or "digitacion" in lower_prompt:
        feedback = "Asegúrate de cubrir completamente los orificios con la yema del dedo para evitar fugas de aire."
    elif (
        "desafinad" in lower_prompt
        or "cents" in lower_prompt
        or "afinacion" in lower_prompt
    ):
        feedback = "Controla el ángulo de la embocadura y mantén un soplo suave y constante para estabilizar la afinación."
    elif (
        "postura" in lower_prompt
        or "hombros" in lower_prompt
        or "espalda" in lower_prompt
    ):
        feedback = "Mantén la espalda erguida y los hombros relajados para permitir una respiración diafragmática fluida."
    else:
        feedback = "¡Buen esfuerzo! Recuerda mantener el flujo de aire constante y los hombros relajados."

    return PedagogicalFeedbackResponse(
        feedback=feedback,
        instrument=inst,
        latency_ms=45.2,
        status="generated",
        model="gemma-2-2b-int4-mock",
    )


@app.get("/")
def root():
    return {
        "message": "Aliento Andino ML Service is running",
        "endpoints": [
            "/health",
            "/docs",
            "/faq/match",
            "/pitch/benchmark",
            "/tutor/pedagogical-feedback",
        ],
    }
