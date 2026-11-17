"""Script para cargar datos iniciales de lecciones en la base de datos.

Idempotente y ADITIVO: crea las categorías que falten e inserta solo las
lecciones cuyo título aún no existe. Es seguro re-ejecutarlo (lo hace el deploy
en cada release) para agregar lecciones nuevas sin duplicar las existentes.

El contenido fue recalibrado para ser MÁS EXIGENTE en todos los niveles
(secuencias más largas, mayor rango, más alteraciones, acordes y manos juntas).
Para REGENERAR las notas de lecciones ya existentes (no solo metadata) se usa
`reseed_lessons.py`, que limpia y vuelve a cargar desde cero (solo en local).
"""

import asyncio
import sys
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session
from app.models.lesson import Category, Lesson, NoteSequence
from app.models.user import User

# En el contenedor (docker exec -T) stdout puede no ser UTF-8; sin esto, imprimir
# acentos (títulos como "Frère Jacques") rompía el seed con UnicodeEncodeError y
# abortaba la carga. Forzamos UTF-8 con reemplazo para que nunca falle por logs.
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
    """Helper para crear datos de una nota."""
    return {
        "position": position,
        "note": n,
        "duration": duration,
        "is_rest": kwargs.get("is_rest", False),
        "finger": kwargs.get("finger"),
        "hand": kwargs.get("hand", "right"),
        "velocity": kwargs.get("velocity", 80),
        "is_chord": kwargs.get("is_chord", False),
        "chord_group": kwargs.get("chord_group"),
    }


class Seq:
    """Constructor de secuencias con posiciones y grupos de acorde automáticos.

    Evita los errores de numerar posiciones a mano. El motor de práctica avanza
    por orden de `position`; este builder garantiza posiciones crecientes y
    grupos de acorde correctos (filas separadas con el mismo `chord_group`).
    """

    def __init__(self) -> None:
        self._notes: list[dict] = []
        self._pos = 1
        self._group = 1

    def n(
        self, name: str, dur: float = 1.0, hand: str = "right", finger: int | None = None
    ) -> "Seq":
        """Una nota suelta."""
        self._notes.append(note(self._pos, name, dur, hand=hand, finger=finger))
        self._pos += 1
        return self

    def run(self, names: list[str], dur: float = 1.0, hand: str = "right") -> "Seq":
        """Una corrida de notas sueltas (escala, melodía)."""
        for nm in names:
            self.n(nm, dur, hand=hand)
        return self

    def rest(self, dur: float = 1.0) -> "Seq":
        """Un silencio (el motor lo salta solo)."""
        self._notes.append(note(self._pos, "REST", dur, is_rest=True))
        self._pos += 1
        return self

    def chord(self, names: list[str], dur: float = 2.0, hand: str = "right") -> "Seq":
        """Un acorde: notas simultáneas (mismo chord_group)."""
        g = self._group
        self._group += 1
        for nm in names:
            self._notes.append(note(self._pos, nm, dur, is_chord=True, chord_group=g, hand=hand))
            self._pos += 1
        return self

    def both(self, bass: list[str], melody: list[str], dur: float = 2.0) -> "Seq":
        """Manos juntas: bajo (izquierda) + melodía (derecha) en un solo golpe.

        Se modela como un único `chord_group` con notas hand="left" (bajo) y
        hand="right" (melodía); el motor lo evalúa como un acorde simultáneo.
        """
        g = self._group
        self._group += 1
        for nm in bass:
            self._notes.append(note(self._pos, nm, dur, is_chord=True, chord_group=g, hand="left"))
            self._pos += 1
        for nm in melody:
            self._notes.append(note(self._pos, nm, dur, is_chord=True, chord_group=g, hand="right"))
            self._pos += 1
        return self

    def build(self) -> list[dict]:
        return self._notes


# Atajos de notas para escalas/arpegios reutilizados.
C_MAJOR = ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]
C_MAJOR_DESC = ["C5", "B4", "A4", "G4", "F4", "E4", "D4", "C4"]


# ===================== SEED DATA =====================
#
# Rúbrica de dificultad (estilo flowkey/Yousician), recalibrada MÁS EXIGENTE:
#   principiante: una mano, secuencias más largas (ida y vuelta, ~1-1.5
#                 octavas), pocas alteraciones, tempo 75-95. La octava no se
#                 exige (tolerante).
#   intermedio:   2 octavas, varias alteraciones, acordes simples y primeras
#                 manos juntas, tempo 95-115. La octava ya importa (estricto).
#   avanzado:     arpegios y acordes de séptima, cromatismo, síncopa, saltos
#                 amplios, 2-3 octavas, corcheas, tempo 115-145.
#   experto:      repertorio real (Bach, Beethoven, Chopin), técnica exigente
#                 (Hanon, escalas/arpegios 3-4 octavas), semicorcheas/tresillos,
#                 tempo 130-170, secuencias largas.

CATEGORIES = [
    {
        "name": "Escalas",
        "description": "Practica escalas musicales para mejorar tu técnica",
        "icon": "music_note",
        "order": 1,
    },
    {
        "name": "Acordes",
        "description": "Aprende acordes mayores, menores y progresiones",
        "icon": "piano",
        "order": 2,
    },
    {
        "name": "Melodías",
        "description": "Toca melodías clásicas y populares",
        "icon": "queue_music",
        "order": 3,
    },
    {
        "name": "Ritmo",
        "description": "Mejora tu sentido del ritmo y timing",
        "icon": "timer",
        "order": 4,
    },
]


def L(meta: dict, notes: list[dict]) -> dict:
    """Empaqueta una lección con su secuencia de notas."""
    return {"lesson": meta, "notes": notes}


def get_escalas_lessons(category_id: uuid.UUID, admin_id: uuid.UUID) -> list[dict]:
    """Lecciones de la categoría Escalas (recalibradas, más exigentes)."""
    base = {
        "category_id": category_id,
        "created_by": admin_id,
        "key_signature": "C",
        "genre": "Técnica",
    }
    return [
        # ── Principiante ──
        L(
            {
                **base,
                "title": "Escala de Do Mayor (ida y vuelta)",
                "description": "La escala más básica, ahora completa: sube y baja una octava sin parar. Sin sostenidos ni bemoles.",
                "difficulty": "principiante",
                "tempo_bpm": 80,
                "order": 1,
            },
            Seq().run(C_MAJOR).run(C_MAJOR_DESC[1:]).build(),
        ),
        L(
            {
                **base,
                "title": "Escala de Sol Mayor (ida y vuelta)",
                "key_signature": "G",
                "description": "Sol Mayor tiene un sostenido (F#). Sube y baja cuidando la transición suave entre notas.",
                "difficulty": "principiante",
                "tempo_bpm": 80,
                "order": 2,
            },
            Seq()
            .run(["G3", "A3", "B3", "C4", "D4", "E4", "F#4", "G4"])
            .run(["F#4", "E4", "D4", "C4", "B3", "A3", "G3"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Escala de Fa Mayor (ida y vuelta)",
                "key_signature": "F",
                "description": "Fa Mayor tiene un bemol (Bb). Practica el control en subida y bajada.",
                "difficulty": "principiante",
                "tempo_bpm": 80,
                "order": 3,
            },
            Seq()
            .run(["F4", "G4", "A4", "Bb4", "C5", "D5", "E5", "F5"])
            .run(["E5", "D5", "C5", "Bb4", "A4", "G4", "F4"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Pentatónica mayor de Do (2 octavas)",
                "description": "Cinco notas (C D E G A) repartidas en dos octavas. La base de mucha música popular.",
                "difficulty": "principiante",
                "tempo_bpm": 85,
                "order": 4,
            },
            Seq().run(["C4", "D4", "E4", "G4", "A4", "C5", "D5", "E5", "G5", "A5", "C6"]).build(),
        ),
        L(
            {
                **base,
                "title": "Escala de Do Mayor en saltos de tercera",
                "description": "C-E, D-F, E-G... subir de a terceras te prepara para los arpegios. Más exigente que la escala simple.",
                "difficulty": "principiante",
                "tempo_bpm": 80,
                "order": 5,
            },
            Seq()
            .run(
                [
                    "C4",
                    "E4",
                    "D4",
                    "F4",
                    "E4",
                    "G4",
                    "F4",
                    "A4",
                    "G4",
                    "B4",
                    "A4",
                    "C5",
                    "B4",
                    "D5",
                    "C5",
                ]
            )
            .build(),
        ),
        # ── Intermedio ──
        L(
            {
                **base,
                "title": "Escala de Re Mayor (2 octavas)",
                "key_signature": "D",
                "description": "Dos octavas con dos sostenidos (F#, C#). Cuidá la octava: ahora se exige exacta.",
                "difficulty": "intermedio",
                "tempo_bpm": 100,
                "order": 6,
            },
            Seq()
            .run(
                [
                    "D4",
                    "E4",
                    "F#4",
                    "G4",
                    "A4",
                    "B4",
                    "C#5",
                    "D5",
                    "E5",
                    "F#5",
                    "G5",
                    "A5",
                    "B5",
                    "C#6",
                    "D6",
                ],
                dur=0.5,
            )
            .run(
                [
                    "C#6",
                    "B5",
                    "A5",
                    "G5",
                    "F#5",
                    "E5",
                    "D5",
                    "C#5",
                    "B4",
                    "A4",
                    "G4",
                    "F#4",
                    "E4",
                    "D4",
                ],
                dur=0.5,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Escala de La Mayor (3 sostenidos)",
                "key_signature": "A",
                "description": "La Mayor con F#, C# y G#. Tres alteraciones a dos octavas: buen reto de digitación.",
                "difficulty": "intermedio",
                "tempo_bpm": 100,
                "order": 7,
            },
            Seq()
            .run(
                [
                    "A3",
                    "B3",
                    "C#4",
                    "D4",
                    "E4",
                    "F#4",
                    "G#4",
                    "A4",
                    "B4",
                    "C#5",
                    "D5",
                    "E5",
                    "F#5",
                    "G#5",
                    "A5",
                ],
                dur=0.5,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "La menor armónica",
                "key_signature": "Am",
                "description": "La menor armónica eleva el 7º grado (G#), dando ese color dramático. Atención a la 2ª aumentada F-G#.",
                "difficulty": "intermedio",
                "tempo_bpm": 95,
                "order": 8,
            },
            Seq()
            .run(["A3", "B3", "C4", "D4", "E4", "F4", "G#4", "A4"])
            .run(["G#4", "F4", "E4", "D4", "C4", "B3", "A3"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Escala de Mib Mayor (3 bemoles)",
                "key_signature": "Eb",
                "description": "Mi bemol Mayor (Eb, Ab, Bb). Las tonalidades con bemoles caen muy bien bajo la mano.",
                "difficulty": "intermedio",
                "tempo_bpm": 100,
                "order": 9,
            },
            Seq()
            .run(["Eb4", "F4", "G4", "Ab4", "Bb4", "C5", "D5", "Eb5"])
            .run(["D5", "C5", "Bb4", "Ab4", "G4", "F4", "Eb4"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Escala de Do en movimiento contrario (manos juntas)",
                "description": "Las dos manos parten de Do y se abren en espejo. Tu primera escala a manos juntas.",
                "difficulty": "intermedio",
                "tempo_bpm": 90,
                "order": 10,
            },
            Seq()
            .both(["C3"], ["C5"])
            .both(["B2"], ["D5"])
            .both(["A2"], ["E5"])
            .both(["G2"], ["F5"])
            .both(["F2"], ["G5"])
            .both(["E2"], ["A5"])
            .both(["D2"], ["B5"])
            .both(["C2"], ["C6"])
            .build(),
        ),
        # ── Avanzado ──
        L(
            {
                **base,
                "title": "Escala cromática (2 octavas)",
                "description": "Las doce notas por semitonos, dos octavas a corcheas. Ejercicio de agilidad y paso del pulgar.",
                "difficulty": "avanzado",
                "tempo_bpm": 120,
                "order": 11,
            },
            Seq()
            .run(
                [
                    "C4",
                    "C#4",
                    "D4",
                    "D#4",
                    "E4",
                    "F4",
                    "F#4",
                    "G4",
                    "G#4",
                    "A4",
                    "A#4",
                    "B4",
                    "C5",
                    "C#5",
                    "D5",
                    "D#5",
                    "E5",
                    "F5",
                    "F#5",
                    "G5",
                    "G#5",
                    "A5",
                    "A#5",
                    "B5",
                    "C6",
                ],
                dur=0.25,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Escala de blues en Do (2 octavas)",
                "description": "C, Eb, F, F#, G, Bb a lo largo de dos octavas. Esencial para improvisar con sabor.",
                "difficulty": "avanzado",
                "tempo_bpm": 125,
                "order": 12,
            },
            Seq()
            .run(
                [
                    "C4",
                    "Eb4",
                    "F4",
                    "F#4",
                    "G4",
                    "Bb4",
                    "C5",
                    "Eb5",
                    "F5",
                    "F#5",
                    "G5",
                    "Bb5",
                    "C6",
                ],
                dur=0.5,
            )
            .run(
                ["Bb5", "G5", "F#5", "F5", "Eb5", "C5", "Bb4", "G4", "F#4", "F4", "Eb4", "C4"],
                dur=0.5,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Escala de Do por terceras (2 octavas)",
                "description": "Toda la escala en intervalos de tercera, dos octavas. Patrón clásico de conservatorio.",
                "difficulty": "avanzado",
                "tempo_bpm": 120,
                "order": 13,
            },
            Seq()
            .run(
                [
                    "C4",
                    "E4",
                    "D4",
                    "F4",
                    "E4",
                    "G4",
                    "F4",
                    "A4",
                    "G4",
                    "B4",
                    "A4",
                    "C5",
                    "B4",
                    "D5",
                    "C5",
                    "E5",
                    "D5",
                    "F5",
                    "E5",
                    "G5",
                    "F5",
                    "A5",
                    "G5",
                    "B5",
                    "A5",
                    "C6",
                ],
                dur=0.333,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Arpegios I-IV-V de Do (subida)",
                "description": "Arpegios de Do, Fa y Sol Mayor encadenados subiendo dos octavas. Control de saltos amplios.",
                "difficulty": "avanzado",
                "tempo_bpm": 130,
                "order": 14,
            },
            Seq()
            .run(["C4", "E4", "G4", "C5", "E5", "G5"], dur=0.5)
            .run(["F4", "A4", "C5", "F5", "A5", "C6"], dur=0.5)
            .run(["G4", "B4", "D5", "G5", "B5", "D6"], dur=0.5)
            .build(),
        ),
        # ── Experto ──
        L(
            {
                **base,
                "title": "Escala de Do Mayor (4 octavas)",
                "description": "Do Mayor a lo largo de 4 octavas en semicorcheas. Resistencia, igualdad y paso del pulgar a velocidad.",
                "difficulty": "experto",
                "tempo_bpm": 150,
                "order": 15,
            },
            Seq()
            .run(
                [
                    "C3",
                    "D3",
                    "E3",
                    "F3",
                    "G3",
                    "A3",
                    "B3",
                    "C4",
                    "D4",
                    "E4",
                    "F4",
                    "G4",
                    "A4",
                    "B4",
                    "C5",
                    "D5",
                    "E5",
                    "F5",
                    "G5",
                    "A5",
                    "B5",
                    "C6",
                    "D6",
                    "E6",
                    "F6",
                    "G6",
                    "A6",
                    "B6",
                    "C7",
                ],
                dur=0.25,
            )
            .run(
                [
                    "B6",
                    "A6",
                    "G6",
                    "F6",
                    "E6",
                    "D6",
                    "C6",
                    "B5",
                    "A5",
                    "G5",
                    "F5",
                    "E5",
                    "D5",
                    "C5",
                    "B4",
                    "A4",
                    "G4",
                    "F4",
                    "E4",
                    "D4",
                    "C4",
                ],
                dur=0.25,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Arpegios de Do (4 octavas)",
                "description": "Arpegio de Do Mayor subiendo y bajando 4 octavas. Muñeca suelta y saltos limpios. Nivel experto.",
                "difficulty": "experto",
                "tempo_bpm": 140,
                "order": 16,
            },
            Seq()
            .run(
                ["C3", "E3", "G3", "C4", "E4", "G4", "C5", "E5", "G5", "C6", "E6", "G6", "C7"],
                dur=0.25,
            )
            .run(["G6", "E6", "C6", "G5", "E5", "C5", "G4", "E4", "C4", "G3", "E3", "C3"], dur=0.25)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Hanon Nº 1",
                "description": "El ejercicio Nº 1 de Hanon (patrón ascendente 1-3-4-5-6-5-4-3) en semicorcheas. Independencia de dedos.",
                "difficulty": "experto",
                "tempo_bpm": 132,
                "order": 17,
            },
            Seq()
            .run(
                [
                    "C4",
                    "E4",
                    "F4",
                    "G4",
                    "A4",
                    "G4",
                    "F4",
                    "E4",
                    "D4",
                    "F4",
                    "G4",
                    "A4",
                    "B4",
                    "A4",
                    "G4",
                    "F4",
                    "E4",
                    "G4",
                    "A4",
                    "B4",
                    "C5",
                    "B4",
                    "A4",
                    "G4",
                    "F4",
                    "A4",
                    "B4",
                    "C5",
                    "D5",
                    "C5",
                    "B4",
                    "A4",
                    "G4",
                    "B4",
                    "C5",
                    "D5",
                    "E5",
                    "D5",
                    "C5",
                    "B4",
                ],
                dur=0.25,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Escala cromática (4 octavas)",
                "description": "Cromática completa a 4 octavas en semicorcheas. La prueba de fuego de la agilidad digital.",
                "difficulty": "experto",
                "tempo_bpm": 160,
                "order": 18,
            },
            Seq()
            .run(
                [
                    "C3",
                    "C#3",
                    "D3",
                    "D#3",
                    "E3",
                    "F3",
                    "F#3",
                    "G3",
                    "G#3",
                    "A3",
                    "A#3",
                    "B3",
                    "C4",
                    "C#4",
                    "D4",
                    "D#4",
                    "E4",
                    "F4",
                    "F#4",
                    "G4",
                    "G#4",
                    "A4",
                    "A#4",
                    "B4",
                    "C5",
                    "C#5",
                    "D5",
                    "D#5",
                    "E5",
                    "F5",
                    "F#5",
                    "G5",
                    "G#5",
                    "A5",
                    "A#5",
                    "B5",
                    "C6",
                    "C#6",
                    "D6",
                    "D#6",
                    "E6",
                    "F6",
                    "F#6",
                    "G6",
                    "G#6",
                    "A6",
                    "A#6",
                    "B6",
                    "C7",
                ],
                dur=0.25,
            )
            .build(),
        ),
    ]


def get_acordes_lessons(category_id: uuid.UUID, admin_id: uuid.UUID) -> list[dict]:
    """Lecciones de la categoría Acordes (recalibradas, más exigentes)."""
    base = {
        "category_id": category_id,
        "created_by": admin_id,
        "key_signature": "C",
        "genre": "Técnica",
    }
    return [
        # ── Principiante ──
        L(
            {
                **base,
                "title": "Tríada de Do Mayor",
                "description": "Do-Mi-Sol simultáneo, repetido. Tu primer acorde: presioná las tres notas a la vez.",
                "difficulty": "principiante",
                "tempo_bpm": 70,
                "order": 1,
            },
            Seq()
            .chord(["C4", "E4", "G4"])
            .rest()
            .chord(["C4", "E4", "G4"])
            .rest()
            .chord(["C4", "E4", "G4"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Tríadas mayores: Do, Fa, Sol",
                "description": "Los tres acordes esenciales (I-IV-V). Cambiá de posición de mano entre cada uno.",
                "difficulty": "principiante",
                "tempo_bpm": 70,
                "order": 2,
            },
            Seq()
            .chord(["C4", "E4", "G4"])
            .chord(["F4", "A4", "C5"])
            .chord(["G4", "B4", "D5"])
            .chord(["C4", "E4", "G4"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Tríadas menores: Lam, Rem, Mim",
                "key_signature": "Am",
                "description": "Tres acordes menores de sonido más triste. Muy usados en baladas y pop.",
                "difficulty": "principiante",
                "tempo_bpm": 70,
                "order": 3,
            },
            Seq()
            .chord(["A3", "C4", "E4"])
            .chord(["D4", "F4", "A4"])
            .chord(["E4", "G4", "B4"])
            .chord(["A3", "C4", "E4"])
            .build(),
        ),
        # ── Intermedio ──
        L(
            {
                **base,
                "title": "Progresión pop I-V-vi-IV",
                "description": "La progresión 'mágica' del pop: Do - Sol - Lam - Fa. Suena en miles de canciones.",
                "difficulty": "intermedio",
                "tempo_bpm": 95,
                "order": 4,
            },
            Seq()
            .chord(["C4", "E4", "G4"])
            .chord(["G4", "B4", "D5"])
            .chord(["A4", "C5", "E5"])
            .chord(["F4", "A4", "C5"])
            .chord(["C4", "E4", "G4"])
            .chord(["G4", "B4", "D5"])
            .chord(["A4", "C5", "E5"])
            .chord(["F4", "A4", "C5"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Inversiones de Do Mayor",
                "description": "El mismo acorde en estado fundamental, 1ª y 2ª inversión. Misma armonía, distinta forma de la mano.",
                "difficulty": "intermedio",
                "tempo_bpm": 90,
                "order": 5,
            },
            Seq()
            .chord(["C4", "E4", "G4"])
            .chord(["E4", "G4", "C5"])
            .chord(["G4", "C5", "E5"])
            .chord(["C5", "E5", "G5"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Acompañamiento mano izquierda + melodía",
                "description": "Acorde de bajo en la izquierda y melodía en la derecha, juntos. Coordinación de manos.",
                "difficulty": "intermedio",
                "tempo_bpm": 90,
                "order": 6,
            },
            Seq()
            .both(["C3", "G3"], ["E4"])
            .both(["F2", "C3"], ["A4"])
            .both(["G2", "D3"], ["B4"])
            .both(["C3", "G3"], ["C5"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Arpegios de tríadas (Do-Fa-Sol)",
                "description": "Cada acorde tocado nota por nota (arpegio) en corcheas, subiendo y bajando.",
                "difficulty": "intermedio",
                "tempo_bpm": 105,
                "order": 7,
            },
            Seq()
            .run(["C4", "E4", "G4", "C5", "G4", "E4"], dur=0.5)
            .run(["F4", "A4", "C5", "F5", "C5", "A4"], dur=0.5)
            .run(["G4", "B4", "D5", "G5", "D5", "B4"], dur=0.5)
            .build(),
        ),
        # ── Avanzado ──
        L(
            {
                **base,
                "title": "Acordes de séptima (Cmaj7, Dm7, G7)",
                "description": "Acordes de cuatro notas con séptima: sonido rico y jazzístico. Estiramiento de la mano.",
                "difficulty": "avanzado",
                "tempo_bpm": 100,
                "order": 8,
            },
            Seq()
            .chord(["C4", "E4", "G4", "B4"])
            .chord(["D4", "F4", "A4", "C5"])
            .chord(["G4", "B4", "D5", "F5"])
            .chord(["C4", "E4", "G4", "B4"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Progresión jazz ii-V-I (voicings de 7ª)",
                "description": "La progresión más usada del jazz: Dm7 - G7 - Cmaj7, con voicings de cuatro notas.",
                "difficulty": "avanzado",
                "tempo_bpm": 110,
                "order": 9,
            },
            Seq()
            .chord(["D4", "F4", "A4", "C5"])
            .chord(["G3", "B3", "F4", "A4"])
            .chord(["C4", "E4", "G4", "B4"])
            .rest()
            .chord(["D4", "F4", "A4", "C5"])
            .chord(["G3", "B3", "F4", "A4"])
            .chord(["C4", "E4", "G4", "B4"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Arpegios de séptima a 2 octavas",
                "description": "Cmaj7 y G7 desplegados en arpegio a lo largo de dos octavas. Corcheas continuas.",
                "difficulty": "avanzado",
                "tempo_bpm": 120,
                "order": 10,
            },
            Seq()
            .run(["C4", "E4", "G4", "B4", "C5", "E5", "G5", "B5"], dur=0.5)
            .run(["G3", "B3", "D4", "F4", "G4", "B4", "D5", "F5"], dur=0.5)
            .build(),
        ),
        # ── Experto ──
        L(
            {
                **base,
                "title": "Cadena de dominantes (círculo de quintas)",
                "description": "E7-A7-D7-G7-C: dominantes encadenadas por el círculo de quintas. Armonía avanzada en acordes de 4 notas.",
                "difficulty": "experto",
                "tempo_bpm": 120,
                "order": 11,
            },
            Seq()
            .chord(["E4", "G#4", "B4", "D5"])
            .chord(["A3", "C#4", "E4", "G4"])
            .chord(["D4", "F#4", "A4", "C5"])
            .chord(["G3", "B3", "D4", "F4"])
            .chord(["C4", "E4", "G4", "B4"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Acordes con novena (jazz/pop avanzado)",
                "description": "Cmaj9, Dm9 y G9: voicings de cinco notas de color moderno. Gran apertura de mano.",
                "difficulty": "experto",
                "tempo_bpm": 110,
                "order": 12,
            },
            Seq()
            .chord(["C4", "E4", "G4", "B4", "D5"])
            .chord(["D4", "F4", "A4", "C5", "E5"])
            .chord(["G3", "B3", "D4", "F4", "A4"])
            .chord(["C4", "E4", "G4", "B4", "D5"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Acordes desplegados a manos juntas",
                "description": "Bajo de octava en la izquierda + acorde de séptima en la derecha, simultáneos. Sonoridad de pianista completo.",
                "difficulty": "experto",
                "tempo_bpm": 110,
                "order": 13,
            },
            Seq()
            .both(["C2", "C3"], ["E4", "G4", "B4"])
            .both(["A2", "A3"], ["E4", "G4", "C5"])
            .both(["F2", "F3"], ["F4", "A4", "C5"])
            .both(["G2", "G3"], ["F4", "G4", "B4"])
            .both(["C2", "C3"], ["E4", "G4", "C5"])
            .build(),
        ),
    ]


# Género y autor por título (dominio público). Se aplica a las melodías que no
# lo definen explícitamente en su meta.
_MELODY_META: dict[str, tuple[str, str | None]] = {
    "Twinkle Twinkle (completa)": ("Infantil", "Tradicional"),
    "Oda a la Alegría (Beethoven)": ("Clásica", "Beethoven"),
    "Jingle Bells (verso + coro)": ("Navidad", "James Pierpont"),
    "Happy Birthday (con saltos de octava)": ("Festiva", "Tradicional"),
    "Amazing Grace (frases largas)": ("Góspel", "John Newton"),
    "Greensleeves (intro)": ("Folclore", "Tradicional inglés"),
    "Ode to Joy con bajo (manos juntas)": ("Clásica", "Beethoven"),
    "Für Elise (tema principal)": ("Clásica", "Beethoven"),
    "Canon en Re (Pachelbel)": ("Clásica", "Pachelbel"),
    "Entertainer (Joplin, fragmento)": ("Ragtime", "Scott Joplin"),
    "Preludio en Do (Bach, BWV 846)": ("Clásica", "J.S. Bach"),
    "Claro de Luna (tresillos)": ("Clásica", "Beethoven"),
    "Vals de las flores (tema, Chaikovski)": ("Clásica", "Chaikovski"),
    "Nocturno Op.9 Nº2 (tema, Chopin)": ("Clásica", "Chopin"),
}


def get_melodias_lessons(category_id: uuid.UUID, admin_id: uuid.UUID) -> list[dict]:
    """Lecciones de la categoría Melodías (recalibradas, más exigentes)."""
    base = {"category_id": category_id, "created_by": admin_id, "key_signature": "C"}
    lessons = [
        # ── Principiante ──
        L(
            {
                **base,
                "title": "Twinkle Twinkle (completa)",
                "description": "La melodía infantil más conocida, completa con su parte central. Notas claras a tempo cómodo.",
                "difficulty": "principiante",
                "tempo_bpm": 90,
                "order": 1,
            },
            Seq()
            .run(
                [
                    "C4",
                    "C4",
                    "G4",
                    "G4",
                    "A4",
                    "A4",
                    "G4",
                    "F4",
                    "F4",
                    "E4",
                    "E4",
                    "D4",
                    "D4",
                    "C4",
                    "G4",
                    "G4",
                    "F4",
                    "F4",
                    "E4",
                    "E4",
                    "D4",
                    "G4",
                    "G4",
                    "F4",
                    "F4",
                    "E4",
                    "E4",
                    "D4",
                    "C4",
                    "C4",
                    "G4",
                    "G4",
                    "A4",
                    "A4",
                    "G4",
                    "F4",
                    "F4",
                    "E4",
                    "E4",
                    "D4",
                    "D4",
                    "C4",
                ]
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Oda a la Alegría (Beethoven)",
                "description": "El tema de la 9ª Sinfonía, completo en dos frases. Melodía icónica para principiantes avanzados.",
                "difficulty": "principiante",
                "tempo_bpm": 90,
                "order": 2,
            },
            Seq()
            .run(
                [
                    "E4",
                    "E4",
                    "F4",
                    "G4",
                    "G4",
                    "F4",
                    "E4",
                    "D4",
                    "C4",
                    "C4",
                    "D4",
                    "E4",
                    "E4",
                    "D4",
                    "D4",
                    "E4",
                    "E4",
                    "F4",
                    "G4",
                    "G4",
                    "F4",
                    "E4",
                    "D4",
                    "C4",
                    "C4",
                    "D4",
                    "E4",
                    "D4",
                    "C4",
                    "C4",
                ]
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Jingle Bells (verso + coro)",
                "description": "El villancico más famoso, ampliado con el verso. Notas repetidas y saltos cortos.",
                "difficulty": "principiante",
                "tempo_bpm": 100,
                "order": 3,
            },
            Seq()
            .run(
                [
                    "E4",
                    "E4",
                    "E4",
                    "E4",
                    "E4",
                    "E4",
                    "E4",
                    "G4",
                    "C4",
                    "D4",
                    "E4",
                    "F4",
                    "F4",
                    "F4",
                    "F4",
                    "F4",
                    "E4",
                    "E4",
                    "E4",
                    "E4",
                    "D4",
                    "D4",
                    "E4",
                    "D4",
                    "G4",
                    "E4",
                    "E4",
                    "E4",
                    "E4",
                    "E4",
                    "E4",
                    "E4",
                    "G4",
                    "C4",
                    "D4",
                    "E4",
                    "F4",
                    "F4",
                    "F4",
                    "F4",
                    "F4",
                    "E4",
                    "E4",
                    "G4",
                    "G4",
                    "F4",
                    "D4",
                    "C4",
                ]
            )
            .build(),
        ),
        # ── Intermedio ──
        L(
            {
                **base,
                "title": "Happy Birthday (con saltos de octava)",
                "description": "El 'Cumpleaños feliz'. Salta octavas: la octava ahora se exige exacta.",
                "difficulty": "intermedio",
                "tempo_bpm": 95,
                "order": 4,
            },
            Seq()
            .run(
                [
                    "G4",
                    "G4",
                    "A4",
                    "G4",
                    "C5",
                    "B4",
                    "G4",
                    "G4",
                    "A4",
                    "G4",
                    "D5",
                    "C5",
                    "G4",
                    "G4",
                    "G5",
                    "E5",
                    "C5",
                    "B4",
                    "A4",
                    "F5",
                    "F5",
                    "E5",
                    "C5",
                    "D5",
                    "C5",
                ]
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Amazing Grace (frases largas)",
                "description": "Himno tradicional de sonido cálido. Frases largas que suben y bajan con anacrusa.",
                "difficulty": "intermedio",
                "tempo_bpm": 85,
                "order": 5,
            },
            Seq()
            .run(
                [
                    "G4",
                    "C5",
                    "E5",
                    "C5",
                    "E5",
                    "D5",
                    "C5",
                    "A4",
                    "G4",
                    "G4",
                    "C5",
                    "E5",
                    "C5",
                    "E5",
                    "D5",
                    "E5",
                    "G5",
                    "G5",
                    "E5",
                    "C5",
                    "E5",
                    "D5",
                    "C5",
                    "A4",
                    "G4",
                    "C5",
                ]
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Greensleeves (intro)",
                "key_signature": "Am",
                "description": "La melancólica melodía renacentista en La menor, con su característico F#. Compás de 6/8.",
                "difficulty": "intermedio",
                "tempo_bpm": 90,
                "time_signature": "6/8",
                "order": 6,
            },
            Seq()
            .run(
                [
                    "A4",
                    "C5",
                    "D5",
                    "E5",
                    "F5",
                    "E5",
                    "D5",
                    "B4",
                    "G4",
                    "A4",
                    "B4",
                    "C5",
                    "B4",
                    "A4",
                    "G#4",
                    "B4",
                    "A4",
                    "C5",
                    "D5",
                    "E5",
                    "F5",
                    "E5",
                    "D5",
                    "B4",
                    "G4",
                    "A4",
                    "B4",
                    "C5",
                    "B4",
                    "A4",
                    "G#4",
                    "A4",
                ]
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Ode to Joy con bajo (manos juntas)",
                "description": "El tema de Beethoven con un bajo simple en la izquierda en cada acento. Primer paso a manos juntas en melodía.",
                "difficulty": "intermedio",
                "tempo_bpm": 90,
                "order": 7,
            },
            Seq()
            .both(["C3"], ["E4"])
            .n("E4")
            .n("F4")
            .both(["G3"], ["G4"])
            .n("G4")
            .n("F4")
            .n("E4")
            .both(["C3"], ["D4"])
            .both(["G2"], ["C4"])
            .n("C4")
            .n("D4")
            .both(["C3"], ["E4"])
            .n("E4", dur=1.5)
            .n("D4", dur=0.5)
            .both(["G2"], ["D4"])
            .build(),
        ),
        # ── Avanzado ──
        L(
            {
                **base,
                "title": "Für Elise (tema principal)",
                "key_signature": "Am",
                "description": "La icónica sección A completa de Für Elise de Beethoven. Cambios rápidos E-D# y frases largas en corcheas.",
                "difficulty": "avanzado",
                "tempo_bpm": 100,
                "order": 8,
            },
            Seq()
            .run(
                [
                    "E5",
                    "D#5",
                    "E5",
                    "D#5",
                    "E5",
                    "B4",
                    "D5",
                    "C5",
                    "A4",
                    "C4",
                    "E4",
                    "A4",
                    "B4",
                    "E4",
                    "G#4",
                    "B4",
                    "C5",
                    "E4",
                    "E5",
                    "D#5",
                    "E5",
                    "D#5",
                    "E5",
                    "B4",
                    "D5",
                    "C5",
                    "A4",
                    "C4",
                    "E4",
                    "A4",
                    "B4",
                    "E4",
                    "C5",
                    "B4",
                    "A4",
                ],
                dur=0.5,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Canon en Re (Pachelbel)",
                "key_signature": "D",
                "description": "El tema más famoso de Pachelbel, en Re Mayor. Reto avanzado con sostenidos y rango amplio.",
                "difficulty": "avanzado",
                "tempo_bpm": 95,
                "order": 9,
            },
            Seq()
            .run(
                [
                    "F#5",
                    "E5",
                    "D5",
                    "C#5",
                    "B4",
                    "A4",
                    "B4",
                    "C#5",
                    "D5",
                    "C#5",
                    "B4",
                    "A4",
                    "G4",
                    "F#4",
                    "G4",
                    "E4",
                    "F#4",
                    "D4",
                    "A4",
                    "G4",
                    "F#4",
                    "D4",
                    "F#4",
                    "A4",
                    "G4",
                    "F#4",
                    "E4",
                    "D4",
                    "E4",
                    "F#4",
                    "G4",
                    "A4",
                ],
                dur=0.5,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Entertainer (Joplin, fragmento)",
                "description": "El ragtime clásico de Scott Joplin. Saltos sincopados y cromatismos: pura agilidad.",
                "difficulty": "avanzado",
                "tempo_bpm": 120,
                "order": 10,
            },
            Seq()
            .run(
                [
                    "D5",
                    "D#5",
                    "E5",
                    "C6",
                    "E5",
                    "C6",
                    "E5",
                    "C6",
                    "C6",
                    "C6",
                    "A5",
                    "G5",
                    "F#5",
                    "A5",
                    "C6",
                    "E6",
                    "D6",
                    "C6",
                    "A5",
                    "D5",
                    "D#5",
                    "E5",
                    "C6",
                    "E5",
                    "C6",
                    "E5",
                ],
                dur=0.5,
            )
            .build(),
        ),
        # ── Experto ──
        L(
            {
                **base,
                "title": "Preludio en Do (Bach, BWV 846)",
                "description": "Los acordes desplegados continuos del célebre Preludio de El clave bien temperado. Igualdad y legato perfectos.",
                "difficulty": "experto",
                "tempo_bpm": 140,
                "order": 11,
            },
            Seq()
            .run(
                [
                    "C4",
                    "E4",
                    "G4",
                    "C5",
                    "E5",
                    "G4",
                    "C5",
                    "E5",
                    "C4",
                    "E4",
                    "G4",
                    "C5",
                    "E5",
                    "G4",
                    "C5",
                    "E5",
                    "C4",
                    "D4",
                    "A4",
                    "D5",
                    "F5",
                    "A4",
                    "D5",
                    "F5",
                    "C4",
                    "D4",
                    "A4",
                    "D5",
                    "F5",
                    "A4",
                    "D5",
                    "F5",
                    "B3",
                    "D4",
                    "G4",
                    "D5",
                    "F5",
                    "G4",
                    "D5",
                    "F5",
                    "C4",
                    "E4",
                    "G4",
                    "C5",
                    "E5",
                    "G4",
                    "C5",
                    "E5",
                ],
                dur=0.25,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Claro de Luna (tresillos)",
                "key_signature": "C#m",
                "description": "Los tresillos del 1er movimiento de la Sonata de Beethoven. Uniformidad y control a tempo lento pero implacable.",
                "difficulty": "experto",
                "tempo_bpm": 60,
                "order": 12,
            },
            Seq()
            .run(
                [
                    "G#3",
                    "C#4",
                    "E4",
                    "G#3",
                    "C#4",
                    "E4",
                    "G#3",
                    "C#4",
                    "E4",
                    "G#3",
                    "C#4",
                    "E4",
                    "A3",
                    "C#4",
                    "E4",
                    "A3",
                    "C#4",
                    "E4",
                    "A3",
                    "C#4",
                    "E4",
                    "A3",
                    "C#4",
                    "E4",
                    "G#3",
                    "C4",
                    "F#4",
                    "G#3",
                    "C4",
                    "F#4",
                    "G#3",
                    "B3",
                    "F#4",
                    "G#3",
                    "B3",
                    "F#4",
                ],
                dur=0.333,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Vals de las flores (tema, Chaikovski)",
                "description": "El célebre tema del Cascanueces en 3/4. Saltos amplios de bajo a melodía y fraseo cantábile. Experto.",
                "difficulty": "experto",
                "tempo_bpm": 150,
                "time_signature": "3/4",
                "order": 13,
            },
            Seq()
            .both(["D3", "A3"], ["F#5"])
            .n("E5")
            .n("D5")
            .both(["A2", "E3"], ["A5"])
            .n("G5")
            .n("F#5")
            .both(["D3", "A3"], ["E5"])
            .n("D5")
            .n("C#5")
            .both(["A2", "E3"], ["B4"])
            .n("A4", dur=2.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Nocturno Op.9 Nº2 (tema, Chopin)",
                "key_signature": "Eb",
                "description": "El comienzo del Nocturno más famoso de Chopin, con sus adornos y saltos expresivos. Repertorio de concierto. Experto.",
                "difficulty": "experto",
                "tempo_bpm": 130,
                "order": 14,
            },
            Seq()
            .n("Bb4", dur=1.0)
            .run(["G4", "F4", "Eb4", "Bb4", "C5", "Bb4"], dur=0.5)
            .n("F5", dur=1.0)
            .run(["Eb5", "D5", "Eb5", "G4", "Bb4"], dur=0.5)
            .n("Ab5", dur=1.0)
            .run(["G5", "F5", "Eb5", "D5", "Eb5", "F5", "G5"], dur=0.5)
            .n("Bb4", dur=2.0)
            .build(),
        ),
        # ── Canciones nuevas (dominio público) con género/autor ──
        L(
            {
                **base,
                "title": "Auld Lang Syne",
                "genre": "Festiva",
                "artist": "Tradicional escocés",
                "description": "El clásico de Año Nuevo. Melodía cálida y pegadiza, ideal para frasear.",
                "difficulty": "principiante",
                "tempo_bpm": 90,
                "order": 15,
            },
            Seq()
            .run(
                [
                    "G4",
                    "C5",
                    "C5",
                    "C5",
                    "E5",
                    "D5",
                    "C5",
                    "D5",
                    "E5",
                    "C5",
                    "C5",
                    "E5",
                    "G5",
                    "A5",
                    "A5",
                    "G5",
                    "E5",
                    "E5",
                    "C5",
                    "D5",
                    "C5",
                    "D5",
                    "E5",
                    "C5",
                    "A4",
                    "A4",
                    "G4",
                    "C5",
                ]
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Scarborough Fair (tema)",
                "key_signature": "Am",
                "genre": "Folclore",
                "artist": "Tradicional inglés",
                "description": "Balada renacentista en modo dórico. Frases largas y melancólicas.",
                "difficulty": "intermedio",
                "tempo_bpm": 90,
                "time_signature": "3/4",
                "order": 16,
            },
            Seq()
            .run(
                [
                    "A4",
                    "A4",
                    "E5",
                    "E5",
                    "E5",
                    "B4",
                    "C5",
                    "B4",
                    "A4",
                    "G4",
                    "A4",
                    "B4",
                    "A4",
                    "G4",
                    "E4",
                    "A4",
                    "A4",
                    "C5",
                    "B4",
                    "A4",
                    "G4",
                    "F#4",
                    "G4",
                    "A4",
                    "E4",
                    "E4",
                    "A4",
                ]
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Minueto en Sol (Bach)",
                "key_signature": "G",
                "genre": "Clásica",
                "artist": "J.S. Bach",
                "description": "El célebre Minueto en Sol (BWV Anh. 114). Elegante y bailable en 3/4.",
                "difficulty": "intermedio",
                "tempo_bpm": 110,
                "time_signature": "3/4",
                "order": 17,
            },
            Seq()
            .run(
                [
                    "D5",
                    "G4",
                    "A4",
                    "B4",
                    "C5",
                    "D5",
                    "G4",
                    "G4",
                    "E5",
                    "C5",
                    "D5",
                    "E5",
                    "F#5",
                    "G5",
                    "G4",
                    "G4",
                    "C5",
                    "D5",
                    "C5",
                    "B4",
                    "A4",
                    "B4",
                    "C5",
                    "B4",
                    "A4",
                    "G4",
                    "F#4",
                    "G4",
                    "A4",
                    "B4",
                    "G4",
                ]
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Habanera (Carmen, Bizet)",
                "key_signature": "Dm",
                "genre": "Ópera",
                "artist": "Bizet",
                "description": "El tema más famoso de Carmen, descendiendo cromáticamente con sabor. Reto avanzado.",
                "difficulty": "avanzado",
                "tempo_bpm": 100,
                "order": 18,
            },
            Seq()
            .run(
                [
                    "D5",
                    "C#5",
                    "C5",
                    "B4",
                    "Bb4",
                    "A4",
                    "A4",
                    "A4",
                    "Bb4",
                    "A4",
                    "Bb4",
                    "A4",
                    "Bb4",
                    "A4",
                    "A4",
                    "D5",
                    "C#5",
                    "C5",
                    "B4",
                    "Bb4",
                    "A4",
                    "A4",
                    "A4",
                    "Bb4",
                    "A4",
                    "G4",
                    "A4",
                    "D5",
                ]
            )
            .build(),
        ),
    ]
    # Asignar género/autor a las que no lo definieron explícitamente.
    for ld in lessons:
        meta = ld["lesson"]
        if "genre" not in meta:
            g, a = _MELODY_META.get(meta["title"], ("Clásica", None))
            meta["genre"] = g
            meta["artist"] = a
    return lessons


def get_ritmo_lessons(category_id: uuid.UUID, admin_id: uuid.UUID) -> list[dict]:
    """Lecciones de la categoría Ritmo (recalibradas, más exigentes)."""
    base = {
        "category_id": category_id,
        "created_by": admin_id,
        "key_signature": "C",
        "genre": "Técnica",
    }
    return [
        # ── Principiante ──
        L(
            {
                **base,
                "title": "Negras, blancas y redondas",
                "description": "Mezcla los tres valores básicos: negras (1), blancas (2) y redondas (4 tiempos). Aprendé a sostener el pulso.",
                "difficulty": "principiante",
                "tempo_bpm": 70,
                "order": 1,
            },
            Seq()
            .run(["C4", "C4", "C4", "C4"], dur=1.0)
            .run(["D4", "E4"], dur=2.0)
            .n("C4", dur=4.0)
            .build(),
        ),
        L(
            {
                **base,
                "title": "Negras y silencios",
                "description": "Alterná notas y silencios de negra. Contar los silencios es tan importante como tocar.",
                "difficulty": "principiante",
                "tempo_bpm": 75,
                "order": 2,
            },
            Seq()
            .n("C4")
            .rest()
            .n("D4")
            .rest()
            .n("E4")
            .rest()
            .n("F4")
            .rest()
            .n("G4")
            .rest()
            .n("E4")
            .n("C4")
            .build(),
        ),
        # ── Intermedio ──
        L(
            {
                **base,
                "title": "Corcheas continuas",
                "description": "Ocho corcheas seguidas y de vuelta. Mantené parejo el flujo rápido de notas a dos octavas.",
                "difficulty": "intermedio",
                "tempo_bpm": 100,
                "order": 3,
            },
            Seq()
            .run(
                [
                    "C4",
                    "D4",
                    "E4",
                    "F4",
                    "G4",
                    "A4",
                    "B4",
                    "C5",
                    "B4",
                    "A4",
                    "G4",
                    "F4",
                    "E4",
                    "D4",
                    "C4",
                ],
                dur=0.5,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Vals (3/4) con bajo y acorde",
                "description": "El clásico UN-dos-tres del vals: bajo en el primer tiempo, acorde en los otros dos. Manos juntas.",
                "difficulty": "intermedio",
                "tempo_bpm": 110,
                "time_signature": "3/4",
                "order": 4,
            },
            Seq()
            .both(["C3"], ["C4", "E4", "G4"])
            .chord(["C4", "E4", "G4"])
            .chord(["C4", "E4", "G4"])
            .both(["G2"], ["B3", "D4", "G4"])
            .chord(["B3", "D4", "G4"])
            .chord(["B3", "D4", "G4"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Síncopa básica",
                "description": "Acentos en el contratiempo: la nota cae 'entre' los pulsos. La base del groove.",
                "difficulty": "intermedio",
                "tempo_bpm": 100,
                "order": 5,
            },
            Seq()
            .n("C4", dur=0.5)
            .rest(0.5)
            .n("D4", dur=1.0)
            .n("E4", dur=0.5)
            .rest(0.5)
            .n("F4", dur=1.0)
            .n("G4", dur=0.5)
            .rest(0.5)
            .n("A4", dur=1.0)
            .build(),
        ),
        # ── Avanzado ──
        L(
            {
                **base,
                "title": "Tresillos a dos octavas",
                "description": "Tres notas por tiempo (tresillos) recorriendo el arpegio en dos octavas. Vaivén del swing y el blues.",
                "difficulty": "avanzado",
                "tempo_bpm": 120,
                "order": 6,
            },
            Seq()
            .run(
                [
                    "C4",
                    "E4",
                    "G4",
                    "C5",
                    "G4",
                    "E4",
                    "C5",
                    "E5",
                    "G5",
                    "C6",
                    "G5",
                    "E5",
                    "C5",
                    "G4",
                    "E4",
                    "C4",
                    "G3",
                    "C4",
                ],
                dur=0.333,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Semicorcheas (grupos de cuatro)",
                "description": "Cuatro notas por tiempo a buena velocidad. Articulación pareja y precisa, ida y vuelta.",
                "difficulty": "avanzado",
                "tempo_bpm": 120,
                "order": 7,
            },
            Seq()
            .run(
                [
                    "C4",
                    "D4",
                    "E4",
                    "F4",
                    "E4",
                    "F4",
                    "G4",
                    "A4",
                    "G4",
                    "A4",
                    "B4",
                    "C5",
                    "B4",
                    "A4",
                    "G4",
                    "F4",
                    "E4",
                    "D4",
                    "C4",
                    "D4",
                    "E4",
                    "F4",
                    "G4",
                    "C5",
                ],
                dur=0.25,
            )
            .build(),
        ),
        L(
            {
                **base,
                "title": "Patrón rítmico mixto (negra-corchea-semicorchea)",
                "description": "Combina valores en cada compás: negra, dos corcheas, cuatro semicorcheas. Lectura rítmica avanzada.",
                "difficulty": "avanzado",
                "tempo_bpm": 110,
                "order": 8,
            },
            Seq()
            .n("C4", dur=1.0)
            .run(["D4", "E4"], dur=0.5)
            .run(["F4", "G4", "A4", "B4"], dur=0.25)
            .n("C5", dur=1.0)
            .run(["B4", "A4"], dur=0.5)
            .run(["G4", "F4", "E4", "D4"], dur=0.25)
            .n("C4", dur=2.0)
            .build(),
        ),
        # ── Experto ──
        L(
            {
                **base,
                "title": "Polirritmia 3 contra 2 (manos juntas)",
                "description": "La izquierda en grupos de 2 y la derecha en tresillos, sonando juntas. El clásico reto de independencia rítmica.",
                "difficulty": "experto",
                "tempo_bpm": 80,
                "order": 9,
            },
            Seq()
            .both(["C3"], ["C5"])
            .n("E5", dur=0.333, hand="right")
            .both(["G3"], ["G5"])
            .n("E5", dur=0.333, hand="right")
            .both(["C3"], ["C5"])
            .n("E5", dur=0.333, hand="right")
            .both(["G3"], ["G5"])
            .build(),
        ),
        L(
            {
                **base,
                "title": "Boogie-woogie (bajo caminante)",
                "description": "El bajo caminante de octavas del boogie en semicorcheas continuas. Resistencia y swing a tempo rápido. Experto.",
                "difficulty": "experto",
                "tempo_bpm": 150,
                "order": 10,
            },
            Seq()
            .run(
                [
                    "C3",
                    "E3",
                    "G3",
                    "A3",
                    "Bb3",
                    "A3",
                    "G3",
                    "E3",
                    "C3",
                    "E3",
                    "G3",
                    "A3",
                    "Bb3",
                    "A3",
                    "G3",
                    "E3",
                    "F3",
                    "A3",
                    "C4",
                    "D4",
                    "Eb4",
                    "D4",
                    "C4",
                    "A3",
                    "G3",
                    "B3",
                    "D4",
                    "E4",
                    "F4",
                    "E4",
                    "D4",
                    "B3",
                ],
                dur=0.25,
            )
            .build(),
        ),
    ]


async def seed_lessons():
    """Seed ADITIVO de categorías y lecciones (idempotente por nombre/título)."""
    async with async_session() as db:
        try:
            admin = await get_admin_user(db)
            admin_id = admin.id if admin else None
            if admin_id:
                print(f"[seed] Admin encontrado: {admin.email}")
            else:
                print("[seed] No hay usuario admin. Creando lecciones sin creador.")

            # Crear/obtener categorías por nombre.
            categories: dict[str, uuid.UUID] = {}
            for cat_data in CATEGORIES:
                existing = (
                    await db.execute(select(Category).where(Category.name == cat_data["name"]))
                ).scalar_one_or_none()
                if existing:
                    categories[cat_data["name"]] = existing.id
                else:
                    cat = Category(**cat_data)
                    db.add(cat)
                    await db.flush()
                    categories[cat_data["name"]] = cat.id
                    print(f"[seed] Categoria creada: {cat_data['name']}")

            all_lessons = {
                "Escalas": get_escalas_lessons(categories["Escalas"], admin_id),
                "Acordes": get_acordes_lessons(categories["Acordes"], admin_id),
                "Melodías": get_melodias_lessons(categories["Melodías"], admin_id),
                "Ritmo": get_ritmo_lessons(categories["Ritmo"], admin_id),
            }

            added = 0
            updated = 0
            skipped = 0
            total_notes = 0

            for _cat_name, lessons in all_lessons.items():
                for lesson_data in lessons:
                    meta = lesson_data["lesson"]
                    title = meta["title"]
                    exists = (
                        await db.execute(select(Lesson).where(Lesson.title == title))
                    ).scalar_one_or_none()
                    if exists:
                        # Upsert de metadata curada (nivel/descripción) para que
                        # las recalibraciones se apliquen sin recrear la lección.
                        # Las notas y el progreso no se tocan (usá reseed_lessons
                        # en local para regenerar las notas desde cero).
                        changed = False
                        if exists.difficulty != meta["difficulty"]:
                            exists.difficulty = meta["difficulty"]
                            changed = True
                        if exists.description != meta["description"]:
                            exists.description = meta["description"]
                            changed = True
                        new_genre = meta.get("genre")
                        if exists.genre != new_genre:
                            exists.genre = new_genre
                            changed = True
                        new_artist = meta.get("artist")
                        if exists.artist != new_artist:
                            exists.artist = new_artist
                            changed = True
                        if changed:
                            updated += 1
                            print(f"  [seed] Recalibrada: {title} -> {meta['difficulty']}")
                        else:
                            skipped += 1
                        continue

                    lesson = Lesson(**meta)
                    db.add(lesson)
                    await db.flush()

                    for note_data in lesson_data["notes"]:
                        db.add(NoteSequence(lesson_id=lesson.id, **note_data))
                        total_notes += 1

                    added += 1
                    print(f"  [seed] Leccion nueva: {title} ({len(lesson_data['notes'])} notas)")

            await db.commit()
            print(
                f"\n[seed] Completado: {added} nuevas, {updated} recalibradas, "
                f"{skipped} sin cambios, {total_notes} notas agregadas."
            )

        except Exception as e:
            await db.rollback()
            print(f"[seed] ERROR: {e}")
            raise


if __name__ == "__main__":
    asyncio.run(seed_lessons())
