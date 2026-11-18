"""Script para cargar el catálogo oficial de digitaciones de instrumentos andinos.

Puebla digitaciones para Quena (7 orificios: pulgar + 6 frontales),
Zampoña (13 tubos: 6 ira y 7 arca) y Tarka (6 orificios frontales).
"""

import asyncio

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session
from app.models.fingering import Fingering

FINGERINGS_SEED = [
    # ==================== QUENA (Sol Mayor diatónico + 2da octava + alternas) ====================
    {
        "instrument": "quena",
        "note": "G",
        "octave": 4,
        "holes_covered": [True, True, True, True, True, True, True],
        "is_alternate": False,
        "description": "Sol4 fundamental (todos los orificios cubiertos: pulgar + 6 frontales)",
    },
    {
        "instrument": "quena",
        "note": "G#",
        "octave": 4,
        "holes_covered": [True, True, True, True, True, True, False],
        "is_alternate": True,
        "description": "Sol#4 alterno con orificio 6 a medio tapar",
    },
    {
        "instrument": "quena",
        "note": "A",
        "octave": 4,
        "holes_covered": [True, True, True, True, True, True, False],
        "is_alternate": False,
        "description": "La4 destapando orificio frontal 6",
    },
    {
        "instrument": "quena",
        "note": "A#",
        "octave": 4,
        "holes_covered": [True, True, True, True, True, False, False],
        "is_alternate": True,
        "description": "La#4 alterno con orificio 5 a medio tapar",
    },
    {
        "instrument": "quena",
        "note": "B",
        "octave": 4,
        "holes_covered": [True, True, True, True, True, False, False],
        "is_alternate": False,
        "description": "Si4 destapando orificios frontales 5 y 6",
    },
    {
        "instrument": "quena",
        "note": "C",
        "octave": 5,
        "holes_covered": [True, True, True, True, False, False, False],
        "is_alternate": False,
        "description": "Do5 destapando la mano inferior (orificios 4, 5 y 6)",
    },
    {
        "instrument": "quena",
        "note": "C#",
        "octave": 5,
        "holes_covered": [True, True, True, True, False, False, False],
        "is_alternate": True,
        "description": "Do#5 alterno con orificio 4 a medio tapar",
    },
    {
        "instrument": "quena",
        "note": "D",
        "octave": 5,
        "holes_covered": [True, True, True, False, False, False, False],
        "is_alternate": False,
        "description": "Re5 tapando solo los tres orificios de la mano superior",
    },
    {
        "instrument": "quena",
        "note": "D#",
        "octave": 5,
        "holes_covered": [True, True, True, False, False, False, False],
        "is_alternate": True,
        "description": "Re#5 alterno con orificio 3 a medio tapar",
    },
    {
        "instrument": "quena",
        "note": "E",
        "octave": 5,
        "holes_covered": [True, True, False, False, False, False, False],
        "is_alternate": False,
        "description": "Mi5 tapando pulgar y dos orificios superiores",
    },
    {
        "instrument": "quena",
        "note": "F",
        "octave": 5,
        "holes_covered": [True, False, False, False, False, False, False],
        "is_alternate": True,
        "description": "Fa5 natural alterno con orificio 1 a medio tapar",
    },
    {
        "instrument": "quena",
        "note": "F#",
        "octave": 5,
        "holes_covered": [True, False, False, False, False, False, False],
        "is_alternate": False,
        "description": "Fa#5 tapando únicamente el orificio posterior del pulgar",
    },
    {
        "instrument": "quena",
        "note": "G",
        "octave": 5,
        "holes_covered": [True, True, True, True, True, True, True],
        "is_alternate": False,
        "description": "Sol5 segunda octava (sobre-soplo con pulgar semicubierto)",
    },
    {
        "instrument": "quena",
        "note": "A",
        "octave": 5,
        "holes_covered": [True, True, True, True, True, True, False],
        "is_alternate": False,
        "description": "La5 segunda octava (sobre-soplo)",
    },
    {
        "instrument": "quena",
        "note": "B",
        "octave": 5,
        "holes_covered": [True, True, True, True, True, False, False],
        "is_alternate": False,
        "description": "Si5 segunda octava (sobre-soplo)",
    },
    {
        "instrument": "quena",
        "note": "C",
        "octave": 6,
        "holes_covered": [True, True, True, True, False, False, False],
        "is_alternate": False,
        "description": "Do6 segunda octava (sobre-soplo)",
    },
    {
        "instrument": "quena",
        "note": "D",
        "octave": 6,
        "holes_covered": [True, True, True, False, False, False, False],
        "is_alternate": False,
        "description": "Re6 segunda octava (sobre-soplo)",
    },
    # ==================== TARKA (Do Mayor diatónico - 6 orificios frontales) ====================
    {
        "instrument": "tarka",
        "note": "C",
        "octave": 5,
        "holes_covered": [True, True, True, True, True, True],
        "is_alternate": False,
        "description": "Do5 fundamental con los 6 orificios frontales cubiertos",
    },
    {
        "instrument": "tarka",
        "note": "D",
        "octave": 5,
        "holes_covered": [True, True, True, True, True, False],
        "is_alternate": False,
        "description": "Re5 destapando el último orificio inferior",
    },
    {
        "instrument": "tarka",
        "note": "E",
        "octave": 5,
        "holes_covered": [True, True, True, True, False, False],
        "is_alternate": False,
        "description": "Mi5 destapando los dos orificios inferiores",
    },
    {
        "instrument": "tarka",
        "note": "F",
        "octave": 5,
        "holes_covered": [True, True, True, False, False, False],
        "is_alternate": False,
        "description": "Fa5 destapando la mano inferior",
    },
    {
        "instrument": "tarka",
        "note": "G",
        "octave": 5,
        "holes_covered": [True, True, False, False, False, False],
        "is_alternate": False,
        "description": "Sol5 cubriendo dos orificios superiores",
    },
    {
        "instrument": "tarka",
        "note": "A",
        "octave": 5,
        "holes_covered": [True, False, False, False, False, False],
        "is_alternate": False,
        "description": "La5 cubriendo únicamente el primer orificio superior",
    },
    {
        "instrument": "tarka",
        "note": "B",
        "octave": 5,
        "holes_covered": [False, False, False, False, False, False],
        "is_alternate": False,
        "description": "Si5 con todos los orificios abiertos",
    },
    {
        "instrument": "tarka",
        "note": "C",
        "octave": 6,
        "holes_covered": [True, True, True, True, True, True],
        "is_alternate": False,
        "description": "Do6 segunda octava con sobre-soplo brillante (tarka tara)",
    },
    {
        "instrument": "tarka",
        "note": "D",
        "octave": 6,
        "holes_covered": [True, True, True, True, True, False],
        "is_alternate": False,
        "description": "Re6 segunda octava (sobre-soplo)",
    },
    {
        "instrument": "tarka",
        "note": "E",
        "octave": 6,
        "holes_covered": [True, True, True, True, False, False],
        "is_alternate": False,
        "description": "Mi6 segunda octava (sobre-soplo)",
    },
    # ==================== ZAMPOÑA (Siku tradicional de 13 tubos: Ira 6 + Arca 7) ====================
    # Fila Ira (6 tubos)
    {
        "instrument": "zampona",
        "note": "G",
        "octave": 4,
        "holes_covered": ["ira", 1],
        "is_alternate": False,
        "description": "Sol4 en tubo 1 de fila Ira (tubo más largo de Ira)",
    },
    {
        "instrument": "zampona",
        "note": "B",
        "octave": 4,
        "holes_covered": ["ira", 2],
        "is_alternate": False,
        "description": "Si4 en tubo 2 de fila Ira",
    },
    {
        "instrument": "zampona",
        "note": "D",
        "octave": 5,
        "holes_covered": ["ira", 3],
        "is_alternate": False,
        "description": "Re5 en tubo 3 de fila Ira",
    },
    {
        "instrument": "zampona",
        "note": "F#",
        "octave": 5,
        "holes_covered": ["ira", 4],
        "is_alternate": False,
        "description": "Fa#5 en tubo 4 de fila Ira",
    },
    {
        "instrument": "zampona",
        "note": "A",
        "octave": 5,
        "holes_covered": ["ira", 5],
        "is_alternate": False,
        "description": "La5 en tubo 5 de fila Ira",
    },
    {
        "instrument": "zampona",
        "note": "C",
        "octave": 6,
        "holes_covered": ["ira", 6],
        "is_alternate": False,
        "description": "Do6 en tubo 6 de fila Ira (tubo más corto de Ira)",
    },
    # Fila Arca (7 tubos)
    {
        "instrument": "zampona",
        "note": "A",
        "octave": 4,
        "holes_covered": ["arca", 1],
        "is_alternate": False,
        "description": "La4 en tubo 1 de fila Arca (tubo más largo de Arca)",
    },
    {
        "instrument": "zampona",
        "note": "C",
        "octave": 5,
        "holes_covered": ["arca", 2],
        "is_alternate": False,
        "description": "Do5 en tubo 2 de fila Arca",
    },
    {
        "instrument": "zampona",
        "note": "E",
        "octave": 5,
        "holes_covered": ["arca", 3],
        "is_alternate": False,
        "description": "Mi5 en tubo 3 de fila Arca",
    },
    {
        "instrument": "zampona",
        "note": "G",
        "octave": 5,
        "holes_covered": ["arca", 4],
        "is_alternate": False,
        "description": "Sol5 en tubo 4 de fila Arca",
    },
    {
        "instrument": "zampona",
        "note": "B",
        "octave": 5,
        "holes_covered": ["arca", 5],
        "is_alternate": False,
        "description": "Si5 en tubo 5 de fila Arca",
    },
    {
        "instrument": "zampona",
        "note": "D",
        "octave": 6,
        "holes_covered": ["arca", 6],
        "is_alternate": False,
        "description": "Re6 en tubo 6 de fila Arca",
    },
    {
        "instrument": "zampona",
        "note": "F#",
        "octave": 6,
        "holes_covered": ["arca", 7],
        "is_alternate": False,
        "description": "Fa#6 en tubo 7 de fila Arca (tubo más corto de Arca)",
    },
]


async def seed_fingerings(db: AsyncSession | None = None) -> tuple[int, int]:
    """Insertar digitaciones oficiales predefinidas en la base de datos de manera idempotente."""

    async def _execute_seed(session: AsyncSession) -> tuple[int, int]:
        inserted = 0
        skipped = 0

        for f_data in FINGERINGS_SEED:
            result = await session.execute(
                select(Fingering).where(
                    Fingering.instrument == f_data["instrument"],
                    Fingering.note == f_data["note"],
                    Fingering.octave == f_data["octave"],
                    Fingering.is_alternate == f_data.get("is_alternate", False),
                )
            )
            existing = result.scalar_one_or_none()

            if existing:
                # Actualizar datos si cambiaron
                existing.holes_covered = f_data["holes_covered"]
                existing.description = f_data.get("description")
                skipped += 1
            else:
                session.add(Fingering(**f_data))
                inserted += 1

        await session.commit()
        print(f"✅ Digitaciones andinas: {inserted} insertadas, {skipped} actualizadas/existentes.")
        return inserted, skipped

    if db is not None:
        return await _execute_seed(db)

    async with async_session() as session:
        return await _execute_seed(session)


if __name__ == "__main__":
    asyncio.run(seed_fingerings())
