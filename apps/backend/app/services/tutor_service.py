"""Agente tutor de IA con *function calling* (Gemini vía Vertex AI).

A diferencia del feedback de práctica (`gemini_service`), esto es un AGENTE: no
solo conversa, sino que **usa herramientas**. Algunas herramientas se ejecutan en
el servidor (leer progreso/lecciones) y otras son **acciones de UI** que devuelve
al cliente Flutter para que las ejecute (navegar, resaltar un botón, abrir una
lección). El bucle de razonamiento corre acá; el cliente solo ejecuta las acciones.
"""

import asyncio
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.lesson import Lesson
from app.models.ranking import UserXP
from app.models.user import User

logger = logging.getLogger(__name__)

# Acciones que ejecuta el CLIENTE (Flutter). El servidor solo las recolecta.
_CLIENT_ACTIONS = {"navigate_to", "highlight_element", "start_lesson"}

# Rutas válidas de la app (deben coincidir con core/router/app_router.dart).
_ROUTES = {
    "/lessons": "Inicio de lecciones (escalas, acordes, melodías, ritmo)",
    "/progress": "Mi progreso (estadísticas de práctica)",
    "/rankings": "Rankings / tablas de clasificación",
    "/achievements": "Logros desbloqueables",
    "/social": "Feed de la red social",
    "/social/explore": "Explorar publicaciones populares",
    "/social/search": "Buscar usuarios y publicaciones",
    "/social/saved": "Publicaciones guardadas",
    "/social/create-post": "Crear una publicación",
    "/profile": "Mi perfil",
    "/settings": "Configuración",
}

# Elementos resaltables, agrupados por la pantalla donde EXISTEN. El agente debe
# navegar a esa pantalla antes de resaltar (salvo los nav_*, siempre visibles).
# Estos nombres deben coincidir con los registrados en Flutter (TutorTargets).
_TARGETS_BY_SCREEN = {
    "/social (Feed)": {
        "feed_tabs": "Pestañas Siguiendo/Populares/Reciente",
        "search_button": "Botón de búsqueda (arriba)",
        "create_post_button": "Botón flotante para crear publicación",
        "save_post_button": "Botón de guardar (bookmark) de una publicación",
    },
    "/lessons (Lecciones)": {
        "lessons_search": "Buscador de lecciones",
        "lessons_categories": "Fila de categorías (Escalas/Acordes/Melodías/Ritmo)",
        "first_lesson_card": "Primera lección de la lista (tócala para abrirla)",
    },
    "/rankings (Rankings)": {
        "rankings_tabs": "Pestañas Global / Semanal / Rachas",
    },
    "/progress (Mi progreso)": {
        "progress_stats": "Tarjetas de estadísticas (score, sesiones, racha, lecciones)",
    },
    "/profile (Perfil)": {
        "profile_saved": "Opción 'Guardados' del menú",
        "profile_settings": "Opción 'Configuración' del menú",
    },
}

# Conjunto plano de nombres válidos (para validar/documentar).
_HIGHLIGHT_TARGETS = {
    name: desc for group in _TARGETS_BY_SCREEN.values() for name, desc in group.items()
}


def _system_prompt(current_route: str | None = None) -> str:
    rutas = "\n".join(f"  - {r}: {d}" for r, d in _ROUTES.items())
    targets = "\n".join(
        f"  En {screen}:\n" + "\n".join(f"    - {t}: {d}" for t, d in group.items())
        for screen, group in _TARGETS_BY_SCREEN.items()
    )
    ubicacion = (
        f"\nUBICACIÓN ACTUAL: el usuario está AHORA en la pantalla '{current_route}'."
        if current_route
        else ""
    )
    return f"""Eres "Vivi", el tutor pedagógico de la app Aliento Andino (tutor virtual de instrumentos de viento andinos: Quena, Zampoña y Tarka).
Tu trabajo NO es solo responder: eres un AGENTE que ENSEÑA HACIENDO. Cuando el
usuario pregunta cómo hacer algo, usa tus herramientas para LLEVARLO al lugar
correcto y RESALTAR el elemento, mientras explicas en pocas palabras.

Escribe en español latinoamericano neutro. Evita regionalismos ("che", "vos",
"mirá", "dale"). Sé breve y cálido: 1 a 2 oraciones por respuesta.

PANTALLAS (usa navigate_to con estas rutas exactas):
{rutas}

ELEMENTOS RESALTABLES, POR PANTALLA (usa highlight_element con estos nombres):
{targets}
{ubicacion}

REGLAS IMPORTANTES:
- Si el elemento que necesita el usuario YA está en su pantalla actual, resáltalo
  SIN navegar (no uses navigate_to a la pantalla donde ya está). Podés reconocerlo
  con algo como "Ya estás acá:" antes de resaltar.
- Si el elemento está en OTRA pantalla, navega primero con navigate_to y luego
  resalta. Un elemento de "/lessons" NO se puede resaltar mientras estás en "/social".
- Para "¿dónde está X?" lo más útil es navigate_to a esa pantalla (eso ya lleva
  al usuario ahí) y, si aplica, resaltar un elemento concreto de esa pantalla.
- Resalta SOLO elementos de la lista de arriba; nunca inventes nombres ni rutas.
- Para "¿cómo empiezo a practicar?": navigate_to('/lessons') y highlight_element
  'first_lesson_card' ("Tocá una lección para abrirla y practicar"). Si el usuario
  nombra una lección concreta, usa list_lessons para hallar su id y luego
  start_lesson(id) para abrirla (ahí ya verá el botón 'Iniciar Práctica').
- Para "¿cómo guardo una publicación?": navigate_to('/social') y highlight_element
  'save_post_button'.
- Para recomendar qué practicar: usa get_user_progress y list_lessons.
- Encadena varias acciones cuando haga falta (navegar y luego resaltar).
- Si la petición no es sobre la app, responde breve y reconduce al uso de la app.
"""


def _function_declarations():
    """Declaraciones de herramientas para Gemini (formato google.genai)."""
    from google.genai import types

    return types.Tool(
        function_declarations=[
            types.FunctionDeclaration(
                name="navigate_to",
                description=(
                    "Lleva al usuario a una pantalla de la app. Usa una ruta "
                    "exacta del listado de pantallas."
                ),
                parameters=types.Schema(
                    type="OBJECT",
                    properties={
                        "route": types.Schema(
                            type="STRING",
                            description="Ruta destino, ej. '/lessons'.",
                        ),
                    },
                    required=["route"],
                ),
            ),
            types.FunctionDeclaration(
                name="highlight_element",
                description=(
                    "Resalta visualmente un elemento de la pantalla actual y "
                    "muestra una pista corta al usuario."
                ),
                parameters=types.Schema(
                    type="OBJECT",
                    properties={
                        "target": types.Schema(
                            type="STRING",
                            description="Nombre del elemento a resaltar.",
                        ),
                        "hint": types.Schema(
                            type="STRING",
                            description="Pista breve mostrada junto al elemento.",
                        ),
                    },
                    required=["target", "hint"],
                ),
            ),
            types.FunctionDeclaration(
                name="start_lesson",
                description="Abre y arranca una lección por su id.",
                parameters=types.Schema(
                    type="OBJECT",
                    properties={
                        "lesson_id": types.Schema(type="STRING", description="UUID de la lección."),
                    },
                    required=["lesson_id"],
                ),
            ),
            types.FunctionDeclaration(
                name="list_lessons",
                description=(
                    "Lista lecciones disponibles. Filtra por categoría opcional "
                    "(Escalas, Acordes, Melodías, Ritmo)."
                ),
                parameters=types.Schema(
                    type="OBJECT",
                    properties={
                        "category": types.Schema(
                            type="STRING",
                            description="Categoría opcional; vacío = todas.",
                        ),
                    },
                ),
            ),
            types.FunctionDeclaration(
                name="get_user_progress",
                description=(
                    "Devuelve el progreso del usuario actual (nivel, XP, racha, "
                    "sesiones, nivel de habilidad) para personalizar la enseñanza."
                ),
                parameters=types.Schema(type="OBJECT", properties={}),
            ),
        ]
    )


async def _tool_list_lessons(db: AsyncSession, category: str = "") -> dict:
    """Herramienta servidor: lista lecciones activas (opcionalmente por categoría)."""
    query = select(Lesson).where(Lesson.is_active.is_(True)).order_by(Lesson.order)
    result = await db.execute(query.limit(40))
    lessons = list(result.scalars().all())

    cat = (category or "").strip().lower()
    items = []
    for le in lessons:
        cat_name = le.category.name if le.category else ""
        if cat and cat not in cat_name.lower():
            continue
        items.append(
            {
                "id": str(le.id),
                "title": le.title,
                "category": cat_name,
                "difficulty": le.difficulty,
                "tempo_bpm": le.tempo_bpm,
            }
        )
        if len(items) >= 15:
            break
    return {"lessons": items}


async def _tool_get_user_progress(db: AsyncSession, user: User) -> dict:
    """Herramienta servidor: progreso del usuario actual."""
    xp = (await db.execute(select(UserXP).where(UserXP.user_id == user.id))).scalar_one_or_none()
    return {
        "skill_level": getattr(user, "skill_level", None) or "beginner",
        "level": xp.level if xp else 1,
        "total_xp": xp.total_xp if xp else 0,
        "current_streak": xp.current_streak if xp else 0,
        "total_practice_sessions": xp.total_practice_sessions if xp else 0,
        "total_lessons_completed": xp.total_lessons_completed if xp else 0,
    }


async def _generate(client, contents, config, attempts: int = 3):
    """Llama a Gemini con reintentos ante errores transitorios (ConnectError, etc.)."""
    last_error = None
    for i in range(attempts):
        try:
            return await client.aio.models.generate_content(
                model=settings.gemini_model,
                contents=contents,
                config=config,
            )
        except Exception as e:  # noqa: BLE001 — reintentamos cualquier fallo de red
            last_error = e
            logger.warning("Gemini intento %d/%d falló: %s", i + 1, attempts, e)
            if i < attempts - 1:
                await asyncio.sleep(0.6 * (i + 1))
    raise last_error


def _extract_text(response) -> str:
    """Extrae el texto del response de forma defensiva (puede tener tool calls)."""
    try:
        if response.text:
            return response.text.strip()
    except Exception:
        pass
    parts = []
    for cand in getattr(response, "candidates", None) or []:
        content = getattr(cand, "content", None)
        for part in getattr(content, "parts", None) or []:
            if getattr(part, "text", None):
                parts.append(part.text)
    return " ".join(parts).strip()


_FALLBACK_REPLY = (
    "Soy Vivi, tu tutor de Aliento Andino. Puedo enseñarte a practicar una lección, "
    "usar la red social, ver tu progreso o tus logros. (El tutor con IA necesita "
    "Vertex AI configurado para guiarte paso a paso.)"
)


def _smart_tutor_fallback(message: str, current_route: str | None, user: User) -> dict:
    """Responde preguntas de forma inteligente y guía al usuario ejecutando acciones de UI."""
    msg = message.lower()

    if any(
        k in msg
        for k in ["practic", "leccion", "lección", "cancion", "canción", "aprender", "tocar"]
    ):
        return {
            "reply": "¡Es muy fácil! En la sección de Lecciones puedes elegir cualquier ejercicio de piano y presionar para comenzar tu práctica.",
            "actions": [
                {"tool": "navigate_to", "args": {"route": "/lessons"}},
                {
                    "tool": "highlight_element",
                    "args": {
                        "target": "first_lesson_card",
                        "hint": "Toca aquí para empezar a practicar.",
                    },
                },
            ],
        }
    elif any(
        k in msg for k in ["progres", "estadistic", "estadístic", "racha", "score", "puntaje"]
    ):
        return {
            "reply": "Aquí en 'Mi Progreso' puedes ver tus métricas completas: score promedio, sesiones realizadas y días en racha.",
            "actions": [
                {"tool": "navigate_to", "args": {"route": "/progress"}},
                {
                    "tool": "highlight_element",
                    "args": {"target": "progress_stats", "hint": "Revisa tus métricas clave aquí."},
                },
            ],
        }
    elif any(
        k in msg for k in ["ranking", "posicion", "posición", "tabla", "lider", "líder", "xp"]
    ):
        return {
            "reply": "En el Ranking puedes ver tu posición global y semanal comparada con otros estudiantes de Aliento Andino.",
            "actions": [
                {"tool": "navigate_to", "args": {"route": "/rankings"}},
                {
                    "tool": "highlight_element",
                    "args": {
                        "target": "rankings_tabs",
                        "hint": "Cambia entre el ranking semanal y global.",
                    },
                },
            ],
        }
    elif any(k in msg for k in ["social", "feed", "publica", "publicó", "comunidad", "post"]):
        return {
            "reply": "En la Red Social puedes interactuar con otros pianistas, ver sus avances y publicar tus propias prácticas.",
            "actions": [
                {"tool": "navigate_to", "args": {"route": "/social"}},
                {
                    "tool": "highlight_element",
                    "args": {"target": "create_post_button", "hint": "Publica tu progreso aquí."},
                },
            ],
        }
    elif any(k in msg for k in ["perfil", "configuraci", "configurací", "ajuste", "cuenta"]):
        return {
            "reply": "Te llevo a tu Perfil. Desde aquí puedes modificar tu información y revisar tus grabaciones guardadas.",
            "actions": [{"tool": "navigate_to", "args": {"route": "/profile"}}],
        }
    elif any(k in msg for k in ["hola", "buen", "saludo", "quien eres", "quién eres"]):
        name = getattr(user, "username", "estudiante")
        return {
            "reply": f"¡Hola {name}! Soy Vivi, tu tutora de piano inteligente. ¿En qué parte de la app te gustaría ayuda hoy?",
            "actions": [],
        }
    else:
        return {
            "reply": "¡Hola! Puedo enseñarte cómo practicar lecciones, mostrarte tu progreso o guiarte por la app. ¿Qué deseas explorar?",
            "actions": [{"tool": "navigate_to", "args": {"route": "/lessons"}}],
        }


async def run_tutor_turn(
    db: AsyncSession,
    user: User,
    message: str,
    history: list[dict] | None = None,
    current_route: str | None = None,
    max_steps: int = 6,
) -> dict:
    """Ejecuta un turno del agente tutor.

    Devuelve {"reply": str, "actions": [{"tool", "args"}]}. Las acciones las
    ejecuta el cliente Flutter (navegar, resaltar, abrir lección).
    """
    gemini_key = getattr(settings, "gemini_api_key", None)
    if not settings.vertex_project_id and not gemini_key:
        logger.info("IA no configurada, tutor en modo guiado inteligente")
        return _smart_tutor_fallback(message, current_route, user)

    try:
        from google import genai
        from google.genai import types

        if gemini_key:
            client = genai.Client(api_key=gemini_key)
        else:
            try:
                import google.auth

                creds, _ = google.auth.default(
                    scopes=["https://www.googleapis.com/auth/cloud-platform"]
                )
                client = genai.Client(
                    vertexai=True,
                    project=settings.vertex_project_id,
                    location=settings.vertex_location,
                    credentials=creds,
                )
            except Exception:
                client = genai.Client(
                    vertexai=True,
                    project=settings.vertex_project_id,
                    location=settings.vertex_location,
                )

        contents: list = []
        for turn in (history or [])[-10:]:
            role = "model" if turn.get("role") == "model" else "user"
            text = (turn.get("text") or "").strip()
            if text:
                contents.append(types.Content(role=role, parts=[types.Part(text=text)]))
        contents.append(types.Content(role="user", parts=[types.Part(text=message)]))

        config = types.GenerateContentConfig(
            system_instruction=_system_prompt(current_route),
            tools=[_function_declarations()],
            temperature=0.4,
            max_output_tokens=400,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        )

        actions: list[dict] = []
        response = None

        from app.services import ai_usage_service

        for _ in range(max_steps):
            response = await _generate(client, contents, config)
            # Registrar tokens reales del turno del tutor (cada llamada cuenta).
            await ai_usage_service.record_from_response(
                response, kind="tutor", model=settings.gemini_model, user_id=user.id
            )
            calls = response.function_calls or []
            if not calls:
                break

            # Registrar el turno del modelo (con sus function_call).
            contents.append(response.candidates[0].content)

            tool_parts = []
            for call in calls:
                name = call.name
                args = dict(call.args or {})
                if name == "list_lessons":
                    result = await _tool_list_lessons(db, category=str(args.get("category", "")))
                elif name == "get_user_progress":
                    result = await _tool_get_user_progress(db, user)
                elif name in _CLIENT_ACTIONS:
                    actions.append({"tool": name, "args": args})
                    result = {"status": "dispatched"}
                else:
                    result = {"error": f"herramienta desconocida: {name}"}

                tool_parts.append(
                    types.Part.from_function_response(name=name, response={"result": result})
                )

            contents.append(types.Content(role="user", parts=tool_parts))

        reply = _extract_text(response) if response is not None else ""
        if not reply and actions:
            reply = "Listo, te guío por ahí. 👇"
        if not reply:
            reply = "¿Sobre qué parte de la app querés que te enseñe?"
        return {"reply": reply, "actions": actions}

    except Exception as e:
        logger.warning(
            "Generación Vertex/Gemini inaccesible (%s), usando respuesta guiada inteligente", e
        )
        return _smart_tutor_fallback(message, current_route, user)
