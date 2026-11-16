"""Seeder de digitaciones (FingeringChart) para Aliento Andino.

Carga una base inicial con la escala de Sol Mayor (G4-G5) para Quena y Zampoña/Siku.
Convenciones:
- Quena: 6 orificios frontales ("1" arriba .. "6" abajo) + "back" (pulgar).
  Valores: "closed" (tapado), "open" (destapado), "half" (medio tapado).
- Zampoña/Siku: flauta de pan sin orificios; cada nota es un tubo de una
  hilera ("ira" = 6 tubos guía, "arka" = 7 tubos complementarios).

NOTA: es una base pedagógica inicial; debe validarse con un maestro de música
andina antes de usarse en producción.
"""

import asyncio

from sqlalchemy import select

from app.database import async_session
from app.models.fingering import FingeringChart


def _quena(pattern: str, back: str = "closed") -> dict:
    """pattern: 6 chars (C/O/H) para orificios 1..6; back por separado."""
    m = {"C": "closed", "O": "open", "H": "half"}
    holes = {str(i + 1): m[pattern[i]] for i in range(6)}
    holes["back"] = back
    return holes


FINGERINGS_SEED = [
    # === QUENA — escala de Sol Mayor (G4..G5) ===
    {"instrument": "quena", "pitch": "G4", "holes": _quena("CCCCCC"), "notes": "Todos los orificios cerrados."},
    {"instrument": "quena", "pitch": "A4", "holes": _quena("CCCCCO")},
    {"instrument": "quena", "pitch": "B4", "holes": _quena("CCCCOO")},
    {"instrument": "quena", "pitch": "C5", "holes": _quena("CCCOOO")},
    {"instrument": "quena", "pitch": "D5", "holes": _quena("CCOOOO")},
    {"instrument": "quena", "pitch": "E5", "holes": _quena("COOOOO")},
    {"instrument": "quena", "pitch": "F#5", "holes": _quena("OOOOOO")},
    {"instrument": "quena", "pitch": "G5", "holes": _quena("CCCCCC", back="open"),
     "notes": "Octava: pulgar (trasero) abierto / sobresoplo."},

    # === ZAMPOÑA / SIKU — escala de Sol Mayor (trenzado Ira/Arka) ===
    {"instrument": "zampona", "pitch": "G4", "holes": {"row": "ira", "tube": 1}},
    {"instrument": "zampona", "pitch": "A4", "holes": {"row": "arka", "tube": 1}},
    {"instrument": "zampona", "pitch": "B4", "holes": {"row": "ira", "tube": 2}},
    {"instrument": "zampona", "pitch": "C5", "holes": {"row": "arka", "tube": 2}},
    {"instrument": "zampona", "pitch": "D5", "holes": {"row": "ira", "tube": 3}},
    {"instrument": "zampona", "pitch": "E5", "holes": {"row": "arka", "tube": 3}},
    {"instrument": "zampona", "pitch": "F#5", "holes": {"row": "ira", "tube": 4}},
    {"instrument": "zampona", "pitch": "G5", "holes": {"row": "arka", "tube": 4}},
]


async def seed_fingerings():
    """Insertar digitaciones base (idempotente por instrument+pitch)."""
    async with async_session() as db:
        try:
            inserted = 0
            skipped = 0
            for fc_data in FINGERINGS_SEED:
                result = await db.execute(
                    select(FingeringChart).where(
                        FingeringChart.instrument == fc_data["instrument"],
                        FingeringChart.pitch == fc_data["pitch"],
                    )
                )
                if result.scalar_one_or_none():
                    skipped += 1
                    continue
                db.add(FingeringChart(**fc_data))
                inserted += 1
            await db.commit()
            print(f"✅ Digitaciones: {inserted} insertadas, {skipped} ya existían.")
        except Exception as e:
            await db.rollback()
            print(f"❌ Error al insertar digitaciones: {e}")
            raise


if __name__ == "__main__":
    asyncio.run(seed_fingerings())
