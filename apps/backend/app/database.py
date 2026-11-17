"""Configuración de base de datos async con SQLAlchemy 2.0 y asyncpg."""

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import StaticPool

from app.config import settings

# Motor async - PostgreSQL-specific pool params only for non-SQLite
_engine_kwargs = {
    "echo": settings.debug,
}

if settings.database_url.startswith("sqlite"):
    _engine_kwargs["poolclass"] = StaticPool
    _engine_kwargs["connect_args"] = {"check_same_thread": False}
else:
    _engine_kwargs["pool_pre_ping"] = True
    _engine_kwargs["pool_size"] = 20
    _engine_kwargs["max_overflow"] = 10
    _engine_kwargs["pool_recycle"] = 3600

engine = create_async_engine(settings.database_url, **_engine_kwargs)

# Fábrica de sesiones async
async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Clase base para todos los modelos SQLAlchemy."""

    pass


async def get_db() -> AsyncSession:
    """Dependency que provee una sesión de base de datos."""
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
