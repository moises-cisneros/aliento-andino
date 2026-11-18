"""Ciclo de migraciones Alembic contra PostgreSQL temporal (#119).

Ejecuta `upgrade head`, `downgrade base`, `upgrade head` y verifica que el
esquema resultante coincide con `Base.metadata`. Las migraciones usan tipos
específicos de PostgreSQL, por lo que el test requiere un servidor PostgreSQL:
se toma de `MIGRATION_TEST_DATABASE_URL` o, si no existe, de `DATABASE_URL`
cuando apunta a `postgresql`. En caso contrario el test se omite con motivo
explícito. Se crea una base temporal (`CREATE DATABASE`) y se elimina al final.
"""

import asyncio
import os
import subprocess
import sys
import uuid
from pathlib import Path

import pytest
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy import inspect, text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine

import app.models  # noqa: F401  (registra todas las tablas en Base.metadata)
from app.database import Base

BACKEND_DIR = Path(__file__).resolve().parent.parent


def _server_url() -> str | None:
    for var in ("MIGRATION_TEST_DATABASE_URL", "DATABASE_URL"):
        value = os.environ.get(var, "")
        if value.startswith("postgresql"):
            return value
    return None


pytestmark = pytest.mark.skipif(
    _server_url() is None,
    reason=(
        "Requiere PostgreSQL: define MIGRATION_TEST_DATABASE_URL (o DATABASE_URL) "
        "con una URL postgresql+asyncpg://..."
    ),
)


def _alembic(url: str, *args: str) -> None:
    env = {**os.environ, "DATABASE_URL": url}
    result = subprocess.run(
        [sys.executable, "-m", "alembic", *args],
        cwd=BACKEND_DIR,
        env=env,
        capture_output=True,
        text=True,
        timeout=300,
    )
    assert result.returncode == 0, (
        f"alembic {' '.join(args)} falló:\n{result.stdout}\n{result.stderr}"
    )


async def _admin(server_url: str, statement: str) -> None:
    engine = create_async_engine(server_url, isolation_level="AUTOCOMMIT")
    async with engine.connect() as conn:
        await conn.execute(text(statement))
    await engine.dispose()


async def _table_names(url: str) -> set[str]:
    engine = create_async_engine(url)
    async with engine.connect() as conn:
        names = await conn.run_sync(lambda c: set(inspect(c).get_table_names()))
    await engine.dispose()
    return names


async def _schema_diff(url: str) -> list:
    engine = create_async_engine(url)

    def _compare(sync_conn):
        ctx = MigrationContext.configure(
            sync_conn, opts={"compare_type": True, "compare_server_default": False}
        )
        return compare_metadata(ctx, Base.metadata)

    async with engine.connect() as conn:
        diff = await conn.run_sync(_compare)
    await engine.dispose()
    return diff


def test_upgrade_downgrade_upgrade_matches_models():
    server_url = _server_url()
    assert server_url is not None
    db_name = f"migration_test_{uuid.uuid4().hex[:12]}"
    temp_url = make_url(server_url).set(database=db_name).render_as_string(hide_password=False)

    asyncio.run(_admin(server_url, f'CREATE DATABASE "{db_name}"'))
    try:
        _alembic(temp_url, "upgrade", "head")
        _alembic(temp_url, "downgrade", "base")
        leftover = asyncio.run(_table_names(temp_url)) - {"alembic_version"}
        assert leftover == set(), f"downgrade base dejó tablas: {sorted(leftover)}"

        _alembic(temp_url, "upgrade", "head")
        diff = asyncio.run(_schema_diff(temp_url))
        assert diff == [], f"El esquema migrado difiere de Base.metadata: {diff}"
    finally:
        asyncio.run(_admin(server_url, f'DROP DATABASE IF EXISTS "{db_name}" WITH (FORCE)'))
