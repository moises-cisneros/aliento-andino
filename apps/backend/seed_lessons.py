"""Script para cargar el catálogo curricular pedagógico andino en la base de datos.

Idempotente y consistente:
  - Crea las 4 categorías pedagógicas andinas:
      1. Embocadura y Sonido
      2. Escalas Andinas
      3. Melodías Tradicionales
      4. Ritmos y Huaynos
  - Purga cualquier categoría o lección obsoleta ajena al dominio andino
    (piano, acordes, manos juntas, Hanon, Für Elise, etc.).
  - Inserta o actualiza un catálogo rico, equilibrado y 100% andino (36 lecciones):
      * 12 lecciones de Quena (embocadura Sol4-Do5, pentatónica menor, El Cóndor Pasa, Ojos Azules, Valicha, Vírgenes del Sol).
      * 12 lecciones de Zampoña / Siku (soplo individual, alternancia Ira y Arca, Kantu de Charazani, Sikuriada de Italaque, Poco a poco, Flor de Retama).
      * 12 lecciones de Tarka (emisión de la tara, escala de 6 orificios de carnaval/anata, temas tradicionales de tarkada).
  - Todas las notas son monofónicas (is_chord=False, chord_group=None).
"""

import asyncio
import sys
import uuid

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session
from app.models.lesson import Category, Lesson, NoteSequence, PracticeSession
from app.models.user import User

# Asegurar encoding UTF-8 para stdout y stderr
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


async def get_admin_user(db: AsyncSession) -> User | None:
    """Obtener el primer usuario admin para asignar como creador."""
    result = await db.execute(select(User).where(User.is_admin == True).limit(1))  # noqa: E712
    return result.scalar_one_or_none()


def note(position: int, n: str, duration: float = 1.0, **kwargs) -> dict:
    """Helper para crear datos de una nota monofónica para instrumento andino."""
    return {
        "position": position,
        "note": n,
        "duration": duration,
        "is_rest": kwargs.get("is_rest", False),
        "finger": kwargs.get("finger"),
        "hand": kwargs.get("hand", "right"),
        "velocity": kwargs.get("velocity", 80),
        "is_chord": False,
        "chord_group": None,
    }


class Seq:
    """Constructor de secuencias monofónicas con posiciones automáticas."""

    def __init__(self) -> None:
        self._notes: list[dict] = []
        self._pos = 1

    def n(self, name: str, dur: float = 1.0) -> "Seq":
        """Una nota monofónica."""
        self._notes.append(note(self._pos, name, dur))
        self._pos += 1
        return self

    def run(self, names: list[str], dur: float = 1.0) -> "Seq":
        """Una secuencia de notas consecutivas."""
        for nm in names:
            self.n(nm, dur)
        return self

    def rest(self, dur: float = 1.0) -> "Seq":
        """Un silencio."""
        self._notes.append(note(self._pos, "REST", dur, is_rest=True))
        self._pos += 1
        return self

    def build(self) -> list[dict]:
        return self._notes


CATEGORIES = [
    {
        "name": "Embocadura y Sonido",
        "description": "Dominio de la columna de aire, embocadura andina y emisión de sonido puro.",
        "icon": "air",
        "order": 1,
    },
    {
        "name": "Escalas Andinas",
        "description": "Escalas pentatónicas menores, mayores y modos tradicionales andinos.",
        "icon": "music_note",
        "order": 2,
    },
    {
        "name": "Melodías Tradicionales",
        "description": "Repertorio ancestral y piezas clásicas del folklore andino.",
        "icon": "queue_music",
        "order": 3,
    },
    {
        "name": "Ritmos y Huaynos",
        "description": "Patrones rítmicos, huaynos festivos, sikuris y tarkadas tradicionales.",
        "icon": "timer",
        "order": 4,
    },
]


def L(meta: dict, notes: list[dict]) -> dict:
    """Empaqueta los metadatos de una lección con su secuencia de notas."""
    return {"lesson": meta, "notes": notes}


# ==============================================================================
# 1. CATEGORÍA: Embocadura y Sonido (9 lecciones: 3 Quena, 3 Zampoña, 3 Tarka)
# ==============================================================================


def get_embocadura_lessons(category_id: uuid.UUID, admin_id: uuid.UUID | None) -> list[dict]:
    base = {
        "category_id": category_id,
        "created_by": admin_id,
        "genre": "Técnica Andina",
    }
    return [
        # ── Quena ──
        L(
            {
                **base,
                "title": "Primeros Soplos en Quena (Sol4 y La4)",
                "description": "Dominio de la embocadura en el bisel de la quena. Emisión de notas fundamentales Sol4 y La4 con columna de aire constante.",
                "instrument": "quena",
                "difficulty": "principiante",
                "tempo_bpm": 70,
                "key_signature": "G",
                "time_signature": "4/4",
                "order": 1,
            },
            Seq().run(["G4", "G4", "A4", "A4"], dur=2.0).run(["G4", "A4", "G4"], dur=2.0).build(),
        ),
        L(
            {
                **base,
                "title": "Claridad de Embocadura (Si4 y Do5)",
                "description": "Control de la obturación de orificios superiores. Emisión limpia de Si4 y Do5 sin soplos de aire residual.",
                "instrument": "quena",
                "difficulty": "principiante",
                "tempo_bpm": 75,
                "key_signature": "G",
                "time_signature": "4/4",
                "order": 2,
            },
            Seq()
            .run(["B4", "B4", "C5", "C5"], dur=1.5)
            .run(["B4", "A4", "G4", "G4"], dur=1.5)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Soplo Continuo y Cambio de Octava",
                "description": "Técnica de aumento de presión y reducción del ángulo del bisel para sobreagudos y octavas limpias en quena.",
                "instrument": "quena",
                "difficulty": "intermedio",
                "tempo_bpm": 80,
                "key_signature": "G",
                "time_signature": "4/4",
                "order": 3,
            },
            Seq()
            .run(["G4", "B4", "D5", "G5"], dur=1.0)
            .run(["G5", "D5", "B4", "G4"], dur=1.0)
            .build(),
        ),
        # ── Zampoña (Siku) ──
        L(
            {
                **base,
                "title": "Ataque de Soplo Individual en Tubos Arca",
                "description": "Emisión perpendicular en los tubos de la hilera Arca (7 tubos: Re4 a Si5). Sonido pleno y resonante.",
                "instrument": "zampona",
                "difficulty": "principiante",
                "tempo_bpm": 70,
                "key_signature": "G",
                "time_signature": "4/4",
                "order": 4,
            },
            Seq().run(["D4", "F#4", "A4", "C5", "E5", "C5", "A4", "F#4", "D4"], dur=1.5).build(),
        ),
        L(
            {
                **base,
                "title": "Ataque de Soplo Individual en Tubos Ira",
                "description": "Ataque con golpe de lengua (sílabas 'tu' / 'ku') en los tubos de la hilera Ira (6 tubos: Mi4 a La5).",
                "instrument": "zampona",
                "difficulty": "principiante",
                "tempo_bpm": 70,
                "key_signature": "G",
                "time_signature": "4/4",
                "order": 5,
            },
            Seq().run(["E4", "G4", "B4", "D5", "F#5", "D5", "B4", "G4", "E4"], dur=1.5).build(),
        ),
        L(
            {
                **base,
                "title": "Alternancia Básica Ira (6) y Arca (7)",
                "description": "El principio del siku trenzado: intercalar notas entre las hileras Ira y Arca para formar la escala continua.",
                "instrument": "zampona",
                "difficulty": "intermedio",
                "tempo_bpm": 80,
                "key_signature": "G",
                "time_signature": "4/4",
                "order": 6,
            },
            Seq()
            .run(["D4", "E4", "F#4", "G4", "A4", "B4", "C5", "D5"], dur=1.0)
            .run(["C5", "B4", "A4", "G4", "F#4", "E4", "D4"], dur=1.0)
            .build(),
        ),
        # ── Tarka ──
        L(
            {
                **base,
                "title": "Emisión de la Tara (Timbre Rasposo)",
                "description": "La tara es el timbre vibrante y rasposo característico de la tarka, logrado mediante mayor presión diafragmática.",
                "instrument": "tarka",
                "difficulty": "principiante",
                "tempo_bpm": 75,
                "key_signature": "A",
                "time_signature": "4/4",
                "order": 7,
            },
            Seq().run(["A4", "A4", "B4", "B4", "C#5", "C#5", "B4", "A4"], dur=1.5).build(),
        ),
        L(
            {
                **base,
                "title": "Ataque Rápido y Presión de Diafragma en Tarka",
                "description": "Articulación incisiva con acento rítmico para mantener la resonancia de la madera en cada nota.",
                "instrument": "tarka",
                "difficulty": "intermedio",
                "tempo_bpm": 85,
                "key_signature": "A",
                "time_signature": "4/4",
                "order": 8,
            },
            Seq()
            .run(["A4", "C#5", "E5", "E5"], dur=1.0)
            .run(["C#5", "B4", "A4", "A4"], dur=1.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Control de Armónicos y Sobretonos en Tarka",
                "description": "Transición precisa entre la octava base y los armónicos superiores sin perder el cuerpo del sonido.",
                "instrument": "tarka",
                "difficulty": "avanzado",
                "tempo_bpm": 90,
                "key_signature": "A",
                "time_signature": "4/4",
                "order": 9,
            },
            Seq().run(["A4", "E5", "A5", "E5", "A4", "B4", "C#5", "E5", "A4"], dur=0.75).build(),
        ),
    ]


# ==============================================================================
# 2. CATEGORÍA: Escalas Andinas (9 lecciones: 3 Quena, 3 Zampoña, 3 Tarka)
# ==============================================================================


def get_escalas_lessons(category_id: uuid.UUID, admin_id: uuid.UUID | None) -> list[dict]:
    base = {
        "category_id": category_id,
        "created_by": admin_id,
        "genre": "Escalas Andinas",
    }
    return [
        # ── Quena ──
        L(
            {
                **base,
                "title": "Escala Pentatónica Menor en Quena",
                "description": "Escala pentatónica menor (Mi - Sol - La - Si - Re - Mi), la matriz armónica y melódica de la cordillera andina.",
                "instrument": "quena",
                "difficulty": "principiante",
                "tempo_bpm": 80,
                "key_signature": "Em",
                "time_signature": "4/4",
                "order": 1,
            },
            Seq()
            .run(["E4", "G4", "A4", "B4", "D5", "E5"], dur=1.0)
            .run(["D5", "B4", "A4", "G4", "E4"], dur=1.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Escala de Sol Mayor Andina en Quena",
                "description": "Recorrido diatónico completo por los 6 orificios frontales y el orificio posterior de octavación.",
                "instrument": "quena",
                "difficulty": "intermedio",
                "tempo_bpm": 85,
                "key_signature": "G",
                "time_signature": "4/4",
                "order": 2,
            },
            Seq()
            .run(["G4", "A4", "B4", "C5", "D5", "E5", "F#5", "G5"], dur=0.75)
            .run(["F#5", "E5", "D5", "C5", "B4", "A4", "G4"], dur=0.75)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Digitaciones y Ornamentos Pentatónicos en Quena",
                "description": "Digitaciones rápidas, semiorificios y ornamentación andina (mordentes y portamentos) en escala de La menor.",
                "instrument": "quena",
                "difficulty": "avanzado",
                "tempo_bpm": 95,
                "key_signature": "Am",
                "time_signature": "4/4",
                "order": 3,
            },
            Seq()
            .run(["A4", "C5", "D5", "E5", "G5", "A5", "G5", "E5"], dur=0.5)
            .run(["D5", "C5", "A4", "B4", "C5", "A4"], dur=0.5)
            .build(),
        ),
        # ── Zampoña (Siku) ──
        L(
            {
                **base,
                "title": "Escala Diatónica Entrelazada en Siku",
                "description": "Coordinación espacial de los labios para enlazar tubos alternos de Ira y Arca sin pausas ni tropiezos.",
                "instrument": "zampona",
                "difficulty": "principiante",
                "tempo_bpm": 80,
                "key_signature": "G",
                "time_signature": "4/4",
                "order": 4,
            },
            Seq()
            .run(["G4", "A4", "B4", "C5", "D5", "E5", "F#5", "G5"], dur=1.0)
            .run(["F#5", "E5", "D5", "C5", "B4", "A4", "G4"], dur=1.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Escala Pentatónica en Zampoña",
                "description": "Salto de tubos diatónicos para aislar la pentafonía andina tradicional en tempo moderado.",
                "instrument": "zampona",
                "difficulty": "intermedio",
                "tempo_bpm": 85,
                "key_signature": "Em",
                "time_signature": "4/4",
                "order": 5,
            },
            Seq()
            .run(["E4", "G4", "A4", "B4", "D5", "E5"], dur=0.75)
            .run(["D5", "B4", "A4", "G4", "E4"], dur=0.75)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Saltos de Terceras e Intervalos en Siku",
                "description": "Entrenamiento de precisión labial con saltos de intervalo dentro de la misma hilera y entre hileras.",
                "instrument": "zampona",
                "difficulty": "avanzado",
                "tempo_bpm": 100,
                "key_signature": "G",
                "time_signature": "4/4",
                "order": 6,
            },
            Seq()
            .run(["G4", "B4", "A4", "C5", "B4", "D5", "C5", "E5"], dur=0.5)
            .run(["D5", "F#5", "E5", "G5", "D5", "B4", "G4"], dur=0.5)
            .build(),
        ),
        # ── Tarka ──
        L(
            {
                **base,
                "title": "Escala de Carnaval de 6 Orificios en Tarka",
                "description": "Digitación correlativa tapando y destapando los 6 orificios frontales cilíndricos de la tarka.",
                "instrument": "tarka",
                "difficulty": "principiante",
                "tempo_bpm": 80,
                "key_signature": "A",
                "time_signature": "2/4",
                "order": 7,
            },
            Seq()
            .run(["A4", "B4", "C#5", "D5", "E5", "F#5", "G5", "A5"], dur=0.75)
            .run(["G5", "F#5", "E5", "D5", "C#5", "B4", "A4"], dur=0.75)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Modo Mayor Festivo en Tarka",
                "description": "Secuencia melódica de apertura de festividad andina con énfasis en notas tónicas y quintas.",
                "instrument": "tarka",
                "difficulty": "intermedio",
                "tempo_bpm": 90,
                "key_signature": "A",
                "time_signature": "2/4",
                "order": 8,
            },
            Seq()
            .run(["A4", "C#5", "E5", "F#5", "E5", "C#5", "B4", "A4"], dur=0.5)
            .run(["E5", "A5", "E5", "A4"], dur=0.75)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Secuencia Melódica de Anata",
                "description": "Desplazamiento ágil en la escala de Anata andina con variaciones de dinámica e intensidad.",
                "instrument": "tarka",
                "difficulty": "avanzado",
                "tempo_bpm": 100,
                "key_signature": "A",
                "time_signature": "2/4",
                "order": 9,
            },
            Seq()
            .run(["A4", "B4", "C#5", "E5", "F#5", "A5"], dur=0.5)
            .run(["F#5", "E5", "C#5", "B4", "C#5", "A4"], dur=0.5)
            .build(),
        ),
    ]


# ==============================================================================
# 3. CATEGORÍA: Melodías Tradicionales (9 lecciones: 3 Quena, 3 Zampoña, 3 Tarka)
# ==============================================================================


def get_melodias_lessons(category_id: uuid.UUID, admin_id: uuid.UUID | None) -> list[dict]:
    base = {
        "category_id": category_id,
        "created_by": admin_id,
    }
    return [
        # ── Quena ──
        L(
            {
                **base,
                "title": "Ojos Azules (Melodía Tradicional)",
                "description": "Emblemático huayno andino atribuido a la memoria popular del altiplano. Melodía pentatónica melancólica.",
                "instrument": "quena",
                "difficulty": "principiante",
                "tempo_bpm": 80,
                "key_signature": "Am",
                "time_signature": "4/4",
                "genre": "Huayno Tradicional",
                "artist": "Tradicional Andino",
                "order": 1,
            },
            Seq()
            .run(["A4", "C5", "B4", "A4", "E5", "E5", "D5", "E5"], dur=1.0)
            .run(["G5", "E5", "D5", "C5", "B4", "A4", "B4", "C5", "A4"], dur=1.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "El Cóndor Pasa (Tema Principal)",
                "description": "La obra cumbre de la música andina peruana, declarada Patrimonio Cultural de la Nación. Movimiento lento y solemne.",
                "instrument": "quena",
                "difficulty": "intermedio",
                "tempo_bpm": 75,
                "key_signature": "Em",
                "time_signature": "4/4",
                "genre": "Música Andina",
                "artist": "Daniel Alomía Robles",
                "order": 2,
            },
            Seq()
            .run(["E4", "G4", "A4", "B4", "B4", "A4", "B4", "D5"], dur=1.0)
            .run(["B4", "A4", "G4", "E4", "G4", "A4", "B4", "A4", "G4", "E4"], dur=1.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Vírgenes del Sol (Fox Incaico)",
                "description": "Famosa danza incaica con pasajes rápidos de adorno y saltos de registro típicos del esplendor andino.",
                "instrument": "quena",
                "difficulty": "avanzado",
                "tempo_bpm": 90,
                "key_signature": "Em",
                "time_signature": "4/4",
                "genre": "Fox Incaico",
                "artist": "Jorge Bravo de Rueda",
                "order": 3,
            },
            Seq()
            .run(["B4", "E5", "F#5", "G5", "F#5", "E5", "D#5", "E5"], dur=0.75)
            .run(["B4", "E5", "G5", "B5", "A5", "G5", "F#5", "E5"], dur=0.75)
            .build(),
        ),
        # ── Zampoña (Siku) ──
        L(
            {
                **base,
                "title": "Kantu de Charazani (Melodía Ancestral)",
                "description": "Melodía ceremonial de la cultura kallawaya de Charazani. Cadencia pausada con notas largas y sonoras.",
                "instrument": "zampona",
                "difficulty": "principiante",
                "tempo_bpm": 80,
                "key_signature": "G",
                "time_signature": "4/4",
                "genre": "Kantu",
                "artist": "Tradicional Kallawaya",
                "order": 4,
            },
            Seq()
            .run(["D4", "G4", "B4", "D5", "D5", "C5"], dur=1.5)
            .run(["B4", "A4", "B4", "G4", "E4", "G4"], dur=1.5)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Sikuriada de Italaque (Melodía de Siku)",
                "description": "Tema clásico de los sikuris de Italaque, cuna del siku aymara. Estructura de diálogo rítmico entre tropas.",
                "instrument": "zampona",
                "difficulty": "intermedio",
                "tempo_bpm": 95,
                "key_signature": "Em",
                "time_signature": "4/4",
                "genre": "Sikuri",
                "artist": "Tradicional Altiplánico",
                "order": 5,
            },
            Seq()
            .run(["E4", "G4", "B4", "D5", "E5", "D5", "B4"], dur=1.0)
            .run(["A4", "B4", "D5", "B4", "G4", "E4"], dur=1.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Flor de Retama (Huayno en Zampoña)",
                "description": "Inolvidable huayno ayacuchano adaptado al siku. Fraseo conmovedor con gran riqueza en dinámicas.",
                "instrument": "zampona",
                "difficulty": "avanzado",
                "tempo_bpm": 90,
                "key_signature": "Em",
                "time_signature": "4/4",
                "genre": "Huayno",
                "artist": "Ricardo Dolorier",
                "order": 6,
            },
            Seq()
            .run(["B4", "E5", "E5", "E5", "D5", "E5", "G5", "E5"], dur=0.75)
            .run(["D5", "B4", "D5", "B4", "A4", "G4", "E4"], dur=0.75)
            .build(),
        ),
        # ── Tarka ──
        L(
            {
                **base,
                "title": "Tarkada Tradicional de Fiesta",
                "description": "Melodía comunitaria interpretada en comparsa para abrir las celebraciones de la tierra.",
                "instrument": "tarka",
                "difficulty": "principiante",
                "tempo_bpm": 85,
                "key_signature": "A",
                "time_signature": "2/4",
                "genre": "Tarkada",
                "artist": "Tradicional Aymara",
                "order": 7,
            },
            Seq()
            .run(["A4", "C#5", "E5", "E5", "F#5", "E5", "C#5"], dur=1.0)
            .run(["B4", "A4", "B4", "C#5", "A4"], dur=1.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Carnaval de Anata (Melodía Central)",
                "description": "La tonada central de la Anata andina, agradecimiento a la Pachamama por los frutos de la tierra.",
                "instrument": "tarka",
                "difficulty": "intermedio",
                "tempo_bpm": 95,
                "key_signature": "A",
                "time_signature": "2/4",
                "genre": "Carnaval Andino",
                "artist": "Tradicional Altiplánico",
                "order": 8,
            },
            Seq()
            .run(["E5", "F#5", "A5", "A5", "F#5", "E5"], dur=0.75)
            .run(["C#5", "E5", "C#5", "B4", "A4", "B4", "C#5", "A4"], dur=0.75)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Huayno de la Siembra en Tarka",
                "description": "Ritmo vigoroso con acentuación en contratiempo que acompaña las labores agrícolas comunitarias.",
                "instrument": "tarka",
                "difficulty": "avanzado",
                "tempo_bpm": 100,
                "key_signature": "A",
                "time_signature": "2/4",
                "genre": "Huayno Tarkada",
                "artist": "Comunidad Andina",
                "order": 9,
            },
            Seq()
            .run(["A4", "A4", "C#5", "E5", "F#5", "E5"], dur=0.5)
            .run(["C#5", "A4", "B4", "C#5", "B4", "A4", "A4"], dur=0.5)
            .build(),
        ),
    ]


# ==============================================================================
# 4. CATEGORÍA: Ritmos y Huaynos (9 lecciones: 3 Quena, 3 Zampoña, 3 Tarka)
# ==============================================================================


def get_ritmos_lessons(category_id: uuid.UUID, admin_id: uuid.UUID | None) -> list[dict]:
    base = {
        "category_id": category_id,
        "created_by": admin_id,
    }
    return [
        # ── Quena ──
        L(
            {
                **base,
                "title": "Valicha (Huayno Cusqueño)",
                "description": "El huayno más célebre del Perú, lleno de alegría andina, ritmo bailable y sincopado en quena.",
                "instrument": "quena",
                "difficulty": "intermedio",
                "tempo_bpm": 105,
                "key_signature": "G",
                "time_signature": "2/4",
                "genre": "Huayno Cusqueño",
                "artist": "Miguel Ángel Hurtado Delgado",
                "order": 1,
            },
            Seq()
            .run(["G4", "B4", "D5", "D5", "B4", "D5", "E5", "D5"], dur=0.5)
            .run(["B4", "A4", "G4", "A4", "B4", "G4", "E4", "G4"], dur=0.5)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Huayno de Fiesta en Quena",
                "description": "Patrón rítmico básico de huayno con notas cortas y apoyo rítmico alegre.",
                "instrument": "quena",
                "difficulty": "principiante",
                "tempo_bpm": 90,
                "key_signature": "G",
                "time_signature": "2/4",
                "genre": "Huayno",
                "artist": "Tradicional Andino",
                "order": 2,
            },
            Seq()
            .run(["G4", "G4", "B4", "D5", "B4", "G4", "A4", "B4", "G4", "G4"], dur=0.75)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Acento Rítmico y Síncopa Andina en Quena",
                "description": "Desarrollo del sentido rítmico con síncopas andinas, silencios y staccatos en registro medio-agudo.",
                "instrument": "quena",
                "difficulty": "avanzado",
                "tempo_bpm": 110,
                "key_signature": "Em",
                "time_signature": "2/4",
                "genre": "Técnica Andina",
                "artist": "Aliento Andino",
                "order": 3,
            },
            Seq()
            .run(["E4", "G4", "A4", "B4", "D5", "E5"], dur=0.5)
            .run(["D5", "B4", "A4", "B4", "A4", "G4", "E4"], dur=0.5)
            .build(),
        ),
        # ── Zampoña (Siku) ──
        L(
            {
                **base,
                "title": "Poco a Poco (Huayno en Siku)",
                "description": "Huayno tradicional andino de compás alegre y cadencia contagiosa, perfecto para iniciarse en el ritmo de siku.",
                "instrument": "zampona",
                "difficulty": "principiante",
                "tempo_bpm": 90,
                "key_signature": "G",
                "time_signature": "2/4",
                "genre": "Huayno Sikuri",
                "artist": "Tradicional Andino",
                "order": 4,
            },
            Seq()
            .run(["G4", "G4", "B4", "B4", "D5", "D5", "B4", "G4"], dur=0.75)
            .run(["A4", "B4", "A4", "G4"], dur=1.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Ritmo de Sikuriada Altiplánica",
                "description": "La pulsación cadenciosa de las tropas de sikuris de Puno y el lago Titicaca a paso marcial andino.",
                "instrument": "zampona",
                "difficulty": "intermedio",
                "tempo_bpm": 100,
                "key_signature": "Em",
                "time_signature": "4/4",
                "genre": "Sikuri",
                "artist": "Tradicional de Puno",
                "order": 5,
            },
            Seq()
            .run(["E4", "B4", "B4", "D5", "E5", "D5", "B4"], dur=0.75)
            .run(["A4", "G4", "A4", "B4", "E4"], dur=1.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Marcha de Sikus y Huaylarsh",
                "description": "Tempo rápido y zapateo enérgico adaptado a la velocidad de respuesta de las cañas de zampoña.",
                "instrument": "zampona",
                "difficulty": "avanzado",
                "tempo_bpm": 115,
                "key_signature": "G",
                "time_signature": "2/4",
                "genre": "Huaylarsh / Sikuri",
                "artist": "Tradicional Andino",
                "order": 6,
            },
            Seq()
            .run(["G4", "B4", "D5", "G5", "F#5", "E5", "D5", "B4"], dur=0.5)
            .run(["C5", "B4", "A4", "G4", "D4", "G4"], dur=0.5)
            .build(),
        ),
        # ── Tarka ──
        L(
            {
                **base,
                "title": "Tarkada Festiva de Carnaval",
                "description": "El ritmo inconfundible de las comparsas de tarkada retumbando con fuerza y júbilo festivo.",
                "instrument": "tarka",
                "difficulty": "intermedio",
                "tempo_bpm": 105,
                "key_signature": "A",
                "time_signature": "2/4",
                "genre": "Tarkada",
                "artist": "Tradicional Oruro",
                "order": 7,
            },
            Seq()
            .run(["A4", "C#5", "E5", "E5", "F#5", "A5"], dur=0.5)
            .run(["F#5", "E5", "C#5", "B4", "A4", "A4"], dur=0.5)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Huayno de Carnaval con Tara",
                "description": "Estructura rítmica de dos por cuatro con acento marcado en el primer tiempo y sonoridad 'tara' plena.",
                "instrument": "tarka",
                "difficulty": "principiante",
                "tempo_bpm": 90,
                "key_signature": "A",
                "time_signature": "2/4",
                "genre": "Huayno con Tarka",
                "artist": "Tradicional Andino",
                "order": 8,
            },
            Seq()
            .run(["A4", "A4", "B4", "C#5", "E5", "C#5"], dur=0.75)
            .run(["B4", "A4", "B4", "A4"], dur=0.75)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Cierre Rítmico de Tarkada (Kacharpaya)",
                "description": "La despedida de la fiesta o kacharpaya en ritmo acelerado y apoteósico con toda la potencia de la tarka.",
                "instrument": "tarka",
                "difficulty": "avanzado",
                "tempo_bpm": 115,
                "key_signature": "A",
                "time_signature": "2/4",
                "genre": "Kacharpaya",
                "artist": "Tradicional Altiplánico",
                "order": 9,
            },
            Seq()
            .run(["A4", "C#5", "E5", "F#5", "A5", "A5"], dur=0.5)
            .run(["F#5", "E5", "C#5", "B4", "A4", "C#5", "A4"], dur=0.5)
            .build(),
        ),
    ]


# ==============================================================================
# SEED PRINCIPAL
# ==============================================================================


async def seed_lessons():
    """Seed pedagógico andino: purga contenido obsoleto e inserta catálogo andino."""
    async with async_session() as db:
        try:
            admin = await get_admin_user(db)
            admin_id = admin.id if admin else None
            if admin_id:
                print(f"[seed] Admin encontrado: {admin.email}")
            else:
                print("[seed] No hay usuario admin. Creando lecciones sin creador.")

            # 1. Purga de categorías obsoletas ajenas al currículo andino
            valid_cat_names = {c["name"] for c in CATEGORIES}
            obsolete_cats_res = await db.execute(
                select(Category.id, Category.name).where(Category.name.notin_(valid_cat_names))
            )
            obsolete_cats = obsolete_cats_res.all()
            if obsolete_cats:
                obs_ids = [c_id for (c_id, _) in obsolete_cats]
                for _, c_name in obsolete_cats:
                    print(f"[seed] Purgando categoría obsoleta: {c_name}")
                obs_lessons_res = await db.execute(
                    select(Lesson.id).where(Lesson.category_id.in_(obs_ids))
                )
                obs_lesson_ids = list(obs_lessons_res.scalars().all())
                if obs_lesson_ids:
                    await db.execute(
                        delete(PracticeSession).where(PracticeSession.lesson_id.in_(obs_lesson_ids))
                    )
                    await db.execute(
                        delete(NoteSequence).where(NoteSequence.lesson_id.in_(obs_lesson_ids))
                    )
                    await db.execute(delete(Lesson).where(Lesson.id.in_(obs_lesson_ids)))
                await db.execute(delete(Category).where(Category.id.in_(obs_ids)))

            await db.flush()

            # 2. Crear u obtener las 4 categorías andinas
            categories: dict[str, uuid.UUID] = {}
            for cat_data in CATEGORIES:
                existing = (
                    await db.execute(select(Category).where(Category.name == cat_data["name"]))
                ).scalar_one_or_none()
                if existing:
                    # Actualizar metadata si cambió
                    existing.description = cat_data["description"]
                    existing.icon = cat_data["icon"]
                    existing.order = cat_data["order"]
                    categories[cat_data["name"]] = existing.id
                else:
                    cat = Category(**cat_data)
                    db.add(cat)
                    await db.flush()
                    categories[cat_data["name"]] = cat.id
                    print(f"[seed] Categoría andina creada: {cat_data['name']}")

            # 3. Construir catálogo de lecciones por categoría
            all_lessons = {
                "Embocadura y Sonido": get_embocadura_lessons(
                    categories["Embocadura y Sonido"], admin_id
                ),
                "Escalas Andinas": get_escalas_lessons(categories["Escalas Andinas"], admin_id),
                "Melodías Tradicionales": get_melodias_lessons(
                    categories["Melodías Tradicionales"], admin_id
                ),
                "Ritmos y Huaynos": get_ritmos_lessons(categories["Ritmos y Huaynos"], admin_id),
            }

            valid_titles = set()
            for lessons in all_lessons.values():
                for l_item in lessons:
                    valid_titles.add(l_item["lesson"]["title"])

            # Purga de lecciones con instrumentos no andinos o títulos que ya no pertenecen al catálogo nuevo
            stale_lessons_res = await db.execute(
                select(Lesson.id, Lesson.title).where(
                    (Lesson.instrument.notin_(["quena", "zampona", "tarka"]))
                    | (Lesson.title.notin_(valid_titles))
                )
            )
            stale_lessons = stale_lessons_res.all()
            if stale_lessons:
                stale_ids = [l_id for (l_id, _) in stale_lessons]
                for _, l_title in stale_lessons:
                    print(f"[seed] Purgando lección obsoleta: {l_title}")
                await db.execute(
                    delete(PracticeSession).where(PracticeSession.lesson_id.in_(stale_ids))
                )
                await db.execute(delete(NoteSequence).where(NoteSequence.lesson_id.in_(stale_ids)))
                await db.execute(delete(Lesson).where(Lesson.id.in_(stale_ids)))

            await db.flush()

            added = 0
            updated = 0
            skipped = 0
            total_notes = 0

            for cat_name, lessons in all_lessons.items():
                for lesson_data in lessons:
                    meta = lesson_data["lesson"]
                    title = meta["title"]
                    exists = (
                        await db.execute(select(Lesson).where(Lesson.title == title))
                    ).scalar_one_or_none()

                    if exists:
                        # Actualizar metadatos
                        changed = False
                        for field, val in meta.items():
                            if getattr(exists, field, None) != val:
                                setattr(exists, field, val)
                                changed = True
                        if changed:
                            updated += 1
                        else:
                            skipped += 1

                        # Asegurar secuencia de notas
                        await db.execute(
                            delete(NoteSequence).where(NoteSequence.lesson_id == exists.id)
                        )
                        for note_data in lesson_data["notes"]:
                            db.add(NoteSequence(lesson_id=exists.id, **note_data))
                            total_notes += 1
                        continue

                    lesson = Lesson(**meta)
                    db.add(lesson)
                    await db.flush()

                    for note_data in lesson_data["notes"]:
                        db.add(NoteSequence(lesson_id=lesson.id, **note_data))
                        total_notes += 1

                    added += 1
                    print(
                        f"  [seed] Lección andina nueva: {title} ({len(lesson_data['notes'])} notas)"
                    )

            await db.commit()
            print(
                f"\n[seed] Catálogo andino completado: {added} nuevas, {updated} actualizadas, "
                f"{skipped} sin cambios, {total_notes} notas registradas."
            )

        except Exception as e:
            await db.rollback()
            print(f"[seed] ERROR: {e}")
            raise


if __name__ == "__main__":
    asyncio.run(seed_lessons())
