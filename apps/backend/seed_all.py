"""Script completo para poblar la base de datos con datos de demostración.

Genera:
- 50 usuarios con datos realistas
- XP y niveles para cada usuario
- Sesiones de práctica variadas
- Posts sociales, comentarios, likes y follows
- Logros desbloqueados para usuarios activos
"""

import asyncio
import random
from datetime import UTC, date, datetime, timedelta

from sqlalchemy import func, select

from app.database import async_session
from app.models.fingering import Fingering
from app.models.lesson import Lesson, PracticeSession
from app.models.ranking import Achievement, UserAchievement, UserXP
from app.models.social import Comment, Follow, Like, Post, Report
from app.models.user import User
from app.utils.security import hash_password

# ── Datos realistas de usuarios ──────────────────────────────────────────

FIRST_NAMES = [
    "Alejandro",
    "Valentina",
    "Sebastián",
    "Camila",
    "Mateo",
    "Isabella",
    "Santiago",
    "Sofía",
    "Daniel",
    "Mariana",
    "Andrés",
    "Lucía",
    "Diego",
    "Gabriela",
    "Nicolás",
    "Carolina",
    "Fernando",
    "Paula",
    "Miguel",
    "Andrea",
    "Carlos",
    "María",
    "José",
    "Elena",
    "David",
    "Laura",
    "Rafael",
    "Ana",
    "Pedro",
    "Julia",
    "Luis",
    "Natalia",
    "Jorge",
    "Daniela",
    "Roberto",
    "Catalina",
    "Eduardo",
    "Fernanda",
    "Marco",
    "Renata",
    "Pablo",
    "Verónica",
    "Tomás",
    "Claudia",
    "Ricardo",
    "Mónica",
    "Javier",
    "Silvia",
    "Emilio",
    "Patricia",
]

LAST_NAMES = [
    "García",
    "Rodríguez",
    "Martínez",
    "López",
    "González",
    "Hernández",
    "Pérez",
    "Sánchez",
    "Ramírez",
    "Torres",
    "Flores",
    "Rivera",
    "Gómez",
    "Díaz",
    "Cruz",
    "Morales",
    "Reyes",
    "Gutiérrez",
    "Ortiz",
    "Ramos",
    "Vargas",
    "Castillo",
    "Mendoza",
    "Rojas",
    "Herrera",
    "Medina",
    "Aguilar",
    "Peña",
    "Castro",
    "Jiménez",
    "Ruiz",
    "Delgado",
    "Romero",
    "Navarro",
    "Domínguez",
    "Vega",
    "Soto",
    "Guerrero",
    "Campos",
    "Espinoza",
    "Molina",
    "Contreras",
    "Sandoval",
    "Figueroa",
    "Córdoba",
    "Silva",
    "Ríos",
    "Acosta",
    "Valencia",
    "Paredes",
]

BIOS = [
    "Aprendiendo quena y zampoña desde cero 🎋",
    "Amante de la música andina tradicional",
    "Practicando el soplo y la embocadura todos los días",
    "Quenista aficionado, fan de la música del altiplano",
    "Estudiante de sikus y tarkas",
    "Autodidacta de la zampoña 🎵",
    "Buscando tocar mis melodías andinas favoritas",
    "Profesor de música explorando aerófonos andinos",
    "La música andina es mi pasión 🎶",
    "Practicando escalas pentatónicas y digitaciones",
    "Fan de los sikuris desde niño",
    "Empezando mi viaje con los vientos andinos",
    "Compositor en formación",
    "Músico de hobby, ingeniero de profesión",
    "Aprendiendo con Aliento Andino",
    None,
    None,
    None,
    None,
    None,  # Algunos sin bio
]

POST_CONTENTS = [
    "¡Acabo de completar mi primera lección de escalas en quena! 🎋",
    "Logré tocar la escala pentatónica de Sol sin errores de afinación 💪",
    "Practicando el diálogo Ira y Arca en la zampoña, ¡cada vez suena mejor!",
    "30 días seguidos practicando postura y soplo, ¡no paro! 🔥",
    "¿Alguien más practica de noche? El sonido de la quena es mágico 🌙",
    "Tip: calibrar el umbral de soplo antes de practicar ayuda mucho con la afinación",
    "¡Conseguí 100% de afinación en una lección por primera vez! ⭐",
    "La escala de Re en tarka me costó por la presión del aire, pero ya la domino",
    "Hoy descubrí que el control de respiración diafragmática cambia todo el sonido",
    "¡Nivel 5 desbloqueado! Seguimos creciendo con los vientos andinos 🚀",
    "Practicar 15 minutos al día de soplo limpio hace una gran diferencia",
    "¡Mi racha más larga hasta ahora: 7 días tocando sikus! 🎯",
    "Escuchando sikuris del altiplano para inspirarme antes de practicar",
    "Las notas agudas de la segunda octava en quena son mi nuevo reto",
    "¡Primera vez dominando la digitación de la tarka con buena postura!",
    "Compartiendo mi progreso: de 60% a 95% de estabilidad de afinación en Sol 📈",
    "¿Cuál es su instrumento favorito? A mí me fascina la zampoña",
    "Hoy practiqué 45 minutos de embocadura sin parar, nuevo récord personal",
    "La app me ayudó mucho a corregir la postura frente a la cámara",
    "¡Desbloqueé el logro 'Maestro del Siku'! 🏆",
    "Empecé hace un mes y ya domino la escala base de quena",
    "Los ejercicios de ritmo andino son muy divertidos",
    "Recomiendo empezar por las notas largas de calibración, dan mucha base",
    "¡Feliz de ser parte de esta comunidad de vientos andinos! 🎋❤️",
    "Hoy me animé a tocar un huayño para mi familia, les encantó",
    "Practicando el soplo suave y continuo en la zampoña",
    "¿Alguien tiene tips para la transición rápida entre tubos de zampoña?",
    "¡Mi primera semana perfecta de práctica! 7/7 días ✅",
    "La constancia en la embocadura es la clave, aunque sea 10 minutos al día",
    "Probando las lecciones avanzadas de quena, ¡son un reto! 💪",
]

COMMENT_CONTENTS = [
    "¡Felicidades! Sigue así 👏",
    "Increíble progreso, ¡bien hecho!",
    "Yo también estoy aprendiendo, ¡ánimo!",
    "Muy buen tip, lo voy a probar",
    "¡Qué genial! Yo apenas voy por las escalas",
    "Excelente, me motivas a practicar más",
    "¡Bravo! La constancia da resultados 🎵",
    "Me pasa igual, las noches son ideales para practicar",
    "Totalmente de acuerdo, la práctica hace al maestro",
    "¡Inspirador! Voy a intentar lo mismo",
    "Wow, 100%? Eso es impresionante 🌟",
    "Gracias por compartir tu experiencia",
    "¡Sigue adelante, vas muy bien!",
    "Qué buen consejo, me sirvió mucho",
    "¡La comunidad de Aliento Andino es genial!",
]

NOW = datetime.now(UTC)


def random_date_within(days_back: int) -> datetime:
    """Genera una fecha aleatoria dentro de los últimos N días."""
    delta = timedelta(
        days=random.randint(0, days_back),
        hours=random.randint(0, 23),
        minutes=random.randint(0, 59),
    )
    return NOW - delta


async def seed_users(db) -> list[User]:
    """Crear 50 usuarios con datos realistas."""
    print("👥 Creando usuarios...")

    # Verificar cuántos usuarios existen (excluyendo admin)
    result = await db.execute(
        select(func.count(User.id)).where(User.is_admin == False)  # noqa: E712
    )
    existing_count = result.scalar() or 0

    if existing_count >= 50:
        print(f"   Ya existen {existing_count} usuarios no-admin. Cargando existentes...")
        result = await db.execute(
            select(User).where(User.is_admin == False)  # noqa: E712
        )
        return list(result.scalars().all())

    users = []
    hashed = hash_password("Andino123!")  # Contraseña común para demo andino

    used_emails = set()
    used_usernames = set()

    # Cargar emails/usernames existentes
    result = await db.execute(select(User.email, User.username))
    for row in result.all():
        used_emails.add(row[0])
        used_usernames.add(row[1])

    names_pool = list(zip(FIRST_NAMES, LAST_NAMES))
    random.shuffle(names_pool)

    for i, (first, last) in enumerate(names_pool):
        if len(users) + existing_count >= 50:
            break

        full_name = f"{first} {last}"
        base_username = f"{first.lower().replace('é', 'e').replace('á', 'a').replace('í', 'i').replace('ó', 'o').replace('ú', 'u')}{last.lower()[:3].replace('á', 'a').replace('é', 'e').replace('í', 'i').replace('ó', 'o').replace('ú', 'u')}"
        username = base_username
        if username in used_usernames:
            username = f"{base_username}{random.randint(1, 99)}"
        if username in used_usernames:
            continue

        email = f"{username}@example.com"
        if email in used_emails:
            continue

        used_emails.add(email)
        used_usernames.add(username)

        days_ago = random.randint(1, 90)
        created_at = NOW - timedelta(days=days_ago)

        user = User(
            email=email,
            username=username,
            full_name=full_name,
            hashed_password=hashed,
            bio=random.choice(BIOS),
            is_active=True,
            is_admin=False,
            is_verified=random.random() > 0.3,  # 70% verificados
            auth_provider="local",
            xp_level=1,
            created_at=created_at,
        )
        db.add(user)
        users.append(user)

    await db.flush()
    print(f"   ✅ {len(users)} usuarios creados")

    # Retornar todos los no-admin
    result = await db.execute(
        select(User).where(User.is_admin == False)  # noqa: E712
    )
    return list(result.scalars().all())


async def seed_user_xp(db, users: list[User]) -> list[UserXP]:
    """Crear registros de XP para cada usuario con datos variados."""
    print("📊 Generando XP y niveles...")

    xp_records = []
    for user in users:
        # Verificar si ya tiene XP
        result = await db.execute(select(UserXP).where(UserXP.user_id == user.id))
        existing = result.scalar_one_or_none()
        if existing:
            xp_records.append(existing)
            continue

        # Generar XP variado según "antigüedad"
        days_active = (NOW - user.created_at).days if user.created_at else 30
        activity_level = random.choice(["low", "medium", "high", "very_high"])

        if activity_level == "low":
            total_xp = random.randint(0, 200)
            sessions = random.randint(0, 5)
            minutes = random.uniform(0, 30)
            lessons = random.randint(0, 3)
            streak = random.randint(0, 2)
            perfects = 0
        elif activity_level == "medium":
            total_xp = random.randint(200, 1500)
            sessions = random.randint(5, 30)
            minutes = random.uniform(30, 300)
            lessons = random.randint(3, 15)
            streak = random.randint(0, 7)
            perfects = random.randint(0, 3)
        elif activity_level == "high":
            total_xp = random.randint(1500, 5000)
            sessions = random.randint(30, 100)
            minutes = random.uniform(300, 1200)
            lessons = random.randint(10, 40)
            streak = random.randint(3, 30)
            perfects = random.randint(2, 10)
        else:  # very_high
            total_xp = random.randint(5000, 15000)
            sessions = random.randint(100, 300)
            minutes = random.uniform(1200, 6000)
            lessons = random.randint(30, 100)
            streak = random.randint(10, 60)
            perfects = random.randint(5, 25)

        level = max(1, total_xp // 500 + 1)
        weekly_xp = random.randint(0, min(total_xp, 800))
        avg_score = round(random.uniform(50, 98), 1) if sessions > 0 else 0.0
        last_practice = (
            (NOW - timedelta(days=random.randint(0, 14))).date() if sessions > 0 else None
        )

        xp = UserXP(
            user_id=user.id,
            total_xp=total_xp,
            weekly_xp=weekly_xp,
            level=level,
            current_streak=streak,
            longest_streak=max(streak, random.randint(streak, streak + 10)),
            total_practice_sessions=sessions,
            total_practice_minutes=round(minutes, 1),
            total_lessons_completed=lessons,
            total_perfect_scores=perfects,
            average_score=avg_score,
            last_practice_date=last_practice,
            week_start_date=date.today() - timedelta(days=date.today().weekday()),
        )
        db.add(xp)
        xp_records.append(xp)

        # Actualizar nivel en user
        user.xp_level = level

    await db.flush()
    print(f"   ✅ {len(xp_records)} registros de XP creados")
    return xp_records


async def seed_practice_sessions(db, users: list[User]) -> list[PracticeSession]:
    """Crear sesiones de práctica realistas."""
    print("🎶 Generando sesiones de práctica...")

    # Obtener lecciones disponibles
    result = await db.execute(select(Lesson))
    lessons = list(result.scalars().all())

    if not lessons:
        print("   ⚠️  No hay lecciones. Ejecuta seed_lessons.py primero.")
        return []

    # Verificar sesiones existentes
    result = await db.execute(select(func.count(PracticeSession.id)))
    existing = result.scalar() or 0

    if existing >= 200:
        print(f"   Ya existen {existing} sesiones de práctica.")
        return []

    sessions = []
    for user in users:
        # Cantidad de sesiones según su XP
        result = await db.execute(select(UserXP).where(UserXP.user_id == user.id))
        user_xp = result.scalar_one_or_none()
        num_sessions = min(
            user_xp.total_practice_sessions if user_xp else random.randint(1, 5),
            15,  # Máx por usuario para no saturar
        )

        for _ in range(num_sessions):
            lesson = random.choice(lessons)
            total_notes = len(lesson.notes) if lesson.notes else 8
            score = round(random.uniform(40, 100), 1)
            correct = int(total_notes * score / 100)
            wrong = random.randint(0, total_notes - correct)
            missed = total_notes - correct - wrong
            tempo_bpm = lesson.tempo_bpm or 80
            avg_tempo = round(random.uniform(tempo_bpm * 0.7, tempo_bpm * 1.2), 1)
            tempo_acc = round(max(0, 100 - abs(avg_tempo - tempo_bpm) / tempo_bpm * 100), 1)

            days_ago = random.randint(0, 60)
            created_at = NOW - timedelta(
                days=days_ago,
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59),
            )

            session = PracticeSession(
                user_id=user.id,
                lesson_id=lesson.id,
                score=score,
                correct_notes=correct,
                total_notes=total_notes,
                wrong_notes=wrong,
                missed_notes=missed,
                average_tempo=avg_tempo,
                expected_tempo=tempo_bpm,
                tempo_accuracy=tempo_acc,
                total_time_seconds=round(random.uniform(30, 300), 1),
                completed=random.random() > 0.1,  # 90% completadas
                created_at=created_at,
            )
            db.add(session)
            sessions.append(session)

    await db.flush()
    print(f"   ✅ {len(sessions)} sesiones de práctica creadas")
    return sessions


async def seed_social(db, users: list[User]) -> None:
    """Crear follows, posts, likes y comentarios."""
    print("💬 Generando datos sociales...")

    if len(users) < 2:
        print("   ⚠️  Se necesitan al menos 2 usuarios para datos sociales.")
        return

    # ── Follows ──
    result = await db.execute(select(func.count(Follow.id)))
    existing_follows = result.scalar() or 0

    follows_created = 0
    if existing_follows < 100:
        for user in users:
            num_following = random.randint(2, min(15, len(users) - 1))
            targets = random.sample([u for u in users if u.id != user.id], num_following)
            for target in targets:
                # Verificar si ya existe
                result = await db.execute(
                    select(Follow).where(
                        Follow.follower_id == user.id,
                        Follow.following_id == target.id,
                    )
                )
                if result.scalar_one_or_none():
                    continue

                follow = Follow(
                    follower_id=user.id,
                    following_id=target.id,
                    created_at=random_date_within(60),
                )
                db.add(follow)
                follows_created += 1

        await db.flush()

        # Actualizar contadores de followers/following
        for user in users:
            r1 = await db.execute(
                select(func.count(Follow.id)).where(Follow.following_id == user.id)
            )
            user.followers_count = r1.scalar() or 0

            r2 = await db.execute(
                select(func.count(Follow.id)).where(Follow.follower_id == user.id)
            )
            user.following_count = r2.scalar() or 0

        await db.flush()

    print(f"   ✅ {follows_created} follows creados")

    # ── Posts ──
    result = await db.execute(select(func.count(Post.id)))
    existing_posts = result.scalar() or 0

    posts_created_list = []
    if existing_posts < 50:
        active_users = random.sample(users, min(35, len(users)))
        for user in active_users:
            num_posts = random.randint(1, 4)
            for _ in range(num_posts):
                post = Post(
                    user_id=user.id,
                    content=random.choice(POST_CONTENTS),
                    post_type="text",
                    is_active=True,
                    created_at=random_date_within(45),
                )
                db.add(post)
                posts_created_list.append(post)

        await db.flush()

        # Actualizar posts_count
        for user in users:
            r = await db.execute(select(func.count(Post.id)).where(Post.user_id == user.id))
            user.posts_count = r.scalar() or 0

        await db.flush()

    print(f"   ✅ {len(posts_created_list)} posts creados")

    # Obtener todos los posts
    result = await db.execute(select(Post).where(Post.is_active == True))  # noqa: E712
    all_posts = list(result.scalars().all())

    # ── Likes ──
    result = await db.execute(select(func.count(Like.id)))
    existing_likes = result.scalar() or 0

    likes_created = 0
    if existing_likes < 100 and all_posts:
        for user in users:
            posts_to_like = random.sample(all_posts, min(random.randint(3, 12), len(all_posts)))
            for post in posts_to_like:
                if post.user_id == user.id:
                    continue
                result = await db.execute(
                    select(Like).where(
                        Like.user_id == user.id,
                        Like.post_id == post.id,
                    )
                )
                if result.scalar_one_or_none():
                    continue

                like = Like(
                    user_id=user.id,
                    post_id=post.id,
                    created_at=random_date_within(30),
                )
                db.add(like)
                likes_created += 1

        await db.flush()

        # Actualizar likes_count
        for post in all_posts:
            r = await db.execute(select(func.count(Like.id)).where(Like.post_id == post.id))
            post.likes_count = r.scalar() or 0

        await db.flush()

    print(f"   ✅ {likes_created} likes creados")

    # ── Comments ──
    result = await db.execute(select(func.count(Comment.id)))
    existing_comments = result.scalar() or 0

    comments_created = 0
    if existing_comments < 50 and all_posts:
        commented_posts = random.sample(all_posts, min(30, len(all_posts)))
        for post in commented_posts:
            num_comments = random.randint(1, 4)
            commenters = random.sample(
                [u for u in users if u.id != post.user_id], min(num_comments, len(users) - 1)
            )
            for commenter in commenters:
                comment = Comment(
                    post_id=post.id,
                    user_id=commenter.id,
                    content=random.choice(COMMENT_CONTENTS),
                    is_active=True,
                    created_at=random_date_within(30),
                )
                db.add(comment)
                comments_created += 1

        await db.flush()

        # Actualizar comments_count
        for post in all_posts:
            r = await db.execute(select(func.count(Comment.id)).where(Comment.post_id == post.id))
            post.comments_count = r.scalar() or 0

        await db.flush()

    print(f"   ✅ {comments_created} comentarios creados")


async def seed_achievements_for_users(db, users: list[User]) -> None:
    """Desbloquear logros para usuarios según su actividad."""
    print("🏆 Asignando logros a usuarios...")

    result = await db.execute(select(Achievement))
    achievements = list(result.scalars().all())

    if not achievements:
        print("   ⚠️  No hay logros en la BD. Ejecuta seed_achievements.py primero.")
        return

    result = await db.execute(select(func.count(UserAchievement.id)))
    existing = result.scalar() or 0

    if existing >= 50:
        print(f"   Ya existen {existing} logros desbloqueados.")
        return

    unlocked = 0
    for user in users:
        # Obtener XP del usuario
        result = await db.execute(select(UserXP).where(UserXP.user_id == user.id))
        user_xp = result.scalar_one_or_none()
        if not user_xp:
            continue

        eligible = []

        for ach in achievements:
            # Decidir si el usuario califica según su actividad
            qualifies = False

            if ach.category == "practice":
                if ach.requirement_value <= user_xp.total_lessons_completed:
                    qualifies = True
            elif ach.category == "streak":
                if ach.requirement_value <= user_xp.longest_streak:
                    qualifies = True
            elif ach.category == "score":
                if (
                    ach.code == "first_perfect"
                    and user_xp.total_perfect_scores >= 1
                    or ach.code == "perfect_10"
                    and user_xp.total_perfect_scores >= 10
                    or ach.code == "score_avg_90"
                    and user_xp.average_score >= 90
                ):
                    qualifies = True
            elif ach.category == "social":
                if (
                    ach.code == "first_post"
                    and user.posts_count >= 1
                    or ach.code == "followers_10"
                    and user.followers_count >= 10
                    or ach.code == "followers_100"
                    and user.followers_count >= 100
                ):
                    qualifies = True
            elif ach.category == "milestone":
                if (
                    ach.code == "level_5"
                    and user_xp.level >= 5
                    or ach.code == "level_10"
                    and user_xp.level >= 10
                    or ach.code == "level_25"
                    and user_xp.level >= 25
                    or ach.code == "hours_10"
                    and user_xp.total_practice_minutes >= 600
                    or ach.code == "hours_100"
                    and user_xp.total_practice_minutes >= 6000
                ):
                    qualifies = True

            if qualifies:
                eligible.append(ach)

        for ach in eligible:
            # Verificar si ya lo tiene
            result = await db.execute(
                select(UserAchievement).where(
                    UserAchievement.user_id == user.id,
                    UserAchievement.achievement_id == ach.id,
                )
            )
            if result.scalar_one_or_none():
                continue

            ua = UserAchievement(
                user_id=user.id,
                achievement_id=ach.id,
                unlocked_at=random_date_within(30),
            )
            db.add(ua)
            unlocked += 1

    await db.flush()
    print(f"   ✅ {unlocked} logros desbloqueados")


REPORT_REASONS = ["spam", "inappropriate", "harassment", "hate_speech", "other"]

REPORT_DESCRIPTIONS = [
    "Este post contiene spam y enlaces sospechosos",
    "Contenido inapropiado para la comunidad",
    "El usuario está acosando a otros miembros",
    "Lenguaje ofensivo y discriminatorio",
    "Publicidad no autorizada",
    "Contenido repetitivo/spam",
    "Información falsa o engañosa",
    "Comportamiento tóxico en los comentarios",
    "Suplantación de identidad",
    "Contenido que no tiene que ver con aerófonos andinos/música",
]

BAN_REASONS = [
    "Spam repetitivo después de múltiples advertencias",
    "Acoso persistente a otros usuarios",
    "Contenido ofensivo y discriminatorio reiterado",
    "Uso de lenguaje de odio",
    "Suplantación de identidad confirmada",
]


async def seed_banned_users(db, users: list[User]) -> None:
    """Banear algunos usuarios para datos de prueba."""
    print("🚫 Baneando usuarios de prueba...")

    already_banned = [u for u in users if u.is_banned]
    if len(already_banned) >= 3:
        print(f"   Ya hay {len(already_banned)} usuarios baneados.")
        return

    # Banear 3-5 usuarios aleatorios
    candidates = [u for u in users if not u.is_banned]
    num_to_ban = min(5, len(candidates))
    to_ban = random.sample(candidates, num_to_ban)

    for user in to_ban:
        user.is_banned = True
        user.is_active = False
        user.ban_reason = random.choice(BAN_REASONS)

    await db.flush()
    print(f"   ✅ {len(to_ban)} usuarios baneados")


async def seed_reports(db, users: list[User]) -> None:
    """Crear reportes de ejemplo."""
    print("📋 Generando reportes...")

    result = await db.execute(select(func.count(Report.id)))
    existing = result.scalar() or 0

    if existing >= 5:
        print(f"   Ya existen {existing} reportes.")
        return

    # Obtener posts activos
    result = await db.execute(select(Post).where(Post.is_active == True))  # noqa: E712
    all_posts = list(result.scalars().all())

    # Obtener comentarios activos
    result = await db.execute(select(Comment).where(Comment.is_active == True))  # noqa: E712
    all_comments = list(result.scalars().all())

    active_users = [u for u in users if not u.is_banned]
    reports_created = 0

    # ── Reportes de posts ──
    if all_posts:
        reported_posts = random.sample(all_posts, min(8, len(all_posts)))
        for post in reported_posts:
            reporter = random.choice([u for u in active_users if u.id != post.user_id])
            reason = random.choice(REPORT_REASONS)
            status_val = random.choice(["pending", "pending", "pending", "reviewed", "dismissed"])

            report = Report(
                reporter_id=reporter.id,
                post_id=post.id,
                reported_user_id=post.user_id,
                reason=reason,
                description=random.choice(REPORT_DESCRIPTIONS),
                status=status_val,
                created_at=random_date_within(20),
            )
            db.add(report)
            reports_created += 1

            # Marcar post como reportado
            post.is_reported = True

        await db.flush()

    # ── Reportes de comentarios ──
    if all_comments:
        reported_comments = random.sample(all_comments, min(5, len(all_comments)))
        for comment in reported_comments:
            reporter = random.choice([u for u in active_users if u.id != comment.user_id])
            reason = random.choice(REPORT_REASONS)
            status_val = random.choice(["pending", "pending", "reviewed", "dismissed"])

            report = Report(
                reporter_id=reporter.id,
                comment_id=comment.id,
                reported_user_id=comment.user_id,
                reason=reason,
                description=random.choice(REPORT_DESCRIPTIONS),
                status=status_val,
                created_at=random_date_within(15),
            )
            db.add(report)
            reports_created += 1

        await db.flush()

    # ── Reportes de usuarios ──
    some_users = random.sample(active_users, min(4, len(active_users)))
    for target_user in some_users:
        reporter = random.choice([u for u in active_users if u.id != target_user.id])
        reason = random.choice(REPORT_REASONS)

        report = Report(
            reporter_id=reporter.id,
            reported_user_id=target_user.id,
            reason=reason,
            description=random.choice(REPORT_DESCRIPTIONS),
            status=random.choice(["pending", "pending", "reviewed"]),
            created_at=random_date_within(10),
        )
        db.add(report)
        reports_created += 1

    await db.flush()
    print(f"   ✅ {reports_created} reportes creados")


async def main():
    """Ejecutar todo el seed."""
    print("=" * 60)
    print("🌱 SEED COMPLETO — Aliento Andino")
    print("=" * 60)

    # 0. Asegurar catálogo andino, digitaciones y logros del sistema
    print("🎋 Sembrando catálogo pedagógico andino...")
    from seed_lessons import seed_lessons

    await seed_lessons()

    print("🎶 Sembrando catálogo oficial de digitaciones andinas...")
    from seed_fingerings import seed_fingerings

    await seed_fingerings()

    print("🏆 Sembrando catálogo de logros...")
    from seed_achievements import seed_achievements

    await seed_achievements()

    async with async_session() as db:
        try:
            # 1. Usuarios
            users = await seed_users(db)

            # 2. XP y niveles
            await seed_user_xp(db, users)

            # 3. Sesiones de práctica
            await seed_practice_sessions(db, users)

            # 4. Social (follows, posts, likes, comments)
            await seed_social(db, users)

            # 5. Logros desbloqueados
            await seed_achievements_for_users(db, users)

            # 6. Usuarios baneados
            await seed_banned_users(db, users)

            # 7. Reportes (posts, comentarios, usuarios)
            await seed_reports(db, users)

            await db.commit()

            print("\n" + "=" * 60)
            print("✅ SEED COMPLETADO EXITOSAMENTE")
            print("=" * 60)

            # Resumen final
            for label, model in [
                ("Usuarios", User),
                ("Digitaciones", Fingering),
                ("Sesiones", PracticeSession),
                ("Posts", Post),
                ("Comentarios", Comment),
                ("Logros desbloqueados", UserAchievement),
                ("Reportes", Report),
            ]:
                r = await db.execute(select(func.count(model.id)))
                count = r.scalar() or 0
                print(f"   {label}: {count}")

            # Banned count
            r = await db.execute(
                select(func.count(User.id)).where(User.is_banned == True)  # noqa: E712
            )
            print(f"   Usuarios baneados: {r.scalar() or 0}")

        except Exception as e:
            await db.rollback()
            print(f"\n❌ Error durante el seed: {e}")
            import traceback

            traceback.print_exc()
            raise


if __name__ == "__main__":
    asyncio.run(main())
