"""Configuración editable del sistema, cacheada en memoria.

Se carga al iniciar la app y se refresca al actualizar desde el admin. Los
servicios leen los valores de forma SÍNCRONA desde el cache (sin pegarle a la
DB en cada request). Solo se aceptan las claves de DEFAULTS.
"""

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.app_setting import AppSetting

# Claves editables + sus valores por defecto (también validan qué se puede setear).
DEFAULTS: dict[str, Any] = {
    "price_monthly": 4.99,   # USD
    "price_annual": 39.99,   # USD
    "trial_days": 7,
    "ai_feedback_enabled": True,
}

_cache: dict[str, Any] = dict(DEFAULTS)


async def load(db: AsyncSession) -> None:
    """Carga la config desde la DB al cache (mergeada sobre los defaults)."""
    rows = (await db.execute(select(AppSetting))).scalars().all()
    merged = dict(DEFAULTS)
    for r in rows:
        if r.key in DEFAULTS:
            merged[r.key] = r.value
    _cache.clear()
    _cache.update(merged)


def get(key: str) -> Any:
    return _cache.get(key, DEFAULTS.get(key))


def all_settings() -> dict[str, Any]:
    return dict(_cache)


async def update(db: AsyncSession, changes: dict[str, Any]) -> dict[str, Any]:
    """Persiste los cambios (solo claves conocidas) y refresca el cache."""
    for k, v in changes.items():
        if k not in DEFAULTS:
            continue
        row = (
            await db.execute(select(AppSetting).where(AppSetting.key == k))
        ).scalar_one_or_none()
        if row:
            row.value = v
        else:
            db.add(AppSetting(key=k, value=v))
    await db.commit()
    await load(db)
    return all_settings()
