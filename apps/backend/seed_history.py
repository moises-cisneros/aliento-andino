"""Seed histórico (~1 año) para que TODOS los dashboards del admin se vean poblados.

Reseed limpio de los datos de DEMO (preserva admins y emutest@pv.com):
- Usuarios backdateados hasta 365 días con sesgo a lo reciente (curva de altas).
- Suscripciones coherentes: premium activos, trials, churned (premium vencido).
- Miles de prácticas distribuidas a diario (parte con ai_feedback).
- ai_usage_logs alineadas a las prácticas con feedback + tutor (costo IA real).
- XP/niveles/logros, social (follows, posts, comments, likes, comment-likes,
  guardados, hashtags), reportes, notificaciones y auditoría de admin.
- Back-fill de todos los counters al final.

Coherencia: ningún evento antes del alta del usuario; started_at < expires_at;
hijos después del padre. Idempotente vía reseed (borra y vuelve a crear).

Uso:
    venv/Scripts/python.exe seed_history.py            # local
Requiere lecciones y logros ya sembrados (seed_lessons.py / seed_achievements.py)
y la DB migrada (alembic upgrade head).
"""

import asyncio
import os
import random
import uuid
from datetime import UTC, date, datetime, timedelta

from sqlalchemy import delete, func, select, text

from app.database import async_session
from app.models.ai_usage import AiUsageLog
from app.models.audit_log import AdminAuditLog
from app.models.hashtag import Hashtag, PostHashtag
from app.models.lesson import Lesson, PracticeSession
from app.models.notification import Notification, NotificationToken
from app.models.ranking import Achievement, UserAchievement, UserXP
from app.models.social import (
    Comment,
    CommentLike,
    Follow,
    Like,
    Post,
    Report,
    SavedPost,
)
from app.models.user import RefreshToken, User
from app.utils.security import hash_password

# Reutilizar contenido realista del seed existente.
from seed_all import (
    BIOS,
    COMMENT_CONTENTS,
    FIRST_NAMES,
    LAST_NAMES,
    POST_CONTENTS,
    REPORT_REASONS,
)

# ── Parámetros de volumen / profundidad ──────────────────────────────────
NEW_USERS = 230  # usuarios nuevos a crear (además de admin + emutest)
DAYS = 365  # profundidad histórica
SESSIONS_PER_USER = (8, 60)  # rango por usuario (según actividad)
FEEDBACK_RATE = 0.35  # % de prácticas con ai_feedback (sobre todo premium)
TUTOR_CALLS = 600  # llamadas al tutor Vivi (ai_usage kind=tutor)
AUDIT_ENTRIES = 320  # entradas de auditoría
PRESERVE_EMAILS = {"emutest@pv.com"}

# Modo de ejecución:
#   "reset"  (default, LOCAL): borra los datos de demo y reseedea limpio.
#   "append" (PROD-SEGURO): NO borra nada; crea usuarios de demo marcados con
#            @demo.aliento-andino.com (idempotente, removibles con un solo DELETE).
MODE = os.getenv("SEED_MODE", "reset").lower()
DEMO_DOMAIN = "demo.aliento-andino.com"
EMAIL_DOMAIN = DEMO_DOMAIN if MODE == "append" else "example.com"

NOW = datetime.now(UTC)
TODAY = date.today()
WEEK_START = TODAY - timedelta(days=TODAY.weekday())  # lunes de esta semana

PLAN_DAYS = {"monthly": 30, "annual": 365}

HASHTAGS = [
    "piano",
    "practica",
    "escalas",
    "acordes",
    "jazz",
    "clasica",
    "chopin",
    "principiante",
    "ritmo",
    "melodia",
    "progreso",
    "motivacion",
    "teoria",
    "improvisacion",
    "tecnica",
]

AI_FEEDBACK_SAMPLES = [
    "¡Buen trabajo! Tu precisión mejoró respecto a intentos previos. Enfocate en mantener el tempo estable en los compases finales.",
    "Vas muy bien con las notas, pero el tempo se aceleró en la segunda mitad. Probá practicar con metrónomo a una velocidad menor.",
    "Excelente precisión. El siguiente paso es trabajar la fluidez entre acordes para que la transición suene más natural.",
    "Cometiste algunos errores en las notas agudas. Repetí esa sección lentamente antes de subir el tempo.",
    "Gran progreso en la mano izquierda. Seguí reforzando la coordinación entre ambas manos.",
    "Tu timing fue muy bueno. Para la próxima, prestá atención a la dinámica: variá la intensidad para darle expresión.",
]

AUDIT_ACTIONS = [
    ("user.ban", "user", {"reason": "spam reiterado"}),
    ("user.unban", "user", None),
    ("user.grant_admin", "user", {"is_admin": True}),
    ("user.reset_password", "user", {"email": "demo@pv.com"}),
    ("subscription.grant", "user", {"plan": "annual"}),
    ("subscription.cancel", "user", None),
    ("post.delete", "post", None),
    ("comment.delete", "comment", None),
    ("report.update", "report", {"status": "reviewed"}),
    ("config.update", "config", {"price_monthly": 4.99}),
    ("announcement.send", "announcement", {"segment": "all", "recipients": 230}),
]

NOTIF_TYPES = [
    ("like", "A alguien le gustó tu publicación ❤️", "Tu post recibió un nuevo like."),
    ("comment", "Nuevo comentario 💬", "Comentaron tu publicación."),
    ("follow", "Tenés un nuevo seguidor 👤", "Alguien empezó a seguirte."),
    ("achievement", "¡Logro desbloqueado! 🏆", "Desbloqueaste un nuevo logro."),
    ("announcement", "Novedad de Aliento Andino 📣", "Tenemos una nueva función para vos."),
    ("streak_warning", "¡Tu racha está por romperse! 🔥", "No pierdas tu racha, practicá hoy."),
    ("mention", "Te mencionaron 📌", "Alguien te mencionó en un comentario."),
]


# ── Helpers de fecha ─────────────────────────────────────────────────────
def weighted_backdate(max_days: int = DAYS) -> datetime:
    """Fecha en los últimos max_days con FUERTE sesgo a lo reciente."""
    r = random.random()
    days = int(max_days * (r**2.0))  # más densidad cerca de hoy
    # leve boost de fin de semana
    dt = NOW - timedelta(
        days=days,
        hours=random.randint(0, 23),
        minutes=random.randint(0, 59),
    )
    return dt


def date_after(start: datetime, max_days: int = DAYS) -> datetime:
    """Fecha entre `start` y ahora, con sesgo a lo reciente (>= start)."""
    if start.tzinfo is None:
        start = start.replace(tzinfo=UTC)
    span = (NOW - start).total_seconds()
    if span <= 0:
        return NOW
    r = random.random() ** 1.6  # sesgo a lo reciente dentro del rango del user
    return start + timedelta(seconds=span * (1 - r))


# ── Reset de datos de demo ───────────────────────────────────────────────
async def reset_demo_data(db) -> None:
    print("🧹 Limpiando datos de demo (preservando admin + emutest)...")
    # IDs de usuarios a borrar (no admin, no preservados).
    to_delete_subq = select(User.id).where(
        User.is_admin.is_(False),
        User.email.notin_(PRESERVE_EMAILS),
    )
    # Borrar tablas hijas (todas, se regeneran).
    for model in (
        AiUsageLog,
        AdminAuditLog,
        Notification,
        NotificationToken,
        SavedPost,
        CommentLike,
        PostHashtag,
        Like,
        Comment,
        Report,
        Post,
        Follow,
        UserAchievement,
        UserXP,
        PracticeSession,
        Hashtag,
    ):
        await db.execute(delete(model))
    # Refresh tokens de los usuarios a borrar (evita FK).
    await db.execute(delete(RefreshToken).where(RefreshToken.user_id.in_(to_delete_subq)))
    # Finalmente, los usuarios de demo.
    res = await db.execute(
        delete(User).where(
            User.is_admin.is_(False),
            User.email.notin_(PRESERVE_EMAILS),
        )
    )
    await db.commit()
    print(f"   ✅ Datos de demo borrados ({res.rowcount} usuarios)")


# ── Usuarios + suscripciones ─────────────────────────────────────────────
async def seed_users(db) -> list[User]:
    print(f"👥 Creando {NEW_USERS} usuarios con historia de ~{DAYS} días...")
    used_emails = set()
    used_usernames = set()
    rows = (await db.execute(select(User.email, User.username))).all()
    for e, u in rows:
        used_emails.add(e)
        used_usernames.add(u)

    users: list[User] = []
    skills = ["beginner", "beginner", "intermediate", "intermediate", "advanced"]
    for i in range(NEW_USERS):
        fn = random.choice(FIRST_NAMES)
        ln = random.choice(LAST_NAMES)
        base = f"{fn.lower()}.{ln.lower()}".replace(" ", "")
        username = base
        while username in used_usernames:
            username = f"{base}{random.randint(1, 9999)}"
        email = f"{username}@{EMAIL_DOMAIN}"
        while email in used_emails:
            email = f"{username}{random.randint(1, 999)}@{EMAIL_DOMAIN}"
        used_emails.add(email)
        used_usernames.add(username)

        created = weighted_backdate(DAYS)
        u = User(
            id=uuid.uuid4(),
            email=email,
            username=username,
            full_name=f"{fn} {ln}",
            hashed_password=hash_password("Demo1234!"),
            bio=random.choice(BIOS),
            avatar_url=None,
            is_active=True,
            is_verified=random.random() > 0.25,
            skill_level=random.choice(skills),
            auth_provider="local",
            created_at=created,
        )
        _assign_subscription(u, created)
        db.add(u)
        users.append(u)

    # Baneados: 8-15 de los menos recientes.
    num_ban = random.randint(8, 15)
    for u in random.sample(users, num_ban):
        u.is_banned = True
        u.ban_reason = random.choice(
            [
                "Spam reiterado",
                "Lenguaje ofensivo",
                "Acoso a otros usuarios",
                "Contenido inapropiado",
                "Suplantación de identidad",
            ]
        )

    await db.commit()
    premium = sum(
        1
        for u in users
        if u.subscription_status == "premium"
        and u.subscription_expires_at
        and u.subscription_expires_at > NOW
    )
    print(f"   ✅ {len(users)} usuarios | premium activos: {premium} | baneados: {num_ban}")
    return users


def _assign_subscription(u: User, created: datetime) -> None:
    """Distribución: ~20% premium activo, ~8% trial, ~12% churned, resto free."""
    roll = random.random()
    if roll < 0.20:  # premium activo
        plan = random.choices(["monthly", "annual"], weights=[3, 2])[0]
        dur = PLAN_DAYS[plan]
        # started en los últimos `dur` días → expires en el futuro
        offset = random.randint(0, max(1, dur - 5))
        started = NOW - timedelta(days=offset)
        if started < created:
            started = created
        u.subscription_status = "premium"
        u.subscription_plan = plan
        u.subscription_started_at = started
        u.subscription_expires_at = started + timedelta(days=dur)
        u.subscription_trial_used = True
    elif roll < 0.28:  # trial activo
        started = NOW - timedelta(days=random.randint(0, 6))
        if started < created:
            started = created
        u.subscription_status = "premium"
        u.subscription_plan = "trial"
        u.subscription_started_at = started
        u.subscription_expires_at = started + timedelta(days=7)
        u.subscription_trial_used = True
    elif roll < 0.40:  # churned: premium vencido
        # Si el usuario es muy nuevo, no tiene historia de churn → free.
        if (NOW - created).days < 40:
            u.subscription_status = "free"
            u.subscription_trial_used = random.random() < 0.3
            return
        plan = random.choices(["monthly", "annual"], weights=[3, 1])[0]
        dur = PLAN_DAYS[plan]
        # expires en el pasado; started = expires - dur (después del alta)
        expires = NOW - timedelta(days=random.randint(1, 120))
        started = expires - timedelta(days=dur)
        if started < created:
            started = created
            expires = min(NOW - timedelta(days=1), started + timedelta(days=dur))
        u.subscription_status = "premium"
        u.subscription_plan = plan
        u.subscription_started_at = started
        u.subscription_expires_at = expires
        u.subscription_trial_used = True
    else:  # free
        u.subscription_status = "free"
        u.subscription_trial_used = random.random() < 0.2


# ── Prácticas ────────────────────────────────────────────────────────────
async def seed_practice(db, users, lessons) -> list[PracticeSession]:
    print("🎹 Generando prácticas distribuidas en el año...")
    sessions: list[PracticeSession] = []
    for u in users:
        if u.is_banned and random.random() < 0.5:
            continue
        # Más sesiones si es premium / más antiguo.
        base_lo, base_hi = SESSIONS_PER_USER
        if u.subscription_status == "premium":
            base_lo, base_hi = base_lo + 6, base_hi
        n = random.randint(base_lo, base_hi)
        for _ in range(n):
            lesson = random.choice(lessons)
            total_notes = len(lesson.notes) if lesson.notes else random.randint(6, 16)
            score = round(min(100.0, max(35.0, random.gauss(78, 16))), 1)
            correct = int(total_notes * score / 100)
            wrong = random.randint(0, max(0, total_notes - correct))
            missed = max(0, total_notes - correct - wrong)
            tempo = lesson.tempo_bpm or 80
            avg_tempo = round(random.uniform(tempo * 0.7, tempo * 1.2), 1)
            tempo_acc = round(max(0, 100 - abs(avg_tempo - tempo) / tempo * 100), 1)
            created = date_after(u.created_at, DAYS)
            # ai_feedback sobre todo en premium.
            has_fb = random.random() < (
                FEEDBACK_RATE + (0.25 if u.subscription_status == "premium" else 0)
            )
            s = PracticeSession(
                id=uuid.uuid4(),
                user_id=u.id,
                lesson_id=lesson.id,
                score=score,
                correct_notes=correct,
                total_notes=total_notes,
                wrong_notes=wrong,
                missed_notes=missed,
                average_tempo=avg_tempo,
                expected_tempo=tempo,
                tempo_accuracy=tempo_acc,
                total_time_seconds=round(random.uniform(30, 320), 1),
                completed=random.random() > 0.08,
                ai_feedback=random.choice(AI_FEEDBACK_SAMPLES) if has_fb else None,
                created_at=created,
            )
            db.add(s)
            sessions.append(s)
    await db.commit()
    with_fb = sum(1 for s in sessions if s.ai_feedback)
    print(f"   ✅ {len(sessions)} prácticas | con feedback IA: {with_fb}")
    return sessions


# ── ai_usage_logs (tokens reales) ────────────────────────────────────────
async def seed_ai_usage(db, sessions, users) -> None:
    print("🤖 Registrando uso real de IA (tokens)...")
    rows = []
    # 1 entrada por práctica con feedback, alineada en tiempo.
    for s in sessions:
        if not s.ai_feedback:
            continue
        inp = random.randint(380, 620)
        out = random.randint(60, 160)
        rows.append(
            AiUsageLog(
                id=uuid.uuid4(),
                kind="practice_feedback",
                model="gemini-2.5-flash",
                input_tokens=inp,
                output_tokens=out,
                total_tokens=inp + out,
                user_id=s.user_id,
                created_at=s.created_at,
            )
        )
    # Llamadas al tutor Vivi.
    active = [u for u in users if not u.is_banned]
    for _ in range(TUTOR_CALLS):
        u = random.choice(active)
        inp = random.randint(700, 1600)
        out = random.randint(120, 420)
        rows.append(
            AiUsageLog(
                id=uuid.uuid4(),
                kind="tutor",
                model="gemini-2.5-flash",
                input_tokens=inp,
                output_tokens=out,
                total_tokens=inp + out,
                user_id=u.id,
                created_at=date_after(u.created_at, DAYS),
            )
        )
    db.add_all(rows)
    await db.commit()
    print(f"   ✅ {len(rows)} registros de uso de IA")


# ── XP derivado de las prácticas ─────────────────────────────────────────
async def seed_xp(db, users, sessions) -> None:
    print("📊 Calculando XP, niveles y rachas...")
    by_user: dict[uuid.UUID, list[PracticeSession]] = {}
    for s in sessions:
        by_user.setdefault(s.user_id, []).append(s)

    records = []
    for u in users:
        us = by_user.get(u.id, [])
        n = len(us)
        minutes = round(sum(s.total_time_seconds for s in us) / 60.0, 1)
        avg = round(sum(s.score for s in us) / n, 1) if n else 0.0
        perfects = sum(1 for s in us if s.score >= 99.0)
        lessons_done = len({s.lesson_id for s in us if s.score >= 80})
        total_xp = int(n * 35 + perfects * 50 + lessons_done * 20)
        level = max(1, min(50, 1 + total_xp // 500))
        last_dt = max((s.created_at for s in us), default=None)
        last_date = last_dt.date() if last_dt else None
        # Racha activa solo si practicó hoy/ayer.
        if last_date and (TODAY - last_date).days <= 1:
            streak = random.randint(1, 45)
        else:
            streak = 0
        weekly = sum(
            35 for s in us if (s.created_at.date() if s.created_at else TODAY) >= WEEK_START
        )
        records.append(
            UserXP(
                id=uuid.uuid4(),
                user_id=u.id,
                total_xp=total_xp,
                weekly_xp=min(weekly, total_xp),
                level=level,
                current_streak=streak,
                longest_streak=max(streak, random.randint(streak, streak + 20)),
                total_practice_sessions=n,
                total_practice_minutes=minutes,
                total_lessons_completed=lessons_done,
                total_perfect_scores=perfects,
                average_score=avg,
                last_practice_date=last_date,
                week_start_date=WEEK_START,
                created_at=u.created_at,
            )
        )
        u.xp_level = level
    db.add_all(records)
    await db.commit()
    print(f"   ✅ {len(records)} registros de XP")


# ── Logros desbloqueados ─────────────────────────────────────────────────
async def seed_achievements(db, users) -> None:
    print("🏆 Desbloqueando logros...")
    achs = list(
        (
            await db.execute(
                select(Achievement)
                .where(Achievement.is_active.is_(True))
                .order_by(Achievement.requirement_value.asc())
            )
        )
        .scalars()
        .all()
    )
    if not achs:
        print("   ⚠️  No hay logros. Corré seed_achievements.py primero. (saltando)")
        return
    xps = {x.user_id: x for x in (await db.execute(select(UserXP))).scalars().all()}
    rows = []
    for u in users:
        x = xps.get(u.id)
        if not x:
            continue
        # Cuántos logros según actividad (los más fáciles primero).
        k = min(len(achs), int(x.total_practice_sessions / 6) + random.randint(0, 3))
        for a in achs[:k]:
            unlocked = date_after(u.created_at, DAYS)
            rows.append(
                UserAchievement(
                    id=uuid.uuid4(),
                    user_id=u.id,
                    achievement_id=a.id,
                    unlocked_at=unlocked,
                )
            )
    db.add_all(rows)
    await db.commit()
    print(f"   ✅ {len(rows)} logros desbloqueados")


# ── Social ───────────────────────────────────────────────────────────────
async def seed_social(db, users):
    print("💬 Generando social (follows, posts, comments, likes, hashtags)...")
    active = [u for u in users if not u.is_banned]

    # Hashtags
    tag_objs = {
        t: Hashtag(id=uuid.uuid4(), tag=t, created_at=weighted_backdate(DAYS)) for t in HASHTAGS
    }
    db.add_all(tag_objs.values())

    # Follows
    follows = set()
    follow_rows = []
    for u in active:
        n = random.randint(2, min(20, len(active) - 1))
        for tgt in random.sample([x for x in active if x.id != u.id], n):
            key = (u.id, tgt.id)
            if key in follows:
                continue
            follows.add(key)
            follow_rows.append(
                Follow(
                    id=uuid.uuid4(),
                    follower_id=u.id,
                    following_id=tgt.id,
                    created_at=date_after(max(u.created_at, tgt.created_at), DAYS),
                )
            )
    db.add_all(follow_rows)

    # Posts (60% de los usuarios postean, 1-6 c/u); ~30% con imagen.
    posts = []
    media_seed = 1000
    for u in active:
        if random.random() > 0.6:
            continue
        for _ in range(random.randint(1, 6)):
            has_media = random.random() < 0.30
            media_seed += 1
            posts.append(
                Post(
                    id=uuid.uuid4(),
                    user_id=u.id,
                    content=random.choice(POST_CONTENTS),
                    post_type="image" if has_media else "text",
                    media_url=f"https://picsum.photos/seed/pv{media_seed}/800/600"
                    if has_media
                    else None,
                    media_thumbnail_url=f"https://picsum.photos/seed/pv{media_seed}/320/240"
                    if has_media
                    else None,
                    created_at=date_after(u.created_at, DAYS),
                )
            )
    db.add_all(posts)
    # Persistir padres (hashtags, follows, posts) antes de sus hijos (FK).
    await db.flush()

    # PostHashtags (~45% de posts, 1-3 tags)
    ph_rows = []
    for p in posts:
        if random.random() > 0.45:
            continue
        for t in random.sample(HASHTAGS, random.randint(1, 3)):
            ph_rows.append(
                PostHashtag(
                    id=uuid.uuid4(),
                    post_id=p.id,
                    hashtag_id=tag_objs[t].id,
                    created_at=p.created_at,
                )
            )
    db.add_all(ph_rows)

    # Comments (cada post 0-6) top-level
    comments = []
    by_post: dict[uuid.UUID, list[Comment]] = {}
    for p in posts:
        for _ in range(random.randint(0, 6)):
            cu = random.choice(active)
            c = Comment(
                id=uuid.uuid4(),
                post_id=p.id,
                user_id=cu.id,
                content=random.choice(COMMENT_CONTENTS),
                created_at=date_after(p.created_at, DAYS),
            )
            comments.append(c)
            by_post.setdefault(p.id, []).append(c)

    # Replies anidadas: ~25% de los comentarios reciben 1-2 respuestas.
    replies = []
    for c in comments:
        if random.random() > 0.25:
            continue
        for _ in range(random.randint(1, 2)):
            ru = random.choice(active)
            replies.append(
                Comment(
                    id=uuid.uuid4(),
                    post_id=c.post_id,
                    user_id=ru.id,
                    parent_comment_id=c.id,
                    content=random.choice(COMMENT_CONTENTS),
                    created_at=date_after(c.created_at, DAYS),
                )
            )
    comments.extend(replies)
    db.add_all(comments)
    # Persistir comments antes de comment_likes (FK).
    await db.flush()

    # Likes a posts (UNIQUE post+user)
    like_rows = []
    seen = set()
    for p in posts:
        n = random.randint(0, min(40, len(active)))
        for lu in random.sample(active, n):
            key = (p.id, lu.id)
            if key in seen:
                continue
            seen.add(key)
            like_rows.append(
                Like(
                    id=uuid.uuid4(),
                    post_id=p.id,
                    user_id=lu.id,
                    created_at=date_after(p.created_at, DAYS),
                )
            )
    db.add_all(like_rows)

    # Comment likes (UNIQUE comment+user)
    cl_rows = []
    seen_cl = set()
    for c in comments:
        for lu in random.sample(active, random.randint(0, 8)):
            key = (c.id, lu.id)
            if key in seen_cl:
                continue
            seen_cl.add(key)
            cl_rows.append(
                CommentLike(
                    id=uuid.uuid4(),
                    comment_id=c.id,
                    user_id=lu.id,
                    created_at=date_after(c.created_at, DAYS),
                )
            )
    db.add_all(cl_rows)

    # Saved posts (UNIQUE user+post)
    sp_rows = []
    seen_sp = set()
    for u in active:
        for p in random.sample(posts, min(len(posts), random.randint(0, 6))):
            key = (u.id, p.id)
            if key in seen_sp:
                continue
            seen_sp.add(key)
            sp_rows.append(
                SavedPost(
                    id=uuid.uuid4(),
                    user_id=u.id,
                    post_id=p.id,
                    created_at=date_after(p.created_at, DAYS),
                )
            )
    db.add_all(sp_rows)

    await db.commit()
    print(
        f"   ✅ follows={len(follow_rows)} posts={len(posts)} comments={len(comments)} "
        f"likes={len(like_rows)} comment_likes={len(cl_rows)} saved={len(sp_rows)} "
        f"hashtags={len(tag_objs)}"
    )
    return posts, comments


# ── Reportes ─────────────────────────────────────────────────────────────
async def seed_reports(db, users, posts, comments, admins) -> None:
    print("📋 Generando reportes de moderación...")
    active = [u for u in users if not u.is_banned]
    rows = []
    reviewer = admins[0] if admins else None
    descs = [
        "Contenido spam",
        "Lenguaje ofensivo",
        "Posible acoso",
        "Fuera de lugar",
        "Reincidente",
        None,
    ]
    for p in random.sample(posts, min(len(posts), random.randint(40, 70))):
        reporter = random.choice([u for u in active if u.id != p.user_id])
        status_val = random.choices(["pending", "reviewed", "dismissed"], weights=[5, 3, 2])[0]
        created = date_after(p.created_at, DAYS)
        rows.append(
            Report(
                id=uuid.uuid4(),
                reporter_id=reporter.id,
                post_id=p.id,
                reported_user_id=p.user_id,
                reason=random.choice(REPORT_REASONS),
                description=random.choice(descs),
                status=status_val,
                reviewed_by=reviewer.id if (status_val != "pending" and reviewer) else None,
                reviewed_at=(created + timedelta(days=random.randint(1, 5)))
                if status_val != "pending"
                else None,
                created_at=created,
            )
        )
    for c in random.sample(comments, min(len(comments), random.randint(10, 25))):
        reporter = random.choice([u for u in active if u.id != c.user_id])
        status_val = random.choices(["pending", "reviewed", "dismissed"], weights=[5, 3, 2])[0]
        created = date_after(c.created_at, DAYS)
        rows.append(
            Report(
                id=uuid.uuid4(),
                reporter_id=reporter.id,
                comment_id=c.id,
                reported_user_id=c.user_id,
                reason=random.choice(REPORT_REASONS),
                description=random.choice(descs),
                status=status_val,
                reviewed_by=reviewer.id if (status_val != "pending" and reviewer) else None,
                reviewed_at=(created + timedelta(days=random.randint(1, 5)))
                if status_val != "pending"
                else None,
                created_at=created,
            )
        )
    db.add_all(rows)
    await db.commit()
    print(f"   ✅ {len(rows)} reportes")


# ── Notificaciones ───────────────────────────────────────────────────────
async def seed_notifications(db, users) -> None:
    print("🔔 Generando notificaciones...")
    rows = []
    tokens = []
    for u in users:
        if u.is_banned:
            continue
        for _ in range(random.randint(4, 14)):
            t, title, body = random.choice(NOTIF_TYPES)
            created = date_after(u.created_at, 60)
            rows.append(
                Notification(
                    id=uuid.uuid4(),
                    user_id=u.id,
                    type=t,
                    title=title,
                    body=body,
                    data={"type": t},
                    is_read=random.random() < 0.6,
                    created_at=created,
                )
            )
        if random.random() < 0.5:
            tokens.append(
                NotificationToken(
                    id=uuid.uuid4(),
                    user_id=u.id,
                    token=f"demo-fcm-{uuid.uuid4().hex[:24]}",
                    platform="android",
                    created_at=u.created_at,
                )
            )
    db.add_all(rows)
    db.add_all(tokens)
    await db.commit()
    print(f"   ✅ {len(rows)} notificaciones | {len(tokens)} tokens push")


# ── Auditoría ────────────────────────────────────────────────────────────
async def seed_audit(db, users, posts, admins) -> None:
    print("📜 Generando registro de auditoría...")
    if not admins:
        print("   ⚠️  No hay admin para atribuir auditoría. (saltando)")
        return
    rows = []
    for _ in range(AUDIT_ENTRIES):
        admin = random.choice(admins)
        action, target_type, detail = random.choice(AUDIT_ACTIONS)
        if target_type == "user":
            target_id = str(random.choice(users).id)
        elif target_type == "post" and posts:
            target_id = str(random.choice(posts).id)
        else:
            target_id = None
        rows.append(
            AdminAuditLog(
                id=uuid.uuid4(),
                admin_id=admin.id,
                admin_email=admin.email,
                action=action,
                target_type=target_type,
                target_id=target_id,
                detail=detail,
                created_at=weighted_backdate(DAYS),
            )
        )
    db.add_all(rows)
    await db.commit()
    print(f"   ✅ {len(rows)} entradas de auditoría")


# ── Back-fill de counters ────────────────────────────────────────────────
async def backfill_counters(db) -> None:
    print("🔧 Back-fill de counters (followers, likes, comments, hashtags)...")
    # followers/following por usuario
    await db.execute(text_update_followers())
    await db.execute(text_update_following())
    await db.execute(text_update_posts_count())
    await db.execute(text_update_post_likes())
    await db.execute(text_update_post_comments())
    await db.execute(text_update_comment_likes())
    await db.execute(text_update_replies_count())
    await db.execute(text_update_hashtag_counts())
    await db.commit()
    print("   ✅ Counters sincronizados")


# Updates en SQL (UPDATE ... FROM subconsulta) para performance.
def text_update_followers():
    return text("""
        UPDATE users u SET followers_count = COALESCE(c.cnt, 0)
        FROM (SELECT following_id, COUNT(*) cnt FROM follows GROUP BY following_id) c
        WHERE u.id = c.following_id""")


def text_update_following():
    return text("""
        UPDATE users u SET following_count = COALESCE(c.cnt, 0)
        FROM (SELECT follower_id, COUNT(*) cnt FROM follows GROUP BY follower_id) c
        WHERE u.id = c.follower_id""")


def text_update_posts_count():
    return text("""
        UPDATE users u SET posts_count = COALESCE(c.cnt, 0)
        FROM (SELECT user_id, COUNT(*) cnt FROM posts WHERE is_active GROUP BY user_id) c
        WHERE u.id = c.user_id""")


def text_update_post_likes():
    return text("""
        UPDATE posts p SET likes_count = COALESCE(c.cnt, 0)
        FROM (SELECT post_id, COUNT(*) cnt FROM likes GROUP BY post_id) c
        WHERE p.id = c.post_id""")


def text_update_post_comments():
    return text("""
        UPDATE posts p SET comments_count = COALESCE(c.cnt, 0)
        FROM (SELECT post_id, COUNT(*) cnt FROM comments WHERE is_active GROUP BY post_id) c
        WHERE p.id = c.post_id""")


def text_update_comment_likes():
    return text("""
        UPDATE comments cm SET likes_count = COALESCE(c.cnt, 0)
        FROM (SELECT comment_id, COUNT(*) cnt FROM comment_likes GROUP BY comment_id) c
        WHERE cm.id = c.comment_id""")


def text_update_replies_count():
    return text("""
        UPDATE comments cm SET replies_count = COALESCE(c.cnt, 0)
        FROM (SELECT parent_comment_id, COUNT(*) cnt FROM comments
              WHERE parent_comment_id IS NOT NULL GROUP BY parent_comment_id) c
        WHERE cm.id = c.parent_comment_id""")


def text_update_hashtag_counts():
    return text("""
        UPDATE hashtags h SET posts_count = COALESCE(c.cnt, 0)
        FROM (SELECT hashtag_id, COUNT(*) cnt FROM post_hashtags GROUP BY hashtag_id) c
        WHERE h.id = c.hashtag_id""")


# ── Main ─────────────────────────────────────────────────────────────────
async def main():
    random.seed()  # no determinista
    print("=" * 60)
    print(f"🌱 SEED HISTÓRICO (~1 año) — Aliento Andino [modo={MODE}]")
    print("=" * 60)
    async with async_session() as db:
        lessons = list((await db.execute(select(Lesson))).scalars().all())
        if not lessons:
            print("❌ No hay lecciones. Corré seed_lessons.py primero.")
            return
        admins = list(
            (await db.execute(select(User).where(User.is_admin.is_(True)))).scalars().all()
        )

        if MODE == "append":
            # PROD-SEGURO: no borra nada. Guard de idempotencia.
            existing_demo = (
                await db.execute(
                    select(func.count())
                    .select_from(User)
                    .where(User.email.like(f"%@{DEMO_DOMAIN}"))
                )
            ).scalar() or 0
            if existing_demo > 0:
                print(
                    f"⏭️  Ya hay {existing_demo} usuarios de demo "
                    f"(@{DEMO_DOMAIN}). Nada que hacer (idempotente)."
                )
                return
            print(
                f"➕ Modo append: agregando demo SIN borrar nada. "
                f"Removible luego con: DELETE FROM users WHERE email LIKE '%@{DEMO_DOMAIN}';"
            )
        else:
            await reset_demo_data(db)
        users = await seed_users(db)
        sessions = await seed_practice(db, users, lessons)
        await seed_ai_usage(db, sessions, users)
        await seed_xp(db, users, sessions)
        await seed_achievements(db, users)
        posts, comments = await seed_social(db, users)
        await seed_reports(db, users, posts, comments, admins)
        await seed_notifications(db, users)
        await seed_audit(db, users, posts, admins)
        await backfill_counters(db)

        print("\n" + "=" * 60)
        print("✅ SEED HISTÓRICO COMPLETADO")
        print("=" * 60)
        for label, model in [
            ("Usuarios", User),
            ("Prácticas", PracticeSession),
            ("Uso IA", AiUsageLog),
            ("XP", UserXP),
            ("Logros", UserAchievement),
            ("Posts", Post),
            ("Comentarios", Comment),
            ("Likes", Like),
            ("Reportes", Report),
            ("Notificaciones", Notification),
            ("Auditoría", AdminAuditLog),
        ]:
            cnt = (await db.execute(select(func.count()).select_from(model))).scalar() or 0
            print(f"   {label}: {cnt}")


if __name__ == "__main__":
    asyncio.run(main())
