"""Punto de entrada de la aplicación Aliento Andino API."""

import asyncio
import logging
from contextlib import asynccontextmanager
from datetime import UTC, datetime

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from sqlalchemy import delete, or_
from starlette.middleware.base import BaseHTTPMiddleware

from app.config import settings
from app.database import async_session
from app.models.user import RefreshToken
from app.rate_limit import limiter
from app.routers import (
    admin_analytics,
    admin_announcements,
    admin_audit,
    admin_config,
    admin_export,
    admin_lessons,
    admin_rankings,
    admin_social,
    admin_subscriptions,
    auth,
    challenges,
    fingerings,
    lessons,
    notifications,
    practice,
    rankings,
    social,
    subscription,
    tuning,
    tutor,
    uploads,
    users,
)

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


async def _cleanup_expired_tokens():
    """Background task: cleanup expired/revoked refresh tokens every 6 hours."""
    while True:
        try:
            await asyncio.sleep(6 * 60 * 60)  # 6 hours
            async with async_session() as session:
                result = await session.execute(
                    delete(RefreshToken).where(
                        or_(
                            RefreshToken.expires_at < datetime.now(UTC),
                            RefreshToken.is_revoked.is_(True),
                        )
                    )
                )
                await session.commit()
                if result.rowcount:
                    logger.info("Cleaned up %d expired/revoked refresh tokens", result.rowcount)
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error("Error cleaning up tokens: %s", e)


async def _streak_warning_loop():
    """Background task: cada hora, avisa a usuarios cuya racha está por romperse.

    Criterio: current_streak >= 1, last_practice_date == ayer, hora local > 20:00.
    Mandamos una sola vez por día (idempotencia simple por bandera en BD futura).
    """
    from datetime import timedelta

    from sqlalchemy import select

    from app.models.ranking import UserXP
    from app.services import notification_dispatcher

    # Esperar 30s tras startup para que la app esté lista
    await asyncio.sleep(30)
    while True:
        try:
            now = datetime.now(UTC)
            yesterday = (now - timedelta(days=1)).date()

            async with async_session() as session:
                result = await session.execute(
                    select(UserXP.user_id, UserXP.current_streak).where(
                        UserXP.current_streak >= 1,
                        UserXP.last_practice_date == yesterday,
                    )
                )
                rows = result.all()

                for user_id, streak in rows:
                    await notification_dispatcher.notify_user(
                        session,
                        user_id=user_id,
                        title="¡Tu racha está por romperse! 🔥",
                        body=f"Llevás {streak} día{'s' if streak != 1 else ''} seguidos. No la pierdas hoy.",
                        data={"type": "streak_warning", "streak": str(streak)},
                    )

                if rows:
                    logger.info("Streak warning enviado a %d usuarios", len(rows))

            # Correr cada hora
            await asyncio.sleep(60 * 60)
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error("Error en streak_warning_loop: %s", e, exc_info=True)
            await asyncio.sleep(60 * 60)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup/shutdown lifecycle."""
    # Cargar la configuración editable (precios, trial, flags) al cache.
    try:
        from app.database import async_session
        from app.services import config_service

        async with async_session() as db:
            await config_service.load(db)
        logger.info("Config cargada")
    except Exception as e:  # noqa: BLE001
        logger.warning("No se pudo cargar la config: %s", e)
    cleanup_task = asyncio.create_task(_cleanup_expired_tokens())
    streak_task = asyncio.create_task(_streak_warning_loop())
    logger.info("Background tasks started: token cleanup + streak warning")
    yield
    cleanup_task.cancel()
    streak_task.cancel()
    for t in (cleanup_task, streak_task):
        try:  # noqa: SIM105 - explicit await keeps cancellation handling readable
            await t
        except asyncio.CancelledError:
            pass


app = FastAPI(
    title="Aliento Andino API",
    description="API de autenticación y servicios para Aliento Andino",
    version="0.1.0",
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
    lifespan=lifespan,
)

# Rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


# --- Security Headers Middleware ---
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        if not settings.debug:
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
            response.headers["Content-Security-Policy"] = (
                "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' https: data:; font-src 'self' https:; connect-src 'self'"
            )
        return response


app.add_middleware(SecurityHeadersMiddleware)

# Configurar CORS para Angular (web) y Flutter (mobile)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

# Registrar routers
app.include_router(auth.router)
app.include_router(lessons.router)
app.include_router(fingerings.router)
app.include_router(practice.router)
app.include_router(admin_lessons.router)
app.include_router(social.router)
app.include_router(users.router)
app.include_router(users.v1_router)
app.include_router(admin_social.router)
app.include_router(admin_subscriptions.router)
app.include_router(admin_announcements.router)
app.include_router(admin_config.router)
app.include_router(admin_export.router)
app.include_router(admin_audit.router)
app.include_router(rankings.router)
app.include_router(challenges.router)
app.include_router(admin_rankings.router)
app.include_router(admin_analytics.router)
app.include_router(uploads.router)
app.include_router(notifications.router)
app.include_router(subscription.router)
app.include_router(tuning.router)
app.include_router(tutor.router)


# --- Global exception handler ---
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception: %s", exc, exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Error interno del servidor"},
    )


@app.get("/")
async def root():
    return {"message": "Aliento Andino API running"}


@app.get("/health")
async def health():
    return {"status": "ok"}
