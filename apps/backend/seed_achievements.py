"""Script para cargar logros predefinidos en la base de datos."""

import asyncio

from sqlalchemy import select

from app.database import async_session
from app.models.ranking import Achievement

# Logros predefinidos del sistema
ACHIEVEMENTS_SEED = [
    # === PRÁCTICA ===
    {
        "code": "first_lesson",
        "name": "Primera Nota",
        "description": "Completá tu primera lección",
        "icon": "music_note",
        "category": "practice",
        "xp_reward": 20,
        "requirement_type": "count",
        "requirement_value": 1,
        "rarity": "common",
        "order": 1,
    },
    {
        "code": "practice_10",
        "name": "Estudiante Dedicado",
        "description": "Completá 10 lecciones",
        "icon": "school",
        "category": "practice",
        "xp_reward": 50,
        "requirement_type": "count",
        "requirement_value": 10,
        "rarity": "common",
        "order": 2,
    },
    {
        "code": "practice_50",
        "name": "Pianista en Formación",
        "description": "Completá 50 lecciones",
        "icon": "piano",
        "category": "practice",
        "xp_reward": 150,
        "requirement_type": "count",
        "requirement_value": 50,
        "rarity": "rare",
        "order": 3,
    },
    {
        "code": "practice_100",
        "name": "Maestro del Teclado",
        "description": "Completá 100 lecciones",
        "icon": "emoji_events",
        "category": "practice",
        "xp_reward": 500,
        "requirement_type": "count",
        "requirement_value": 100,
        "rarity": "epic",
        "order": 4,
    },
    {
        "code": "practice_500",
        "name": "Virtuoso",
        "description": "Completá 500 lecciones",
        "icon": "stars",
        "category": "practice",
        "xp_reward": 2000,
        "requirement_type": "count",
        "requirement_value": 500,
        "rarity": "legendary",
        "order": 5,
    },
    # === RACHA ===
    {
        "code": "streak_3",
        "name": "En Racha",
        "description": "Practicá 3 días seguidos",
        "icon": "local_fire_department",
        "category": "streak",
        "xp_reward": 30,
        "requirement_type": "streak",
        "requirement_value": 3,
        "rarity": "common",
        "order": 1,
    },
    {
        "code": "streak_7",
        "name": "Semana Perfecta",
        "description": "Practicá 7 días seguidos",
        "icon": "whatshot",
        "category": "streak",
        "xp_reward": 100,
        "requirement_type": "streak",
        "requirement_value": 7,
        "rarity": "rare",
        "order": 2,
    },
    {
        "code": "streak_30",
        "name": "Imparable",
        "description": "Practicá 30 días seguidos",
        "icon": "military_tech",
        "category": "streak",
        "xp_reward": 500,
        "requirement_type": "streak",
        "requirement_value": 30,
        "rarity": "epic",
        "order": 3,
    },
    {
        "code": "streak_100",
        "name": "Leyenda",
        "description": "Practicá 100 días seguidos",
        "icon": "diamond",
        "category": "streak",
        "xp_reward": 2000,
        "requirement_type": "streak",
        "requirement_value": 100,
        "rarity": "legendary",
        "order": 4,
    },
    # === SCORE ===
    {
        "code": "first_perfect",
        "name": "Perfección",
        "description": "Obtené 100% en una lección",
        "icon": "star",
        "category": "score",
        "xp_reward": 50,
        "requirement_type": "score",
        "requirement_value": 1,
        "rarity": "rare",
        "order": 1,
    },
    {
        "code": "perfect_10",
        "name": "Precisión Absoluta",
        "description": "Obtené 100% en 10 lecciones",
        "icon": "auto_awesome",
        "category": "score",
        "xp_reward": 300,
        "requirement_type": "score",
        "requirement_value": 10,
        "rarity": "epic",
        "order": 2,
    },
    {
        "code": "score_avg_90",
        "name": "Consistente",
        "description": "Mantené un promedio general de 90%+",
        "icon": "trending_up",
        "category": "score",
        "xp_reward": 200,
        "requirement_type": "special",
        "requirement_value": 90,
        "rarity": "rare",
        "order": 3,
    },
    # === SOCIAL ===
    {
        "code": "first_post",
        "name": "Social",
        "description": "Publicá tu primer post",
        "icon": "feed",
        "category": "social",
        "xp_reward": 15,
        "requirement_type": "count",
        "requirement_value": 1,
        "rarity": "common",
        "order": 1,
    },
    {
        "code": "followers_10",
        "name": "Influyente",
        "description": "Conseguí 10 seguidores",
        "icon": "groups",
        "category": "social",
        "xp_reward": 100,
        "requirement_type": "count",
        "requirement_value": 10,
        "rarity": "rare",
        "order": 2,
    },
    {
        "code": "followers_100",
        "name": "Estrella",
        "description": "Conseguí 100 seguidores",
        "icon": "celebration",
        "category": "social",
        "xp_reward": 500,
        "requirement_type": "count",
        "requirement_value": 100,
        "rarity": "epic",
        "order": 3,
    },
    # === MILESTONE ===
    {
        "code": "level_5",
        "name": "Nivel 5",
        "description": "Alcanzá el nivel 5",
        "icon": "upgrade",
        "category": "milestone",
        "xp_reward": 50,
        "requirement_type": "count",
        "requirement_value": 5,
        "rarity": "common",
        "order": 1,
    },
    {
        "code": "level_10",
        "name": "Nivel 10",
        "description": "Alcanzá el nivel 10",
        "icon": "rocket_launch",
        "category": "milestone",
        "xp_reward": 200,
        "requirement_type": "count",
        "requirement_value": 10,
        "rarity": "rare",
        "order": 2,
    },
    {
        "code": "level_25",
        "name": "Nivel 25",
        "description": "Alcanzá el nivel 25",
        "icon": "workspace_premium",
        "category": "milestone",
        "xp_reward": 1000,
        "requirement_type": "count",
        "requirement_value": 25,
        "rarity": "epic",
        "order": 3,
    },
    {
        "code": "hours_10",
        "name": "10 Horas",
        "description": "Acumulá 10 horas de práctica",
        "icon": "timer",
        "category": "milestone",
        "xp_reward": 150,
        "requirement_type": "count",
        "requirement_value": 600,
        "rarity": "rare",
        "order": 4,
    },
    {
        "code": "hours_100",
        "name": "100 Horas",
        "description": "Acumulá 100 horas de práctica",
        "icon": "hourglass_top",
        "category": "milestone",
        "xp_reward": 1000,
        "requirement_type": "count",
        "requirement_value": 6000,
        "rarity": "legendary",
        "order": 5,
    },
]


async def seed_achievements():
    """Insertar logros predefinidos en la base de datos."""
    async with async_session() as db:
        try:
            inserted = 0
            skipped = 0

            for ach_data in ACHIEVEMENTS_SEED:
                # Verificar si ya existe
                result = await db.execute(
                    select(Achievement).where(Achievement.code == ach_data["code"])
                )
                existing = result.scalar_one_or_none()

                if existing:
                    skipped += 1
                    continue

                achievement = Achievement(**ach_data)
                db.add(achievement)
                inserted += 1

            await db.commit()
            print(f"✅ Logros: {inserted} insertados, {skipped} ya existían.")

        except Exception as e:
            await db.rollback()
            print(f"❌ Error al insertar logros: {e}")
            raise


if __name__ == "__main__":
    asyncio.run(seed_achievements())
