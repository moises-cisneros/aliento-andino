"""Router de autenticación con todos los endpoints de auth."""

import logging
from datetime import UTC

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.rate_limit import limiter
from app.schemas.auth import (
    AccessTokenResponse,
    ChangePasswordRequest,
    DeleteAccountRequest,
    ForgotPasswordRequest,
    GoogleAuthRequest,
    LoginRequest,
    MessageResponse,
    RefreshTokenRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    UpdateProfileRequest,
    UserResponse,
)
from app.services import auth_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["Autenticación"])


def _set_refresh_cookie(response: Response, token: str) -> None:
    """Establecer refresh token como cookie httpOnly."""
    response.set_cookie(
        key="pv_refresh_token",
        value=token,
        httponly=True,
        secure=not settings.debug,
        samesite="lax",
        path="/api/auth",
        max_age=settings.refresh_token_expire_days * 24 * 60 * 60,
    )


def _clear_refresh_cookie(response: Response) -> None:
    """Eliminar la cookie de refresh token."""
    response.delete_cookie(
        key="pv_refresh_token",
        httponly=True,
        secure=not settings.debug,
        samesite="lax",
        path="/api/auth",
    )


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar nuevo usuario",
)
@limiter.limit("5/minute")
async def register(
    request: Request, response: Response, data: RegisterRequest, db: AsyncSession = Depends(get_db)
):
    """
    Registrar un nuevo usuario con email y contraseña.
    Retorna tokens JWT y datos del usuario.
    """
    user, access_token, refresh_token = await auth_service.register_user(data, db)
    _set_refresh_cookie(response, refresh_token)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse.model_validate(user),
    )


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Iniciar sesión",
)
@limiter.limit("10/minute")
async def login(
    request: Request, response: Response, data: LoginRequest, db: AsyncSession = Depends(get_db)
):
    """
    Autenticar usuario con email y contraseña.
    Retorna tokens JWT y datos del usuario.
    """
    user, access_token, refresh_token = await auth_service.login_user(data, db)
    _set_refresh_cookie(response, refresh_token)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse.model_validate(user),
    )


@router.post(
    "/google",
    response_model=TokenResponse,
    summary="Autenticación con Google",
)
@limiter.limit("10/minute")
async def google(
    request: Request,
    response: Response,
    data: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Autenticar o registrar usuario con Google OAuth.
    Si el usuario no existe, se crea automáticamente.
    """
    user, access_token, refresh_token = await auth_service.google_auth(data, db)
    _set_refresh_cookie(response, refresh_token)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse.model_validate(user),
    )


@router.post(
    "/refresh",
    response_model=AccessTokenResponse,
    summary="Refrescar access token",
)
@limiter.limit("10/minute")
async def refresh(
    request: Request,
    response: Response,
    data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Generar nuevos tokens usando un refresh token válido (rotación).
    Acepta refresh token via httpOnly cookie (web) o body (mobile).
    """
    refresh_token_value = request.cookies.get("pv_refresh_token") or data.refresh_token
    if not refresh_token_value:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token requerido",
        )
    new_access_token, new_refresh_token = await auth_service.refresh_access_token(
        refresh_token_value, db
    )
    _set_refresh_cookie(response, new_refresh_token)
    return AccessTokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
    )


@router.post(
    "/logout",
    response_model=MessageResponse,
    summary="Cerrar sesión (revocar tokens)",
)
async def logout(
    response: Response,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Revocar todos los refresh tokens del usuario y limpiar cookie."""
    await auth_service.logout_user(current_user.id, db)
    _clear_refresh_cookie(response)
    return MessageResponse(message="Sesión cerrada exitosamente")


@router.post(
    "/forgot-password",
    response_model=MessageResponse,
    summary="Solicitar recuperación de contraseña",
)
@limiter.limit("3/minute")
async def forgot_password(
    request: Request, data: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)
):
    """
    Enviar email de recuperación de contraseña.
    Por seguridad, siempre retorna éxito sin revelar si el email existe.
    """
    await auth_service.forgot_password(data.email, db)
    return MessageResponse(
        message="Si el email existe, recibirás instrucciones para restablecer tu contraseña"
    )


@router.post(
    "/reset-password",
    response_model=TokenResponse,
    summary="Restablecer contraseña con token",
)
@limiter.limit("5/minute")
async def reset_password(
    request: Request,
    response: Response,
    data: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Restablecer la contraseña usando el token enviado por email.
    Retorna tokens para auto-login.
    """
    user, access_token, refresh_token = await auth_service.reset_password(data, db)
    _set_refresh_cookie(response, refresh_token)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=user,
    )


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Obtener perfil del usuario autenticado",
)
async def get_me(current_user: User = Depends(get_current_user)):
    """
    Retorna los datos del usuario autenticado.
    Requiere access token válido en el header Authorization.
    """
    return UserResponse.model_validate(current_user)


@router.put(
    "/me",
    response_model=UserResponse,
    summary="Actualizar perfil del usuario autenticado",
)
async def update_me(
    data: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Actualizar el perfil del usuario autenticado.
    Solo se actualizan los campos proporcionados.
    """
    updated_user = await auth_service.update_user_profile(current_user, data, db)
    return UserResponse.model_validate(updated_user)


@router.put(
    "/change-password",
    response_model=MessageResponse,
    summary="Cambiar contraseña del usuario autenticado",
)
async def change_password(
    data: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cambiar la contraseña verificando la contraseña actual."""
    await auth_service.change_password(current_user, data, db)
    return MessageResponse(message="Contraseña actualizada correctamente")


@router.delete(
    "/me",
    response_model=MessageResponse,
    summary="Eliminar definitivamente la cuenta del usuario autenticado",
)
async def delete_me(
    data: DeleteAccountRequest,
    response: Response,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Eliminar la cuenta y todos los datos del usuario (irreversible)."""
    await auth_service.delete_account(current_user, data.password, db)
    _clear_refresh_cookie(response)
    return MessageResponse(message="Cuenta eliminada correctamente")


# ============== VERIFICACIÓN DE EMAIL ==============


class VerifyEmailRequest(BaseModel):
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")


@router.post(
    "/send-verification-code",
    response_model=MessageResponse,
    summary="Enviar código de verificación al email del usuario",
)
@limiter.limit("3/minute")
async def send_verification_code(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generar un código de 6 dígitos, persistirlo y enviarlo por email."""
    if current_user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tu email ya está verificado",
        )

    import secrets
    from datetime import datetime, timedelta

    from app.services.email_service import send_email_verification_code

    code = f"{secrets.randbelow(1_000_000):06d}"
    current_user.email_verification_code = code
    current_user.email_verification_expires = datetime.now(UTC) + timedelta(minutes=15)
    await db.commit()

    try:
        await send_email_verification_code(current_user.email, code)
    except Exception as e:
        logger.error("No se pudo enviar email de verificación: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo enviar el email. Reintentá en unos minutos.",
        )

    return MessageResponse(message="Código enviado a tu email")


@router.post(
    "/verify-email",
    response_model=MessageResponse,
    summary="Verificar el email con el código recibido",
)
@limiter.limit("10/minute")
async def verify_email(
    request: Request,
    data: VerifyEmailRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Validar el código y marcar is_verified=True."""
    from datetime import datetime

    if current_user.is_verified:
        return MessageResponse(message="Tu email ya estaba verificado")

    if not current_user.email_verification_code or not current_user.email_verification_expires:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Primero solicitá el código",
        )

    if current_user.email_verification_expires < datetime.now(UTC):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El código expiró. Pedí uno nuevo.",
        )

    if current_user.email_verification_code != data.code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Código incorrecto",
        )

    current_user.is_verified = True
    current_user.email_verification_code = None
    current_user.email_verification_expires = None
    await db.commit()

    return MessageResponse(message="Email verificado correctamente")
