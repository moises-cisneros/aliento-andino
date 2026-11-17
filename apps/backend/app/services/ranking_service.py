"""Servicio de lógica de negocio para rankings, XP y logros."""

import math
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta

from sqlalchemy import and_, distinct, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Lesson, PracticeSession
from app.models.ranking import Achievement, UserAchievement, UserXP
from app.models.social import Follow, Post
from app.models.user import User

# ===================== CÁLCULOS DE XP =====================

# Tope de congeladores de racha que un usuario puede acumular.
MAX_STREAK_FREEZES = 3


def calculate_session_xp(score: float, difficulty: str, is_completed: bool) -> int:
    """Calcular XP ganado por una sesión de práctica."""
    base_xp = 10

    # Bonus por precisión
    if score >= 100:
        precision_bonus = 50
    elif score >= 90:
        precision_bonus = 30
    elif score >= 80:
        precision_bonus = 20
    elif score >= 70:
        precision_bonus = 10
    else:
        precision_bonus = 0

    # Multiplicador por dificultad
    difficulty_multiplier = {
        "principiante": 1.0,
        "intermedio": 1.5,
        "avanzado": 2.0,
    }

    # Bonus por completar (score >= 70)
    completion_bonus = 15 if is_completed else 0

    total = int(
        (base_xp + precision_bonus + completion_bonus) * difficulty_multiplier.get(difficulty, 1.0)
    )
    return total


def calculate_level(total_xp: int) -> int:
    """Calcular nivel basado en XP total. Nivel = floor(sqrt(total_xp / 100)) + 1."""
    return int(math.floor(math.sqrt(total_xp / 100))) + 1


def xp_for_level(level: int) -> int:
    """XP necesario para alcanzar un nivel. xp_needed = (level-1)^2 * 100."""
    return ((level - 1) ** 2) * 100


def get_current_week_monday() -> date:
    """Obtener el lunes de la semana actual (UTC)."""
    today = datetime.now(UTC).date()
    return today - timedelta(days=today.weekday())


# ===================== XP + STREAK UPDATE =====================


async def get_or_create_user_xp(db: AsyncSession, user_id: uuid.UUID) -> UserXP:
    """Obtener o crear registro de XP del usuario."""
    result = await db.execute(select(UserXP).where(UserXP.user_id == user_id))
    user_xp = result.scalar_one_or_none()
    if not user_xp:
        user_xp = UserXP(user_id=user_id)
        db.add(user_xp)
        await db.flush()
        await db.refresh(user_xp)
    return user_xp


@dataclass(frozen=True)
class StreakUpdateResult:
    """Resultado de registrar una práctica sobre la racha diaria."""

    current_streak: int
    streak_preserved_by_freeze: bool
    freeze_consumed: bool


async def update_user_streak(
    db: AsyncSession, user_id: uuid.UUID, practice_datetime: datetime
) -> StreakUpdateResult:
    """Actualizar la racha diaria del usuario con la práctica en `practice_datetime`.

    El día calendario es el de `practice_datetime` tal como llega: el llamador lo
    expresa en la zona horaria local del usuario (un datetime naive se toma como local).
    - Mismo día: no cambia nada (varias prácticas el mismo día no suman).
    - Día consecutivo: +1.
    - Salto de exactamente un día con congelador: +1 y consume un congelador.
    - Cualquier otro salto: la racha vuelve a 1.
    Cada 7 días de racha se gana un congelador (tope MAX_STREAK_FREEZES).
    """
    user_xp = await get_or_create_user_xp(db, user_id)
    practice_day = practice_datetime.date()
    last = user_xp.last_practice_date

    advanced = True
    preserved = False
    consumed = False
    if last is None:
        user_xp.current_streak = 1
        # Congelador de bienvenida: red de seguridad desde el primer día.
        if user_xp.streak_freezes < 1:
            user_xp.streak_freezes = 1
    elif last == practice_day:
        advanced = False
    elif last == practice_day - timedelta(days=1):
        user_xp.current_streak += 1
    elif last == practice_day - timedelta(days=2) and user_xp.streak_freezes > 0:
        user_xp.streak_freezes -= 1
        user_xp.current_streak += 1
        preserved = True
        consumed = True
    else:
        user_xp.current_streak = 1  # Racha rota (2+ días o sin congelador)

    if user_xp.current_streak > user_xp.longest_streak:
        user_xp.longest_streak = user_xp.current_streak

    if advanced and user_xp.current_streak % 7 == 0 and user_xp.streak_freezes < MAX_STREAK_FREEZES:
        user_xp.streak_freezes += 1

    user_xp.last_practice_date = practice_day
    await db.flush()
    return StreakUpdateResult(user_xp.current_streak, preserved, consumed)


async def process_practice_xp(
    db: AsyncSession,
    user_id: uuid.UUID,
    score: float,
    difficulty: str,
    is_completed: bool,
    total_time_seconds: float,
) -> dict:
    """
    Procesar XP después de una sesión de práctica.
    Retorna: {xp_earned, new_level, current_level, new_achievements}
    """
    user_xp = await get_or_create_user_xp(db, user_id)
    current_monday = get_current_week_monday()

    # Resetear weekly_xp si cambió de semana
    if user_xp.week_start_date is None or user_xp.week_start_date < current_monday:
        user_xp.weekly_xp = 0
        user_xp.week_start_date = current_monday

    # Calcular XP ganado
    xp_earned = calculate_session_xp(score, difficulty, is_completed)

    # Actualizar XP
    old_level = user_xp.level
    user_xp.total_xp += xp_earned
    user_xp.weekly_xp += xp_earned

    # Recalcular nivel
    user_xp.level = calculate_level(user_xp.total_xp)
    new_level = user_xp.level > old_level

    # Actualizar estadísticas
    user_xp.total_practice_sessions += 1
    user_xp.total_practice_minutes += total_time_seconds / 60.0

    if is_completed:
        user_xp.total_lessons_completed += 1

    if score >= 100:
        user_xp.total_perfect_scores += 1

    # Recalcular promedio
    if user_xp.total_practice_sessions > 0:
        # Promedio ponderado incremental
        old_avg = user_xp.average_score
        n = user_xp.total_practice_sessions
        user_xp.average_score = round(old_avg + (score - old_avg) / n, 2)

    # Racha diaria con congeladores (día calendario UTC; ver update_user_streak).
    await update_user_streak(db, user_id, datetime.now(UTC))

    # Actualizar xp_level en User
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user:
        user.xp_level = user_xp.level

    await db.flush()

    # Verificar logros
    new_achievements = await check_achievements(db, user_id, user_xp)

    # Sumar XP de logros desbloqueados
    for ach in new_achievements:
        user_xp.total_xp += ach.xp_reward
        user_xp.weekly_xp += ach.xp_reward
        xp_earned += ach.xp_reward

    # Recalcular nivel después de logros
    user_xp.level = calculate_level(user_xp.total_xp)
    if user:
        user.xp_level = user_xp.level

    await db.flush()

    # Disparar notificaciones push por cada logro desbloqueado.
    if new_achievements:
        from app.services import notification_dispatcher

        for ach in new_achievements:
            await notification_dispatcher.notify_user(
                db,
                user_id=user_id,
                title=f"¡Logro desbloqueado! {ach.icon}",
                body=f"{ach.name} · +{ach.xp_reward} XP",
                data={
                    "type": "achievement",
                    "achievement_id": str(ach.id),
                    "rarity": ach.rarity,
                },
            )

    # Bonus: si subió de nivel, notif aparte
    if new_level or user_xp.level > old_level:
        from app.services import notification_dispatcher

        await notification_dispatcher.notify_user(
            db,
            user_id=user_id,
            title="¡Subiste de nivel! 🎉",
            body=f"Ya estás en nivel {user_xp.level}",
            data={"type": "level_up", "level": str(user_xp.level)},
        )

    return {
        "xp_earned": xp_earned,
        "new_level": new_level or (user_xp.level > old_level),
        "current_level": user_xp.level,
        "new_achievements": new_achievements,
    }


# ===================== INSIGNIAS ANDINAS =====================

PASSING_SCORE = 70.0
PENTATONIC_KEYWORD = "pentat"


async def get_andean_progress(db: AsyncSession, user_id: uuid.UUID) -> dict[str, int]:
    """Progreso por código de insignia andina, derivado del historial de prácticas.

    - andean_first_clean_breath: mejor score (redondeado hacia abajo).
    - andean_siku_master: lecciones distintas de zampoña aprobadas (score >= 70).
    - andean_air_control_30s: mayor duración (s) de una sesión con score >= 80.
    - andean_pentatonic_scale: lecciones de escala pentatónica aprobadas.
    """
    ps = PracticeSession
    best_score = (
        await db.execute(select(func.max(ps.score)).where(ps.user_id == user_id))
    ).scalar() or 0.0
    siku = (
        await db.execute(
            select(func.count(distinct(ps.lesson_id)))
            .join(Lesson, Lesson.id == ps.lesson_id)
            .where(
                ps.user_id == user_id,
                ps.score >= PASSING_SCORE,
                Lesson.instrument == "zampona",
            )
        )
    ).scalar() or 0
    longest_clean = (
        await db.execute(
            select(func.max(ps.total_time_seconds)).where(ps.user_id == user_id, ps.score >= 80)
        )
    ).scalar() or 0.0
    pentatonic = (
        await db.execute(
            select(func.count(distinct(ps.lesson_id)))
            .join(Lesson, Lesson.id == ps.lesson_id)
            .where(
                ps.user_id == user_id,
                ps.score >= PASSING_SCORE,
                func.lower(Lesson.title).contains(PENTATONIC_KEYWORD),
            )
        )
    ).scalar() or 0
    return {
        "andean_first_clean_breath": int(best_score),
        "andean_siku_master": int(siku),
        "andean_air_control_30s": int(longest_clean),
        "andean_pentatonic_scale": int(pentatonic),
    }


# ===================== VERIFICACIÓN DE LOGROS =====================


async def check_achievements(
    db: AsyncSession, user_id: uuid.UUID, user_xp: UserXP
) -> list[Achievement]:
    """Verificar y desbloquear logros nuevos después de actualizar XP/stats."""
    # Obtener logros activos no desbloqueados por este usuario
    unlocked_q = select(UserAchievement.achievement_id).where(UserAchievement.user_id == user_id)
    result = await db.execute(
        select(Achievement).where(
            Achievement.is_active == True,  # noqa: E712
            Achievement.id.not_in(unlocked_q),
        )
    )
    available = list(result.scalars().all())

    # Datos sociales para logros de tipo social
    posts_count_result = await db.execute(
        select(func.count()).where(Post.user_id == user_id, Post.is_active == True)  # noqa: E712
    )
    posts_count = posts_count_result.scalar() or 0

    followers_count_result = await db.execute(
        select(func.count()).where(Follow.following_id == user_id)
    )
    followers_count = followers_count_result.scalar() or 0

    andean = await get_andean_progress(db, user_id)

    new_achievements: list[Achievement] = []

    for ach in available:
        unlocked = False

        if ach.category == "andean":
            unlocked = andean.get(ach.code, 0) >= ach.requirement_value

        elif ach.category == "practice" and ach.requirement_type == "count":
            unlocked = user_xp.total_lessons_completed >= ach.requirement_value

        elif ach.category == "streak" and ach.requirement_type == "streak":
            unlocked = user_xp.current_streak >= ach.requirement_value

        elif ach.category == "score" and ach.requirement_type == "score":
            unlocked = user_xp.total_perfect_scores >= ach.requirement_value

        elif ach.category == "score" and ach.requirement_type == "special":
            # Promedio general >= requirement_value
            unlocked = (
                user_xp.average_score >= ach.requirement_value
                and user_xp.total_practice_sessions >= 10
            )

        elif ach.category == "social" and ach.code == "first_post":
            unlocked = posts_count >= ach.requirement_value

        elif ach.category == "social" and ach.code in ("followers_10", "followers_100"):
            unlocked = followers_count >= ach.requirement_value

        elif ach.category == "milestone" and ach.code in ("level_5", "level_10", "level_25"):
            unlocked = user_xp.level >= ach.requirement_value

        elif ach.category == "milestone" and ach.code in ("hours_10", "hours_100"):
            # requirement_value está en minutos
            unlocked = user_xp.total_practice_minutes >= ach.requirement_value

        if unlocked:
            ua = UserAchievement(user_id=user_id, achievement_id=ach.id)
            db.add(ua)
            new_achievements.append(ach)

    if new_achievements:
        await db.flush()

    return new_achievements


# ===================== LEADERBOARDS =====================


async def get_global_leaderboard(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """Top 50 usuarios por total_xp + posición del usuario actual."""
    # Top 50
    result = await db.execute(select(UserXP).order_by(UserXP.total_xp.desc()).limit(50))
    entries = list(result.scalars().all())

    leaderboard = []
    for i, entry in enumerate(entries):
        user = entry.user
        leaderboard.append(
            {
                "rank": i + 1,
                "user_id": entry.user_id,
                "username": user.username if user else "unknown",
                "full_name": user.full_name if user else "Unknown",
                "avatar_url": user.avatar_url if user else None,
                "total_xp": entry.total_xp,
                "weekly_xp": entry.weekly_xp,
                "level": entry.level,
                "total_lessons_completed": entry.total_lessons_completed,
            }
        )

    # Posición del usuario actual
    my_xp_data = await get_or_create_user_xp(db, user_id)
    rank_q = select(func.count()).where(UserXP.total_xp > my_xp_data.total_xp)
    rank_result = await db.execute(rank_q)
    my_rank = (rank_result.scalar() or 0) + 1

    return {
        "leaderboard": leaderboard,
        "my_rank": my_rank,
        "my_xp": my_xp_data.total_xp,
        "my_level": my_xp_data.level,
    }


async def get_friends_leaderboard(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """Top 50 entre la gente que el usuario sigue (+ él mismo) por total_xp.

    Reutiliza el grafo de follows: ranking solo de seguidos + uno mismo, lo que
    lo hace social y motivador (competís con conocidos, no con desconocidos).
    """
    # Asegurar la fila de XP del usuario ANTES de la consulta: así uno siempre
    # aparece en su propio ranking de amigos, incluso sin seguir a nadie.
    my_xp_data = await get_or_create_user_xp(db, user_id)

    following_ids = select(Follow.following_id).where(Follow.follower_id == user_id)
    # Conjunto: gente que sigo + yo mismo.
    id_filter = or_(UserXP.user_id.in_(following_ids), UserXP.user_id == user_id)

    result = await db.execute(
        select(UserXP).where(id_filter).order_by(UserXP.total_xp.desc()).limit(50)
    )
    entries = list(result.scalars().all())

    leaderboard = []
    for i, entry in enumerate(entries):
        user = entry.user
        leaderboard.append(
            {
                "rank": i + 1,
                "user_id": entry.user_id,
                "username": user.username if user else "unknown",
                "full_name": user.full_name if user else "Unknown",
                "avatar_url": user.avatar_url if user else None,
                "total_xp": entry.total_xp,
                "weekly_xp": entry.weekly_xp,
                "level": entry.level,
                "total_lessons_completed": entry.total_lessons_completed,
            }
        )

    # Posición del usuario actual DENTRO del set de amigos.
    rank_q = select(func.count()).where(and_(id_filter, UserXP.total_xp > my_xp_data.total_xp))
    rank_result = await db.execute(rank_q)
    my_rank = (rank_result.scalar() or 0) + 1

    return {
        "leaderboard": leaderboard,
        "my_rank": my_rank,
        "my_xp": my_xp_data.total_xp,
        "my_level": my_xp_data.level,
    }


async def get_weekly_leaderboard(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """Top 50 usuarios por weekly_xp + días restantes para reset."""
    current_monday = get_current_week_monday()

    # Resetear weekly_xp de usuarios que no se actualizaron esta semana
    # (solo para el leaderboard, los datos se resetean on-demand)

    result = await db.execute(
        select(UserXP)
        .where(UserXP.week_start_date == current_monday)
        .order_by(UserXP.weekly_xp.desc())
        .limit(50)
    )
    entries = list(result.scalars().all())

    leaderboard = []
    for i, entry in enumerate(entries):
        user = entry.user
        leaderboard.append(
            {
                "rank": i + 1,
                "user_id": entry.user_id,
                "username": user.username if user else "unknown",
                "full_name": user.full_name if user else "Unknown",
                "avatar_url": user.avatar_url if user else None,
                "total_xp": entry.total_xp,
                "weekly_xp": entry.weekly_xp,
                "level": entry.level,
                "total_lessons_completed": entry.total_lessons_completed,
            }
        )

    # Mi posición semanal
    my_xp_data = await get_or_create_user_xp(db, user_id)
    rank_q = select(func.count()).where(
        UserXP.weekly_xp > my_xp_data.weekly_xp,
        UserXP.week_start_date == current_monday,
    )
    rank_result = await db.execute(rank_q)
    my_rank = (rank_result.scalar() or 0) + 1

    # Días restantes hasta el próximo lunes
    today = datetime.now(UTC).date()
    next_monday = current_monday + timedelta(days=7)
    days_remaining = (next_monday - today).days

    return {
        "leaderboard": leaderboard,
        "my_rank": my_rank,
        "my_weekly_xp": my_xp_data.weekly_xp,
        "days_remaining": days_remaining,
    }


async def get_lesson_leaderboard(
    db: AsyncSession, user_id: uuid.UUID, lesson_id: uuid.UUID
) -> dict:
    """Top 20 mejores scores en una lección específica."""

    # Subconsulta: mejor score por usuario en esta lección
    best_scores_q = (
        select(
            PracticeSession.user_id,
            func.max(PracticeSession.score).label("best_score"),
        )
        .where(PracticeSession.lesson_id == lesson_id)
        .group_by(PracticeSession.user_id)
        .subquery()
    )

    # Obtener la sesión completa con el mejor score
    result = await db.execute(
        select(PracticeSession)
        .join(
            best_scores_q,
            and_(
                PracticeSession.user_id == best_scores_q.c.user_id,
                PracticeSession.score == best_scores_q.c.best_score,
                PracticeSession.lesson_id == lesson_id,
            ),
        )
        .order_by(PracticeSession.score.desc(), PracticeSession.created_at.asc())
        .limit(20)
    )
    sessions = list(result.scalars().all())

    # Obtener usuarios
    user_ids = [s.user_id for s in sessions]
    users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
    users_map = {u.id: u for u in users_result.scalars().all()}

    leaderboard = []
    for i, s in enumerate(sessions):
        user = users_map.get(s.user_id)
        leaderboard.append(
            {
                "rank": i + 1,
                "user_id": s.user_id,
                "username": user.username if user else "unknown",
                "full_name": user.full_name if user else "Unknown",
                "avatar_url": user.avatar_url if user else None,
                "score": s.score,
                "tempo_accuracy": s.tempo_accuracy,
                "created_at": s.created_at,
            }
        )

    # Mi mejor score
    my_best_q = select(func.max(PracticeSession.score)).where(
        PracticeSession.user_id == user_id,
        PracticeSession.lesson_id == lesson_id,
    )
    my_best_result = await db.execute(my_best_q)
    my_best = my_best_result.scalar() or 0.0

    # Mi rank
    better_q = (
        select(func.count(distinct(PracticeSession.user_id)))
        .where(PracticeSession.lesson_id == lesson_id)
        .group_by(PracticeSession.user_id)
        .having(func.max(PracticeSession.score) > my_best)
    )
    better_result = await db.execute(select(func.count()).select_from(better_q.subquery()))
    my_rank = (better_result.scalar() or 0) + 1

    return {
        "leaderboard": leaderboard,
        "my_best_score": my_best,
        "my_rank": my_rank,
    }


async def get_streaks_leaderboard(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """Top 30 usuarios por current_streak."""
    result = await db.execute(
        select(UserXP)
        .where(UserXP.current_streak > 0)
        .order_by(UserXP.current_streak.desc())
        .limit(30)
    )
    entries = list(result.scalars().all())

    leaderboard = []
    for i, entry in enumerate(entries):
        user = entry.user
        leaderboard.append(
            {
                "rank": i + 1,
                "user_id": entry.user_id,
                "username": user.username if user else "unknown",
                "full_name": user.full_name if user else "Unknown",
                "avatar_url": user.avatar_url if user else None,
                "current_streak": entry.current_streak,
                "longest_streak": entry.longest_streak,
            }
        )

    my_xp_data = await get_or_create_user_xp(db, user_id)
    rank_q = select(func.count()).where(UserXP.current_streak > my_xp_data.current_streak)
    rank_result = await db.execute(rank_q)
    my_rank = (rank_result.scalar() or 0) + 1

    return {
        "leaderboard": leaderboard,
        "my_rank": my_rank,
        "my_streak": my_xp_data.current_streak,
        "my_longest": my_xp_data.longest_streak,
    }


# ===================== MY XP =====================


async def get_my_xp(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """Datos completos de XP del usuario actual."""
    user_xp = await get_or_create_user_xp(db, user_id)
    current_monday = get_current_week_monday()

    # Resetear weekly si cambió semana
    if user_xp.week_start_date is None or user_xp.week_start_date < current_monday:
        user_xp.weekly_xp = 0
        user_xp.week_start_date = current_monday
        await db.flush()

    # Calcular progreso de nivel
    current_level_xp = xp_for_level(user_xp.level)
    next_level_xp = xp_for_level(user_xp.level + 1)
    xp_range = next_level_xp - current_level_xp
    xp_progress = user_xp.total_xp - current_level_xp
    percentage = round((xp_progress / xp_range) * 100, 1) if xp_range > 0 else 0.0

    # Ranks
    global_rank_q = select(func.count()).where(UserXP.total_xp > user_xp.total_xp)
    global_rank_result = await db.execute(global_rank_q)
    global_rank = (global_rank_result.scalar() or 0) + 1

    weekly_rank_q = select(func.count()).where(
        UserXP.weekly_xp > user_xp.weekly_xp,
        UserXP.week_start_date == current_monday,
    )
    weekly_rank_result = await db.execute(weekly_rank_q)
    weekly_rank = (weekly_rank_result.scalar() or 0) + 1

    return {
        "total_xp": user_xp.total_xp,
        "weekly_xp": user_xp.weekly_xp,
        "level": user_xp.level,
        "xp_for_current_level": current_level_xp,
        "xp_for_next_level": next_level_xp,
        "xp_progress_percentage": percentage,
        "current_streak": user_xp.current_streak,
        "longest_streak": user_xp.longest_streak,
        "streak_freezes": user_xp.streak_freezes,
        "total_sessions": user_xp.total_practice_sessions,
        "total_minutes": user_xp.total_practice_minutes,
        "total_completed": user_xp.total_lessons_completed,
        "total_perfect": user_xp.total_perfect_scores,
        "average_score": user_xp.average_score,
        "global_rank": global_rank,
        "weekly_rank": weekly_rank,
    }


# ===================== LOGROS =====================


async def get_all_achievements(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """Lista todos los logros del sistema con estado del usuario."""
    # Todos los logros activos
    result = await db.execute(
        select(Achievement)
        .where(Achievement.is_active == True)  # noqa: E712
        .order_by(Achievement.category, Achievement.order)
    )
    all_achievements = list(result.scalars().all())

    # Logros desbloqueados por el usuario
    unlocked_result = await db.execute(
        select(UserAchievement).where(UserAchievement.user_id == user_id)
    )
    unlocked_map = {ua.achievement_id: ua.unlocked_at for ua in unlocked_result.scalars().all()}

    # Datos del usuario para progreso
    user_xp = await get_or_create_user_xp(db, user_id)

    # Datos sociales
    posts_q = select(func.count()).where(Post.user_id == user_id, Post.is_active == True)  # noqa: E712
    posts_result = await db.execute(posts_q)
    posts_count = posts_result.scalar() or 0

    followers_q = select(func.count()).where(Follow.following_id == user_id)
    followers_result = await db.execute(followers_q)
    followers_count = followers_result.scalar() or 0

    andean = await get_andean_progress(db, user_id)

    achievements = []
    total_unlocked = 0
    for ach in all_achievements:
        is_unlocked = ach.id in unlocked_map
        if is_unlocked:
            total_unlocked += 1

        # Calcular progreso
        progress = _get_achievement_progress(ach, user_xp, posts_count, followers_count, andean)

        achievements.append(
            {
                "id": ach.id,
                "code": ach.code,
                "name": ach.name,
                "description": ach.description,
                "icon": ach.icon,
                "category": ach.category,
                "xp_reward": ach.xp_reward,
                "rarity": ach.rarity,
                "requirement_type": ach.requirement_type,
                "requirement_value": ach.requirement_value,
                "is_unlocked": is_unlocked,
                "unlocked_at": unlocked_map.get(ach.id),
                "progress": progress,
            }
        )

    return {
        "achievements": achievements,
        "total_unlocked": total_unlocked,
        "total_available": len(all_achievements),
    }


def _get_achievement_progress(
    ach: Achievement,
    user_xp: UserXP,
    posts_count: int,
    followers_count: int,
    andean: dict[str, int] | None = None,
) -> int:
    """Calcular progreso actual hacia un logro."""
    if ach.category == "andean":
        return (andean or {}).get(ach.code, 0)
    elif ach.category == "practice":
        return user_xp.total_lessons_completed
    elif ach.category == "streak":
        return user_xp.current_streak
    elif ach.category == "score" and ach.requirement_type == "score":
        return user_xp.total_perfect_scores
    elif ach.category == "score" and ach.requirement_type == "special":
        return int(user_xp.average_score)
    elif ach.category == "social" and ach.code == "first_post":
        return posts_count
    elif ach.category == "social" and ach.code in ("followers_10", "followers_100"):
        return followers_count
    elif ach.category == "milestone" and ach.code in ("level_5", "level_10", "level_25"):
        return user_xp.level
    elif ach.category == "milestone" and ach.code in ("hours_10", "hours_100"):
        return int(user_xp.total_practice_minutes)
    return 0


async def get_recent_achievements(db: AsyncSession, user_id: uuid.UUID) -> list[dict]:
    """Últimos 5 logros desbloqueados por el usuario."""
    result = await db.execute(
        select(UserAchievement)
        .where(UserAchievement.user_id == user_id)
        .order_by(UserAchievement.unlocked_at.desc())
        .limit(5)
    )
    user_achievements = list(result.scalars().all())

    return [
        {
            "id": ua.id,
            "achievement_id": ua.achievement_id,
            "code": ua.achievement.code,
            "name": ua.achievement.name,
            "description": ua.achievement.description,
            "icon": ua.achievement.icon,
            "category": ua.achievement.category,
            "xp_reward": ua.achievement.xp_reward,
            "rarity": ua.achievement.rarity,
            "unlocked_at": ua.unlocked_at,
        }
        for ua in user_achievements
        if ua.achievement
    ]


# ===================== ADMIN =====================


async def get_ranking_stats(db: AsyncSession) -> dict:
    """Estadísticas del sistema de rankings para admin."""
    # Total XP distribuido
    total_xp_q = select(func.sum(UserXP.total_xp))
    total_xp_result = await db.execute(total_xp_q)
    total_xp = total_xp_result.scalar() or 0

    # Usuarios con XP (> 0)
    users_with_xp = (
        await db.execute(select(func.count()).select_from(UserXP).where(UserXP.total_xp > 0))
    ).scalar() or 0

    # Top usuario por XP (tarjeta destacada)
    top_row = (
        await db.execute(
            select(User.username, UserXP.level, UserXP.total_xp)
            .join(User, User.id == UserXP.user_id)
            .order_by(UserXP.total_xp.desc())
            .limit(1)
        )
    ).first()
    top_user = (
        {"username": top_row[0], "level": top_row[1], "total_xp": top_row[2]} if top_row else None
    )

    # Nivel promedio y máximo
    avg_level_q = select(func.avg(UserXP.level))
    avg_level_result = await db.execute(avg_level_q)
    avg_level = round(avg_level_result.scalar() or 0.0, 2)

    max_level_q = select(func.max(UserXP.level))
    max_level_result = await db.execute(max_level_q)
    max_level = max_level_result.scalar() or 0

    # Total logros desbloqueados
    total_ach_q = select(func.count(UserAchievement.id))
    total_ach_result = await db.execute(total_ach_q)
    total_achievements = total_ach_result.scalar() or 0

    # Logro más desbloqueado
    most_q = (
        select(Achievement.name, func.count(UserAchievement.id).label("cnt"))
        .join(UserAchievement, UserAchievement.achievement_id == Achievement.id)
        .group_by(Achievement.name)
        .order_by(func.count(UserAchievement.id).desc())
        .limit(1)
    )
    most_result = await db.execute(most_q)
    most_row = most_result.first()
    most_unlocked = most_row[0] if most_row else None

    # Logro más difícil (menos desbloqueado entre activos)
    hardest_q = (
        select(
            Achievement.name,
            func.count(UserAchievement.id).label("cnt"),
        )
        .outerjoin(UserAchievement, UserAchievement.achievement_id == Achievement.id)
        .where(Achievement.is_active == True)  # noqa: E712
        .group_by(Achievement.name)
        .order_by(func.count(UserAchievement.id).asc())
        .limit(1)
    )
    hardest_result = await db.execute(hardest_q)
    hardest_row = hardest_result.first()
    hardest_achievement = hardest_row[0] if hardest_row else None

    # Usuarios con racha activa
    today = datetime.now(UTC).date()
    yesterday = today - timedelta(days=1)
    active_streak_q = select(func.count()).where(
        UserXP.current_streak > 0,
        UserXP.last_practice_date.in_([today, yesterday]),
    )
    active_streak_result = await db.execute(active_streak_q)
    active_streaks = active_streak_result.scalar() or 0

    # Racha más larga activa
    longest_q = select(func.max(UserXP.current_streak)).where(
        UserXP.last_practice_date.in_([today, yesterday])
    )
    longest_result = await db.execute(longest_q)
    longest = longest_result.scalar() or 0

    return {
        "total_xp_distributed": total_xp,
        "total_xp_awarded": total_xp,
        "total_users_with_xp": users_with_xp,
        "average_level": avg_level,
        "max_level": max_level,
        "total_achievements_unlocked": total_achievements,
        "most_unlocked_achievement": most_unlocked,
        "hardest_achievement": hardest_achievement,
        "users_with_active_streak": active_streaks,
        "longest_active_streak": longest,
        "top_user": top_user,
    }


async def create_achievement(db: AsyncSession, data: dict) -> Achievement:
    """Crear un nuevo logro (admin)."""
    achievement = Achievement(**data)
    db.add(achievement)
    await db.flush()
    await db.refresh(achievement)
    return achievement


async def update_achievement(
    db: AsyncSession, achievement_id: uuid.UUID, data: dict
) -> Achievement | None:
    """Editar un logro existente (admin)."""
    result = await db.execute(select(Achievement).where(Achievement.id == achievement_id))
    achievement = result.scalar_one_or_none()
    if not achievement:
        return None

    for key, value in data.items():
        if value is not None:
            setattr(achievement, key, value)

    await db.flush()
    await db.refresh(achievement)
    return achievement


async def delete_achievement(db: AsyncSession, achievement_id: uuid.UUID) -> bool:
    """Soft delete de un logro (admin)."""
    result = await db.execute(select(Achievement).where(Achievement.id == achievement_id))
    achievement = result.scalar_one_or_none()
    if not achievement:
        return False

    achievement.is_active = False
    await db.flush()
    return True


async def get_admin_achievements(db: AsyncSession) -> list[dict]:
    """Lista todos los logros para admin con count de desbloqueos."""
    result = await db.execute(
        select(
            Achievement,
            func.count(UserAchievement.id).label("unlocked_count"),
        )
        .outerjoin(UserAchievement, UserAchievement.achievement_id == Achievement.id)
        .group_by(Achievement.id)
        .order_by(Achievement.category, Achievement.order)
    )
    rows = result.all()

    return [
        {
            "id": ach.id,
            "code": ach.code,
            "name": ach.name,
            "description": ach.description,
            "icon": ach.icon,
            "category": ach.category,
            "xp_reward": ach.xp_reward,
            "requirement_type": ach.requirement_type,
            "requirement_value": ach.requirement_value,
            "rarity": ach.rarity,
            "order": ach.order,
            "is_active": ach.is_active,
            "unlocked_count": count,
            "created_at": ach.created_at,
        }
        for ach, count in rows
    ]
