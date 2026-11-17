"""Modelos de usuario y refresh token para Aliento Andino."""

import uuid
from datetime import UTC, datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class User(Base):
    """Tabla de usuarios con soporte para auth local y Google OAuth."""

    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    hashed_password: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,  # Nullable para usuarios de Google OAuth
    )
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    bio: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    # Estado de la cuenta
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)

    # Proveedor de autenticación
    auth_provider: Mapped[str] = mapped_column(
        String(20),
        default="local",  # "local" o "google"
    )
    google_id: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)

    # Recuperación de contraseña
    password_reset_token: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    password_reset_expires: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Verificación de email (código de 6 dígitos enviado por SMTP)
    email_verification_code: Mapped[str | None] = mapped_column(String(6), nullable=True)
    email_verification_expires: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Contadores sociales (counter cache)
    followers_count: Mapped[int] = mapped_column(Integer, default=0)
    following_count: Mapped[int] = mapped_column(Integer, default=0)
    posts_count: Mapped[int] = mapped_column(Integer, default=0)

    # Ban
    is_banned: Mapped[bool] = mapped_column(Boolean, default=False)
    ban_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Nivel XP (cache para display rápido)
    xp_level: Mapped[int] = mapped_column(Integer, default=1)

    # Nivel auto-declarado durante el onboarding ("beginner", "intermediate", "advanced")
    skill_level: Mapped[str | None] = mapped_column(String(20), nullable=True)

    # Preferencias de instrumento y calibración respiratoria (HU-19 / SUB-19-B)
    preferred_instruments: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    breath_sensitivity_rms: Mapped[float | None] = mapped_column(Float, nullable=True)

    # Preferencias de notificaciones (default ambas en True)
    notifications_push_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    notifications_email_enabled: Mapped[bool] = mapped_column(Boolean, default=True)

    # Suscripción (pago simulado). status: "free" | "premium".
    subscription_status: Mapped[str] = mapped_column(
        String(20), default="free", server_default="free", nullable=False
    )
    subscription_plan: Mapped[str | None] = mapped_column(
        String(20), nullable=True
    )  # "monthly" | "annual"
    subscription_started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    subscription_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # True una vez que el usuario usó la prueba gratis (no se puede repetir).
    subscription_trial_used: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    @property
    def is_premium(self) -> bool:
        """True si tiene suscripción premium vigente (no vencida)."""
        if self.subscription_status != "premium":
            return False
        expires = self.subscription_expires_at
        if expires is None:
            return False
        # Algunos backends (SQLite, ciertos drivers) devuelven datetimes sin
        # zona; los tratamos como UTC para evitar comparar naive con aware.
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=UTC)
        return expires > datetime.now(UTC)

    def __repr__(self) -> str:
        return f"<User {self.email}>"


class RefreshToken(Base):
    """Tabla de refresh tokens para revocación y rotación."""

    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    token_jti: Mapped[str] = mapped_column(String(36), unique=True, index=True, nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    is_revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    def __repr__(self) -> str:
        return f"<RefreshToken {self.token_jti}>"
