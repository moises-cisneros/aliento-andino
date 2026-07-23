"""Router admin de analytics: métricas y series temporales para gráficos."""

from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, cast, Date
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies.auth import get_current_admin
from app.models.user import User
from app.models.lesson import PracticeSession, Lesson, Category
from app.models.social import Post, Comment, Like, Report
from app.services import ai_usage_service

router = APIRouter(prefix="/api/admin/analytics", tags=["Admin Analytics"])


@router.get("/overview")
async def get_overview(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """KPIs globales del sistema."""
    total_users = (await db.execute(select(func.count()).select_from(User))).scalar() or 0
    active_users = (await db.execute(
        select(func.count()).select_from(User).where(User.is_active == True, User.is_banned == False)
    )).scalar() or 0
    banned_users = (await db.execute(
        select(func.count()).select_from(User).where(User.is_banned == True)
    )).scalar() or 0
    total_lessons = (await db.execute(select(func.count()).select_from(Lesson))).scalar() or 0
    total_sessions = (await db.execute(select(func.count()).select_from(PracticeSession))).scalar() or 0
    total_posts = (await db.execute(select(func.count()).select_from(Post))).scalar() or 0
    total_comments = (await db.execute(select(func.count()).select_from(Comment))).scalar() or 0
    total_likes = (await db.execute(select(func.count()).select_from(Like))).scalar() or 0
    pending_reports = (await db.execute(
        select(func.count()).select_from(Report).where(Report.status == "pending")
    )).scalar() or 0

    return {
        "total_users": total_users,
        "active_users": active_users,
        "banned_users": banned_users,
        "total_lessons": total_lessons,
        "total_sessions": total_sessions,
        "total_posts": total_posts,
        "total_comments": total_comments,
        "total_likes": total_likes,
        "pending_reports": pending_reports,
    }


@router.get("/users-over-time")
async def get_users_over_time(
    days: int = Query(30, ge=7, le=365),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Usuarios registrados agrupados por día."""
    since = date.today() - timedelta(days=days)
    rows = (await db.execute(
        select(
            cast(User.created_at, Date).label("day"),
            func.count().label("count"),
        )
        .where(User.created_at >= since)
        .group_by("day")
        .order_by("day")
    )).all()
    return [{"name": str(r.day), "value": r.count} for r in rows]


@router.get("/practice-over-time")
async def get_practice_over_time(
    days: int = Query(30, ge=7, le=365),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Sesiones de práctica por día."""
    since = date.today() - timedelta(days=days)
    rows = (await db.execute(
        select(
            cast(PracticeSession.created_at, Date).label("day"),
            func.count().label("count"),
        )
        .where(PracticeSession.created_at >= since)
        .group_by("day")
        .order_by("day")
    )).all()
    return [{"name": str(r.day), "value": r.count} for r in rows]


@router.get("/social-over-time")
async def get_social_over_time(
    days: int = Query(30, ge=7, le=365),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Actividad social (posts, comentarios, likes) por día."""
    since = date.today() - timedelta(days=days)

    posts_rows = (await db.execute(
        select(cast(Post.created_at, Date).label("day"), func.count().label("count"))
        .where(Post.created_at >= since)
        .group_by("day").order_by("day")
    )).all()

    comments_rows = (await db.execute(
        select(cast(Comment.created_at, Date).label("day"), func.count().label("count"))
        .where(Comment.created_at >= since)
        .group_by("day").order_by("day")
    )).all()

    likes_rows = (await db.execute(
        select(cast(Like.created_at, Date).label("day"), func.count().label("count"))
        .where(Like.created_at >= since)
        .group_by("day").order_by("day")
    )).all()

    return {
        "posts": [{"name": str(r.day), "value": r.count} for r in posts_rows],
        "comments": [{"name": str(r.day), "value": r.count} for r in comments_rows],
        "likes": [{"name": str(r.day), "value": r.count} for r in likes_rows],
    }


@router.get("/lessons-by-category")
async def get_lessons_by_category(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lecciones agrupadas por categoría (para pie chart)."""
    rows = (await db.execute(
        select(Category.name, func.count(Lesson.id).label("count"))
        .join(Lesson, Lesson.category_id == Category.id)
        .group_by(Category.name)
        .order_by(func.count(Lesson.id).desc())
    )).all()
    return [{"name": r.name, "value": r.count} for r in rows]


@router.get("/lessons-by-difficulty")
async def get_lessons_by_difficulty(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lecciones agrupadas por dificultad."""
    rows = (await db.execute(
        select(Lesson.difficulty, func.count().label("count"))
        .group_by(Lesson.difficulty)
    )).all()
    return [{"name": r.difficulty, "value": r.count} for r in rows]


@router.get("/reports-by-status")
async def get_reports_by_status(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Reportes agrupados por estado (pie chart)."""
    rows = (await db.execute(
        select(Report.status, func.count().label("count"))
        .group_by(Report.status)
    )).all()
    return [{"name": r.status, "value": r.count} for r in rows]


@router.get("/reports-over-time")
async def get_reports_over_time(
    days: int = Query(30, ge=7, le=365),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Reportes creados por día."""
    since = date.today() - timedelta(days=days)
    rows = (await db.execute(
        select(cast(Report.created_at, Date).label("day"), func.count().label("count"))
        .where(Report.created_at >= since)
        .group_by("day").order_by("day")
    )).all()
    return [{"name": str(r.day), "value": r.count} for r in rows]


@router.get("/top-lessons")
async def get_top_lessons(
    limit: int = Query(10, ge=1, le=50),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lecciones más practicadas."""
    rows = (await db.execute(
        select(Lesson.title, Lesson.total_plays)
        .where(Lesson.total_plays > 0)
        .order_by(Lesson.total_plays.desc())
        .limit(limit)
    )).all()
    return [{"name": r.title, "value": r.total_plays} for r in rows]


# ---------------------------------------------------------------------------
# Inteligencia de negocio: embudo, retención, ingresos y dificultad.
# ---------------------------------------------------------------------------


@router.get("/funnel")
async def get_funnel(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Embudo de conversión: registrados → practicaron → premium."""
    now = datetime.now(timezone.utc)
    registered = (await db.execute(select(func.count()).select_from(User))).scalar() or 0
    practiced = (await db.execute(
        select(func.count(func.distinct(PracticeSession.user_id)))
    )).scalar() or 0
    premium = (await db.execute(
        select(func.count()).select_from(User).where(
            User.subscription_status == "premium",
            User.subscription_expires_at > now,
        )
    )).scalar() or 0

    def pct(a: int, b: int) -> float:
        return round(a * 100 / b, 1) if b else 0.0

    return {
        "registered": registered,
        "practiced": practiced,
        "premium": premium,
        "practiced_pct": pct(practiced, registered),
        "premium_pct": pct(premium, registered),
        "premium_of_practiced_pct": pct(premium, practiced),
    }


@router.get("/retention")
async def get_retention(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Usuarios activos (con práctica) en los últimos 7 y 30 días + premium."""
    now = datetime.now(timezone.utc)
    d7 = now - timedelta(days=7)
    d30 = now - timedelta(days=30)
    total = (await db.execute(select(func.count()).select_from(User))).scalar() or 0
    active7 = (await db.execute(
        select(func.count(func.distinct(PracticeSession.user_id)))
        .where(PracticeSession.created_at >= d7)
    )).scalar() or 0
    active30 = (await db.execute(
        select(func.count(func.distinct(PracticeSession.user_id)))
        .where(PracticeSession.created_at >= d30)
    )).scalar() or 0
    active_premium = (await db.execute(
        select(func.count()).select_from(User).where(
            User.subscription_status == "premium",
            User.subscription_expires_at > now,
        )
    )).scalar() or 0
    expired_premium = (await db.execute(
        select(func.count()).select_from(User).where(
            User.subscription_status == "premium",
            User.subscription_expires_at <= now,
        )
    )).scalar() or 0

    def pct(a: int, b: int) -> float:
        return round(a * 100 / b, 1) if b else 0.0

    return {
        "total_users": total,
        "active_7d": active7,
        "active_30d": active30,
        "active_7d_pct": pct(active7, total),
        "active_30d_pct": pct(active30, total),
        "active_premium": active_premium,
        "expired_premium": expired_premium,
    }


@router.get("/premium-over-time")
async def get_premium_over_time(
    days: int = Query(90, ge=7, le=365),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Altas de premium por día (usando subscription_started_at)."""
    since = date.today() - timedelta(days=days)
    rows = (await db.execute(
        select(
            cast(User.subscription_started_at, Date).label("day"),
            func.count().label("count"),
        )
        .where(
            User.subscription_started_at.isnot(None),
            cast(User.subscription_started_at, Date) >= since,
        )
        .group_by("day")
        .order_by("day")
    )).all()
    return [{"name": str(r.day), "value": r.count} for r in rows]


@router.get("/lesson-performance")
async def get_lesson_performance(
    limit: int = Query(10, ge=1, le=50),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lecciones donde más cuesta: menor score promedio (con ≥1 práctica)."""
    rows = (await db.execute(
        select(
            Lesson.title.label("title"),
            func.count(PracticeSession.id).label("attempts"),
            func.avg(PracticeSession.score).label("avg_score"),
        )
        .join(PracticeSession, PracticeSession.lesson_id == Lesson.id)
        .group_by(Lesson.id, Lesson.title)
        .order_by(func.avg(PracticeSession.score).asc())
        .limit(limit)
    )).all()
    return [
        {
            "title": r.title,
            "attempts": r.attempts,
            "avg_score": round(float(r.avg_score or 0), 1),
        }
        for r in rows
    ]


# ---------------------------------------------------------------------------
# Costo de IA (Gemini). El feedback de práctica SÍ se guarda, así que las
# llamadas se cuentan de verdad; el costo es ESTIMADO (no se loguean tokens).
# ---------------------------------------------------------------------------

# Supuestos editables para estimar el costo del feedback con Gemini Flash.
_AI_AVG_INPUT_TOKENS = 450
_AI_AVG_OUTPUT_TOKENS = 100
_AI_PRICE_INPUT_PER_1M = 0.30  # USD / 1M tokens de entrada (Gemini 2.5 Flash, aprox)
_AI_PRICE_OUTPUT_PER_1M = 2.50  # USD / 1M tokens de salida (aprox)


def _ai_cost_per_call() -> float:
    return (
        _AI_AVG_INPUT_TOKENS * _AI_PRICE_INPUT_PER_1M / 1_000_000
        + _AI_AVG_OUTPUT_TOKENS * _AI_PRICE_OUTPUT_PER_1M / 1_000_000
    )


@router.get("/ai-usage")
async def get_ai_usage(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Uso y costo ESTIMADO de la IA (feedback de práctica con Gemini)."""
    now = datetime.now(timezone.utc)
    d30 = now - timedelta(days=30)
    has_feedback = PracticeSession.ai_feedback.isnot(None)
    total = (await db.execute(
        select(func.count()).select_from(PracticeSession).where(has_feedback)
    )).scalar() or 0
    last30 = (await db.execute(
        select(func.count()).select_from(PracticeSession).where(
            has_feedback, PracticeSession.created_at >= d30
        )
    )).scalar() or 0

    per_call = _ai_cost_per_call()

    # Uso REAL registrado (tokens de usage_metadata de Gemini).
    real = await ai_usage_service.real_usage_summary(db)
    has_real = real["total"]["calls"] > 0

    return {
        "model": settings.gemini_model,
        "total_feedback_calls": total,
        "feedback_calls_30d": last30,
        "est_cost_per_call_usd": round(per_call, 6),
        "est_total_cost_usd": round(total * per_call, 4),
        "est_cost_30d_usd": round(last30 * per_call, 4),
        "assumptions": {
            "avg_input_tokens": _AI_AVG_INPUT_TOKENS,
            "avg_output_tokens": _AI_AVG_OUTPUT_TOKENS,
            "price_input_per_1m_usd": _AI_PRICE_INPUT_PER_1M,
            "price_output_per_1m_usd": _AI_PRICE_OUTPUT_PER_1M,
        },
        # Datos REALES (a partir de que se instrumentó el logging de tokens).
        "has_real": has_real,
        "real": real,
        "price_input_per_1m_usd": ai_usage_service.PRICE_INPUT_PER_1M,
        "price_output_per_1m_usd": ai_usage_service.PRICE_OUTPUT_PER_1M,
        "note": (
            "Se registran los tokens REALES de cada llamada a Gemini (feedback de "
            "práctica y tutor Vivi). El bloque 'estimado' queda como referencia "
            "histórica (llamadas de feedback × tokens promedio)."
            if has_real else
            "Todavía no hay llamadas con tokens registrados; se muestra el "
            "estimado (llamadas de feedback × tokens promedio × precio de Gemini "
            "Flash). El registro real empieza con las próximas llamadas a la IA."
        ),
    }


@router.get("/ai-usage-over-time")
async def get_ai_usage_over_time(
    days: int = Query(30, ge=7, le=365),
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Uso de IA por día: tokens reales si hay registro; si no, llamadas de feedback."""
    if await ai_usage_service.has_any(db):
        return await ai_usage_service.real_usage_over_time(db, days=days)

    since = date.today() - timedelta(days=days)
    rows = (await db.execute(
        select(
            cast(PracticeSession.created_at, Date).label("day"),
            func.count().label("count"),
        )
        .where(
            PracticeSession.ai_feedback.isnot(None),
            PracticeSession.created_at >= since,
        )
        .group_by("day")
        .order_by("day")
    )).all()
    return [{"name": str(r.day), "value": r.count} for r in rows]
