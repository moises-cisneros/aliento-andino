"""
Microservicio ML para Aliento Andino.
Provee endpoints de inferencia acústica y matching semántico offline.
"""

from __future__ import annotations

import math
import time

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(
    title="Aliento Andino ML Service",
    description="Servicio de inferencia acústica y matching semántico",
    version="1.0.0",
)


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str


class FAQQuery(BaseModel):
    query: str
    top_k: int | None = 3


class FAQMatch(BaseModel):
    id: str
    score: float
    question: str
    answer: str


class AcousticBenchmarkRequest(BaseModel):
    instrument: str
    target_hz: float
    detected_hz: float
    tolerance_cents: float | None = 15.0


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
    instrument: str | None = "quena"
    max_tokens: int | None = 128


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
    started = time.perf_counter()
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
            latency_ms=(time.perf_counter() - started) * 1000.0,
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
        latency_ms=(time.perf_counter() - started) * 1000.0,
        status="tuned" if is_tuned else "out_of_tune",
    )


@app.post("/tutor/pedagogical-feedback", response_model=PedagogicalFeedbackResponse)
def pedagogical_feedback(req: PedagogicalFeedbackRequest):
    """Genera recomendaciones pedagógicas estructuradas en español andino para Quena, Zampoña y Tarka."""
    started = time.perf_counter()
    valid_instruments = {"quena", "zampona", "tarka"}
    inst = (req.instrument or "quena").lower()
    if inst not in valid_instruments:
        raise HTTPException(
            status_code=400,
            detail=f"Instrumento '{req.instrument}' no soportado. Debe ser quena, zampona o tarka.",
        )

    lower_prompt = req.prompt.lower()

    # --- Contexto pedagógico específico por instrumento ---
    if inst == "quena":
        if "orificio" in lower_prompt or "digitacion" in lower_prompt:
            feedback = (
                "Asegúrate de sellar herméticamente los 7 orificios con la yema del dedo "
                "para evitar fugas de aire y obtener una nota limpia."
            )
        elif (
            "desafinad" in lower_prompt
            or "cents" in lower_prompt
            or "afinacion" in lower_prompt
        ):
            feedback = (
                "Controla el ángulo del bisel y el quiebre del pulgar para estabilizar la afinación; "
                "un soplo suave y constante sobre la embocadura ayuda a centrar la nota."
            )
        elif (
            "postura" in lower_prompt
            or "hombros" in lower_prompt
            or "espalda" in lower_prompt
        ):
            feedback = (
                "Mantén la espalda erguida y los hombros relajados; "
                "sujeta la quena con pulgares opuestos y dedos planos sobre los orificios."
            )
        else:
            feedback = (
                "¡Buen esfuerzo! Revisa la embocadura y el ángulo del bisel, "
                "y verifica que el sellado de los 7 orificios sea hermético."
            )

    elif inst == "zampona":
        if (
            "desafinad" in lower_prompt
            or "cents" in lower_prompt
            or "afinacion" in lower_prompt
        ):
            feedback = (
                "Mantén un flujo continuo de soplo y cuida el ángulo de incidencia en cada tubo "
                "para estabilizar la afinación."
            )
        elif (
            "postura" in lower_prompt
            or "hombros" in lower_prompt
            or "espalda" in lower_prompt
        ):
            feedback = (
                "Adopta la sujeción bimanual lateral y cuida no ocluir las bocas de los tubos; "
                "mantén los hombros relajados para favorecer una respiración diafragmática fluida."
            )
        elif "ira" in lower_prompt or "arca" in lower_prompt or "alternancia" in lower_prompt:
            feedback = (
                "Practica la alternancia y el diálogo entre las hileras Ira y Arca; "
                "un soplo continuo y bien dirigido es clave para la fluidez melódica."
            )
        else:
            feedback = (
                "¡Buen esfuerzo! Recuerda mantener el flujo continuo de soplo "
                "y practicar la alternancia entre la hilera Ira y la hilera Arca."
            )

    elif inst == "tarka":
        if "orificio" in lower_prompt or "digitacion" in lower_prompt:
            feedback = (
                "Asegúrate de cubrir completamente los 6 orificios de la tarka; "
                "una digitación precisa permite una emisión limpia y un timbre definido."
            )
        elif (
            "desafinad" in lower_prompt
            or "cents" in lower_prompt
            or "afinacion" in lower_prompt
        ):
            feedback = (
                "Mantén una columna de aire firme y constante para estabilizar la afinación; "
                "la embocadura debe favorecer la articulación del timbre rasgado de la tara."
            )
        elif (
            "postura" in lower_prompt
            or "hombros" in lower_prompt
            or "espalda" in lower_prompt
        ):
            feedback = (
                "Sujeta la tarka verticalmente con pulgares opuestos y dedos planos sobre los 6 orificios; "
                "mantén la espalda erguida y los hombros relajados."
            )
        else:
            feedback = (
                "¡Buen esfuerzo! Recuerda mantener una columna de aire firme "
                "y buscar la articulación del timbre rasgado característico de la tara."
            )

    else:
        # Fallback genérico — instrumento no reconocido (no debería llegar aquí por la validación previa)
        feedback = (
            "¡Buen trabajo! Mantén una respiración diafragmática constante, "
            "cuida la postura y practica lentamente para consolidar la técnica."
        )

    return PedagogicalFeedbackResponse(
        feedback=feedback,
        instrument=inst,
        latency_ms=(time.perf_counter() - started) * 1000.0,
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
