"""Schemas Pydantic para autenticación y perfil de usuario."""

import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, model_validator

# --- Requests ---


class RegisterRequest(BaseModel):
    """Schema para registro de nuevo usuario."""

    email: EmailStr
    username: str = Field(min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_]+$")
    full_name: str = Field(min_length=1, max_length=255)
    password: str = Field(min_length=8, max_length=128)
    password_confirm: str
    skill_level: str | None = Field(None, pattern=r"^(beginner|intermediate|advanced)$")

    @model_validator(mode="after")
    def passwords_match(self):
        """Validar que las contraseñas coincidan."""
        if self.password != self.password_confirm:
            raise ValueError("Las contraseñas no coinciden")
        return self


class LoginRequest(BaseModel):
    """Schema para login con email y password."""

    email: EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    """Schema para autenticación con Google OAuth."""

    google_token: str


class RefreshTokenRequest(BaseModel):
    """Schema para refrescar el access token (opcional si se usa httpOnly cookie)."""

    refresh_token: str | None = None


class ForgotPasswordRequest(BaseModel):
    """Schema para solicitar reset de contraseña."""

    email: EmailStr


class ResetPasswordRequest(BaseModel):
    """Schema para resetear la contraseña con token."""

    token: str
    new_password: str = Field(min_length=8, max_length=128)
    new_password_confirm: str

    @model_validator(mode="after")
    def passwords_match(self):
        """Validar que las contraseñas coincidan."""
        if self.new_password != self.new_password_confirm:
            raise ValueError("Las contraseñas no coinciden")
        return self


class UpdateProfileRequest(BaseModel):
    """Schema para actualizar perfil de usuario (todos los campos opcionales)."""

    full_name: str | None = Field(None, min_length=1, max_length=255)
    username: str | None = Field(None, min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_]+$")
    bio: str | None = Field(None, max_length=1000)
    avatar_url: str | None = Field(None, max_length=500, pattern=r"^https://.*")
    skill_level: str | None = Field(None, pattern=r"^(beginner|intermediate|advanced)$")
    notifications_push_enabled: bool | None = None
    notifications_email_enabled: bool | None = None


class ChangePasswordRequest(BaseModel):
    """Schema para cambiar la contraseña del usuario autenticado."""

    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


class DeleteAccountRequest(BaseModel):
    """Schema para eliminar la cuenta. La contraseña es obligatoria para cuentas
    locales (auth_provider=local); para Google puede ir vacía."""

    password: str | None = None


# --- Responses ---


class UserResponse(BaseModel):
    """Schema de respuesta con datos del usuario."""

    id: uuid.UUID
    email: str
    username: str
    full_name: str
    avatar_url: str | None = None
    bio: str | None = None
    is_active: bool
    is_admin: bool
    is_verified: bool
    auth_provider: str
    skill_level: str | None = None
    preferred_instruments: list[str] | None = None
    breath_sensitivity_rms: float | None = None
    notifications_push_enabled: bool = True
    notifications_email_enabled: bool = True
    # Suscripción (pago simulado)
    is_premium: bool = False
    subscription_status: str = "free"
    subscription_plan: str | None = None
    subscription_expires_at: datetime | None = None
    created_at: datetime
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    """Schema de respuesta con tokens JWT y datos del usuario."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponse


class AccessTokenResponse(BaseModel):
    """Schema de respuesta con tokens rotados (para refresh)."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class MessageResponse(BaseModel):
    """Schema genérico de respuesta con mensaje."""

    message: str
