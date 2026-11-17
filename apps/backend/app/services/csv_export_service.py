"""Generación de CSVs para el panel admin (usuarios, suscripciones, lecciones).

Reutiliza los mismos listados/queries que las vistas del admin, pero sin
paginar (cap alto de seguridad). Devuelve el CSV como string para servirlo con
Content-Disposition: attachment.
"""

import csv
import io
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Lesson, PracticeSession
from app.services import subscription_service, user_service

# Tope de filas por export (evita un CSV gigante por accidente).
MAX_ROWS = 50_000


def _to_csv(headers: list[str], rows: list[list[Any]]) -> str:
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(headers)
    writer.writerows(rows)
    return buf.getvalue()


async def users_csv(
    db: AsyncSession,
    search: str | None = None,
    is_banned: bool | None = None,
    is_admin: bool | None = None,
) -> str:
    data = await user_service.admin_list_users(
        db,
        page=1,
        limit=MAX_ROWS,
        search=search,
        is_banned=is_banned,
        is_admin=is_admin,
    )
    headers = [
        "id",
        "email",
        "username",
        "full_name",
        "is_active",
        "is_admin",
        "is_banned",
        "ban_reason",
        "xp_level",
        "followers_count",
        "posts_count",
        "created_at",
    ]
    rows = [[u.get(h) for h in headers] for u in data["items"]]
    return _to_csv(headers, rows)


async def subscriptions_csv(
    db: AsyncSession,
    status_filter: str | None = None,
    plan: str | None = None,
    search: str | None = None,
) -> str:
    data = await subscription_service.admin_list_subscriptions(
        db,
        page=1,
        limit=MAX_ROWS,
        status_filter=status_filter,
        plan=plan,
        search=search,
    )
    headers = [
        "id",
        "email",
        "username",
        "full_name",
        "subscription_status",
        "subscription_plan",
        "plan_label",
        "subscription_started_at",
        "subscription_expires_at",
        "subscription_trial_used",
        "is_premium",
        "days_until_expiry",
    ]
    rows = [[u.get(h) for h in headers] for u in data["items"]]
    return _to_csv(headers, rows)


async def lesson_performance_csv(db: AsyncSession) -> str:
    rows_db = (
        await db.execute(
            select(
                Lesson.title.label("title"),
                func.count(PracticeSession.id).label("attempts"),
                func.avg(PracticeSession.score).label("avg_score"),
            )
            .join(PracticeSession, PracticeSession.lesson_id == Lesson.id)
            .group_by(Lesson.id, Lesson.title)
            .order_by(func.avg(PracticeSession.score).asc())
            .limit(MAX_ROWS)
        )
    ).all()
    headers = ["title", "attempts", "avg_score"]
    rows = [[r.title, r.attempts, round(float(r.avg_score or 0), 1)] for r in rows_db]
    return _to_csv(headers, rows)
