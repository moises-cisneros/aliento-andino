"""LIMPIEZA + REGENERACIÓN de lecciones (solo para LOCAL / desarrollo).

A diferencia de `seed_lessons.py` (aditivo, lo corre el deploy), este script:

  1. BORRA todas las lecciones y sus notas (las sesiones de práctica se borran
     en cascada por la FK ondelete=CASCADE; los posts que referencian una
     sesión quedan con practice_session_id = NULL, no se borran).
  2. REINICIA la progresión de TODOS los usuarios existentes a un estado limpio
     (XP, nivel, rachas, contadores de práctica y logros desbloqueados), porque
     esa progresión derivaba de prácticas sobre lecciones que ya no existen.
     Las cuentas, el grafo social (posts/seguidores/likes) y la suscripción NO
     se tocan.
  3. Vuelve a cargar el catálogo NUEVO y más exigente desde `seed_lessons.py`.

Uso:
    backend/venv/Scripts/python reseed_lessons.py            # pide confirmación
    backend/venv/Scripts/python reseed_lessons.py --yes      # sin confirmación

NO ejecutar contra producción: borra el progreso de todos los usuarios.
"""

import asyncio
import sys

from sqlalchemy import delete, func, select, update

from app.database import async_session
from app.models.lesson import Lesson, NoteSequence, PracticeSession
from app.models.ranking import UserAchievement, UserXP
from app.models.user import User
from seed_lessons import seed_lessons

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


async def _count(db, model) -> int:
    return (await db.execute(select(func.count(model.id)))).scalar() or 0


async def wipe_and_reset() -> None:
    """Borra lecciones/práctica y reinicia la progresión de los usuarios."""
    async with async_session() as db:
        try:
            n_lessons = await _count(db, Lesson)
            n_notes = await _count(db, NoteSequence)
            n_sessions = await _count(db, PracticeSession)
            n_users = await _count(db, User)
            print(
                f"[reseed] Estado actual: {n_lessons} lecciones, {n_notes} notas, "
                f"{n_sessions} sesiones de práctica, {n_users} usuarios."
            )

            # 1. Borrar práctica explícitamente (deja posts con session=NULL),
            #    luego notas y lecciones. El orden evita depender solo de la
            #    cascada y es claro en los logs.
            await db.execute(delete(PracticeSession))
            await db.execute(delete(NoteSequence))
            await db.execute(delete(Lesson))
            print("[reseed] Lecciones, notas y sesiones de práctica borradas.")

            # 2. Reiniciar progresión de TODOS los usuarios (derivaba de práctica
            #    sobre lecciones ya borradas). No se tocan cuentas ni social.
            deleted_ach = await db.execute(delete(UserAchievement))
            await db.execute(
                update(UserXP).values(
                    total_xp=0,
                    weekly_xp=0,
                    level=1,
                    current_streak=0,
                    longest_streak=0,
                    total_practice_sessions=0,
                    total_practice_minutes=0.0,
                    total_lessons_completed=0,
                    total_perfect_scores=0,
                    average_score=0.0,
                    last_practice_date=None,
                    week_start_date=None,
                )
            )
            await db.execute(update(User).values(xp_level=1))
            print(
                f"[reseed] Progresión reiniciada para {n_users} usuarios "
                f"(XP, nivel, rachas, contadores; {deleted_ach.rowcount or 0} "
                f"logros desbloqueados removidos)."
            )

            await db.commit()
        except Exception as e:
            await db.rollback()
            print(f"[reseed] ERROR durante la limpieza: {e}")
            raise


async def main(skip_confirm: bool) -> None:
    print("=" * 64)
    print("🧹 RESEED DE LECCIONES — limpieza total + recarga (LOCAL)")
    print("=" * 64)

    if not skip_confirm:
        print(
            "\nEsto BORRA todas las lecciones, notas y sesiones de práctica, y\n"
            "REINICIA el progreso (XP/nivel/rachas/logros) de TODOS los usuarios.\n"
            "Las cuentas, posts, seguidores y suscripciones se conservan.\n"
        )
        answer = input("¿Continuar? Escribí 'si' para confirmar: ").strip().lower()
        if answer not in ("si", "sí", "s", "yes", "y"):
            print("[reseed] Cancelado. No se modificó nada.")
            return

    await wipe_and_reset()

    print("\n[reseed] Recargando catálogo nuevo (más exigente)...")
    await seed_lessons()

    # Resumen final
    async with async_session() as db:
        n_lessons = await _count(db, Lesson)
        n_notes = await _count(db, NoteSequence)
        # Distribución por dificultad
        rows = (
            await db.execute(
                select(Lesson.difficulty, func.count(Lesson.id)).group_by(
                    Lesson.difficulty
                )
            )
        ).all()
    print("\n" + "=" * 64)
    print(f"✅ RESEED COMPLETADO: {n_lessons} lecciones, {n_notes} notas.")
    order = {"principiante": 0, "intermedio": 1, "avanzado": 2, "experto": 3}
    for diff, cnt in sorted(rows, key=lambda r: order.get(r[0], 9)):
        print(f"   {diff:<14} {cnt} lecciones")
    print("=" * 64)


if __name__ == "__main__":
    skip = "--yes" in sys.argv or "-y" in sys.argv
    asyncio.run(main(skip))
