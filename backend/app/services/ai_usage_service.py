"""Registro y agregación del uso REAL de la IA (tokens de Gemini/Vertex).

`record_from_response` extrae los tokens de usage_metadata y los persiste en su
PROPIA sesión (no toca la transacción de la request y nunca rompe la llamada IA).
Los precios por 1M de tokens son configurables.
"""

import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import Date, cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session
from app.models.ai_usage import AiUsageLog

logger = logging.getLogger(__name__)

# Precios por 1M de tokens (Gemini 2.5 Flash, aprox). Editables.
PRICE_INPUT_PER_1M = 0.30
PRICE_OUTPUT_PER_1M = 2.50


def _extract_usage(response) -> tuple[int, int]:
    """Saca (input_tokens, output_tokens) del response de forma defensiva."""
    um = getattr(response, "usage_metadata", None)
    if um is None:
        return (0, 0)
    inp = getattr(um, "prompt_token_count", 0) or 0
    out = getattr(um, "candidates_token_count", 0) or 0
    return (int(inp), int(out))


async def record_from_response(
    response, kind: str, model: str | None = None, user_id=None
) -> None:
    """Registra el uso de tokens de una respuesta de generate_content."""
    inp, out = _extract_usage(response)
    if inp == 0 and out == 0:
        return  # nada que registrar (modo degradado o sin metadata)
    await record(kind, inp, out, model=model, user_id=user_id)


async def record(
    kind: str,
    input_tokens: int,
    output_tokens: int,
    model: str | None = None,
    user_id=None,
) -> None:
    """Persiste una entrada de uso en su propia sesión (no bloquea la IA)."""
    try:
        async with async_session() as db:
            db.add(
                AiUsageLog(
                    kind=kind,
                    model=model,
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                    total_tokens=input_tokens + output_tokens,
                    user_id=user_id,
                )
            )
            await db.commit()
    except Exception as e:  # noqa: BLE001 — registrar uso no debe tumbar la IA
        logger.warning("No se pudo registrar uso de IA (%s): %s", kind, e)


def cost_usd(input_tokens: int, output_tokens: int) -> float:
    return (
        input_tokens * PRICE_INPUT_PER_1M / 1_000_000
        + output_tokens * PRICE_OUTPUT_PER_1M / 1_000_000
    )


async def real_usage_summary(db: AsyncSession) -> dict:
    """Agregado del uso REAL registrado: totales, 30 días y desglose por tipo."""
    now = datetime.now(timezone.utc)
    d30 = now - timedelta(days=30)

    async def _agg(*conditions):
        row = (await db.execute(
            select(
                func.count(AiUsageLog.id),
                func.coalesce(func.sum(AiUsageLog.input_tokens), 0),
                func.coalesce(func.sum(AiUsageLog.output_tokens), 0),
            ).where(*conditions) if conditions else
            select(
                func.count(AiUsageLog.id),
                func.coalesce(func.sum(AiUsageLog.input_tokens), 0),
                func.coalesce(func.sum(AiUsageLog.output_tokens), 0),
            )
        )).one()
        calls, inp, out = int(row[0]), int(row[1]), int(row[2])
        return {
            "calls": calls,
            "input_tokens": inp,
            "output_tokens": out,
            "total_tokens": inp + out,
            "cost_usd": round(cost_usd(inp, out), 6),
        }

    total = await _agg()
    last30 = await _agg(AiUsageLog.created_at >= d30)

    by_kind = {}
    rows = (await db.execute(
        select(
            AiUsageLog.kind,
            func.count(AiUsageLog.id),
            func.coalesce(func.sum(AiUsageLog.input_tokens), 0),
            func.coalesce(func.sum(AiUsageLog.output_tokens), 0),
        ).group_by(AiUsageLog.kind)
    )).all()
    for kind, calls, inp, out in rows:
        by_kind[kind] = {
            "calls": int(calls),
            "input_tokens": int(inp),
            "output_tokens": int(out),
            "total_tokens": int(inp) + int(out),
            "cost_usd": round(cost_usd(int(inp), int(out)), 6),
        }

    return {"total": total, "last30": last30, "by_kind": by_kind}


async def real_usage_over_time(db: AsyncSession, days: int = 30) -> list[dict]:
    """Tokens reales por día (suma de total_tokens)."""
    since = date.today() - timedelta(days=days)
    rows = (await db.execute(
        select(
            cast(AiUsageLog.created_at, Date).label("day"),
            func.coalesce(func.sum(AiUsageLog.total_tokens), 0).label("tokens"),
        )
        .where(AiUsageLog.created_at >= since)
        .group_by("day")
        .order_by("day")
    )).all()
    return [{"name": str(r.day), "value": int(r.tokens)} for r in rows]


async def has_any(db: AsyncSession) -> bool:
    return ((await db.execute(
        select(func.count(AiUsageLog.id))
    )).scalar() or 0) > 0
