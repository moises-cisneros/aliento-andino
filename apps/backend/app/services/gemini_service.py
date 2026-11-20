"""Cliente de Gemini via Vertex AI para generar feedback IA en sesiones de práctica.

Filosofía: una llamada por sesión, post-mortem. NO se usa en el camino crítico
del request — se ejecuta como background task para no bloquear la respuesta.
"""

import asyncio
import logging
import os
from pathlib import Path

from app.config import settings

logger = logging.getLogger(__name__)

# Configurar credentials de Google al importar este módulo.
# El path en .env es relativo a backend/, lo resolvemos absoluto.
if settings.google_application_credentials:
    _cred_path = Path(settings.google_application_credentials)
    if not _cred_path.is_absolute():
        _cred_path = Path(__file__).resolve().parent.parent.parent / _cred_path
    if _cred_path.exists():
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(_cred_path)
    else:
        logger.warning("Credenciales Gemini no encontradas en %s", _cred_path)


def _build_prompt(
    *,
    skill_level: str | None,
    lesson_title: str,
    difficulty: str,
    tempo_bpm: int,
    score: float,
    correct_notes: int,
    wrong_notes: int,
    missed_notes: int,
    total_notes: int,
    average_tempo: float,
    tempo_accuracy: float,
    total_time_seconds: float,
    errors_detail: list | dict | None,
    instrument: str = "quena",
) -> str:
    """Construir el prompt de feedback personalizado con ergonomía andina contextualizada."""
    nivel_es = {
        "beginner": "principiante",
        "intermediate": "intermedio",
        "advanced": "avanzado",
    }.get(skill_level or "", "principiante")

    errors_summary = ""
    posture_tracking_summary = ""
    posture_tracking_instruction = ""

    # Ergonomía andina contextualizada según instrumento
    inst = (instrument or "quena").lower()
    if inst == "zampona":
        ergonomia_andina = (
            "sujeción bimanual lateral con ambas manos, sin ocluir las bocas de los tubos"
        )
    else:
        # quena y tarka comparten sujeción vertical
        ergonomia_andina = (
            "sujeción vertical con pulgares opuestos y dedos planos sobre los orificios"
        )

    if errors_detail:
        # errors_detail puede ser list (mobile actual) o dict (legacy).
        if isinstance(errors_detail, list):
            note_errors = []
            hand_entry = None
            for item in errors_detail:
                if not isinstance(item, dict):
                    continue
                if item.get("type") == "hand_tracking":
                    hand_entry = item
                else:
                    note_errors.append(item)

            # Muestra de errores de nota (máx 10)
            if note_errors:
                sample = note_errors[:10]
                pieces = []
                for e in sample:
                    expected = e.get("expected", "?")
                    played = e.get("played", "?")
                    pos = e.get("position", "?")
                    pieces.append(f"pos{pos}:{expected}→{played}")
                errors_summary = "\nMuestra de errores: " + ", ".join(pieces)

            # Sección de tracking postural
            if hand_entry:
                detection_pct = hand_entry.get("frames_with_hand_pct", 0)
                frames_total = hand_entry.get("frames_total", 0)
                flat_pct = hand_entry.get("fingers_flat_pct")
                posture_tracking_summary = (
                    f"\n\nTRACKING POSTURAL (cámara, {frames_total} frames):"
                    f"\n- Frames con detección de postura: {detection_pct}%"
                )
                # Postura: curvatura de los dedos (cuando viene del análisis).
                if flat_pct is not None:
                    posture_tracking_summary += (
                        f"\n- Dedos planos (poca curvatura): {flat_pct}% del tiempo"
                    )
                posture_tracking_instruction = (
                    "\nSi la detección postural es baja, sugiere ajustar la postura frente a la cámara."
                )
                if flat_pct is not None and flat_pct >= 40:
                    posture_tracking_instruction += (
                        f" Los dedos estuvieron planos buena parte del tiempo: "
                        f"recomienda adoptar la {ergonomia_andina}."
                    )
        elif isinstance(errors_detail, dict):
            sample = list(errors_detail.items())[:10]
            if sample:
                errors_summary = "\nMuestra de errores: " + ", ".join(f"{k}={v}" for k, v in sample)

    return f"""Eres un profesor de instrumentos de viento andinos (Quena, Zampoña y Tarka) cercano y motivador. Escribe en español latinoamericano neutro.
Evita regionalismos como "che", "vos", "mirá", "dale", "laburo", "seguí" o "practicá".
Acabas de revisar una sesión de práctica de un alumno {nivel_es}.

DATOS DE LA SESIÓN:
- Lección: {lesson_title} (dificultad: {difficulty}, tempo objetivo: {tempo_bpm} BPM)
- Puntuación: {score:.1f}/100
- Notas correctas: {correct_notes}/{total_notes}
- Notas erróneas: {wrong_notes}
- Notas omitidas: {missed_notes}
- Tempo promedio del alumno: {average_tempo:.1f} BPM
- Precisión de tempo: {tempo_accuracy:.1f}%
- Duración total: {total_time_seconds:.1f} segundos{errors_summary}{posture_tracking_summary}

INSTRUCCIONES:
1. Empieza felicitando el avance con una frase breve.
2. Si hubo errores, incluye solo una recomendación simple y positiva para mejorar; si fue perfecto, invita a continuar avanzando.
3. Cierra con una frase motivadora y concreta.{posture_tracking_instruction}

Máximo 3 oraciones cortas y 45 palabras en total. Sin emojis, sin viñetas y sin párrafos separados.
"""


async def generate_practice_feedback(
    *,
    skill_level: str | None,
    lesson_title: str,
    difficulty: str,
    tempo_bpm: int,
    score: float,
    correct_notes: int,
    wrong_notes: int,
    missed_notes: int,
    total_notes: int,
    average_tempo: float,
    tempo_accuracy: float,
    total_time_seconds: float,
    errors_detail: list | dict | None = None,
    instrument: str = "quena",
) -> str | None:
    """Generar el feedback IA. Retorna None si falla (no bloquea al usuario)."""
    if not settings.vertex_project_id:
        logger.info("VERTEX_PROJECT_ID no configurado, salteando feedback IA")
        return None

    try:
        # Import diferido — evita costo al arrancar la app si no se usa.
        from google import genai
        from google.genai import types

        client = genai.Client(
            vertexai=True,
            project=settings.vertex_project_id,
            location=settings.vertex_location,
        )

        prompt = _build_prompt(
            skill_level=skill_level,
            lesson_title=lesson_title,
            difficulty=difficulty,
            tempo_bpm=tempo_bpm,
            score=score,
            correct_notes=correct_notes,
            wrong_notes=wrong_notes,
            missed_notes=missed_notes,
            total_notes=total_notes,
            average_tempo=average_tempo,
            tempo_accuracy=tempo_accuracy,
            total_time_seconds=total_time_seconds,
            errors_detail=errors_detail,
            instrument=instrument,
        )

        config = types.GenerateContentConfig(
            temperature=0.6,
            max_output_tokens=120,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        )

        # Reintentos: la conexión a los endpoints de IA puede resetearse de
        # forma intermitente (ConnectError). Reintentamos con backoff corto.
        attempts = 5
        last_err: Exception | None = None
        for attempt in range(1, attempts + 1):
            try:
                response = await client.aio.models.generate_content(
                    model=settings.gemini_model,
                    contents=prompt,
                    config=config,
                )
                # Registrar tokens reales (no bloquea ni rompe el feedback).
                from app.services import ai_usage_service

                await ai_usage_service.record_from_response(
                    response, kind="practice_feedback", model=settings.gemini_model
                )
                text = (response.text or "").strip()
                if not text:
                    logger.warning("Gemini devolvió texto vacío")
                    return None
                logger.info("Feedback IA generado (len=%d, intento=%d)", len(text), attempt)
                return text
            except Exception as e:
                last_err = e
                logger.warning("Gemini feedback intento %d/%d falló: %s", attempt, attempts, e)
                if attempt < attempts:
                    await asyncio.sleep(0.6 * attempt)

        logger.error(
            "Feedback IA falló tras %d intentos: %s",
            attempts,
            last_err,
            exc_info=True,
        )
        return None

    except Exception as e:
        logger.error("Error generando feedback IA: %s", e, exc_info=True)
        return None
