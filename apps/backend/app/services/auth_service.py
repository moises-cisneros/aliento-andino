"""Servicio de autenticación: lógica de negocio para registro, login, OAuth, etc."""

import logging
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.user import RefreshToken, User
from app.schemas.auth import (
    ChangePasswordRequest,
    GoogleAuthRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    UpdateProfileRequest,
)
from app.services.email_service import send_password_reset_email, send_verification_email
from app.utils.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)

logger = logging.getLogger(__name__)


async def _create_tokens(user_id: uuid.UUID, db: AsyncSession) -> tuple[str, str]:
    """Crear access + refresh token y almacenar el refresh en DB para revocación."""
    access_token = create_access_token(user_id)
    refresh_token, jti = create_refresh_token(user_id)
    db.add(
        RefreshToken(
            token_jti=jti,
            user_id=user_id,
            expires_at=datetime.now(UTC) + timedelta(days=settings.refresh_token_expire_days),
        )
    )
    await db.flush()
    return access_token, refresh_token


async def register_user(data: RegisterRequest, db: AsyncSession) -> tuple[User, str, str]:
    """
    Registrar un nuevo usuario con autenticación local.
    Retorna (user, access_token, refresh_token).
    """
    # Verificar que el email no esté registrado
    existing_email = await db.execute(select(User).where(User.email == data.email))
    if existing_email.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El email ya está registrado",
        )

    # Verificar que el username no esté en uso
    existing_username = await db.execute(select(User).where(User.username == data.username))
    if existing_username.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El nombre de usuario ya está en uso",
        )

    # Crear usuario
    user = User(
        email=data.email,
        username=data.username,
        full_name=data.full_name,
        hashed_password=hash_password(data.password),
        auth_provider="local",
        is_verified=False,
        skill_level=data.skill_level,
    )
    db.add(user)
    await db.flush()

    # Enviar email de verificación (simulado)
    await send_verification_email(user.email, user.username)

    # Generar tokens
    access_token, refresh_token = await _create_tokens(user.id, db)

    logger.info("Nuevo usuario registrado: %s (%s)", user.email, user.id)
    return user, access_token, refresh_token


async def login_user(data: LoginRequest, db: AsyncSession) -> tuple[User, str, str]:
    """
    Autenticar usuario con email y password.
    Retorna (user, access_token, refresh_token).
    """
    # Buscar usuario por email
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if user is None or user.hashed_password is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales inválidas",
        )

    # Verificar contraseña
    if not verify_password(data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales inválidas",
        )

    # Verificar que la cuenta esté activa
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Cuenta desactivada",
        )

    # Generar tokens
    access_token, refresh_token = await _create_tokens(user.id, db)

    logger.info("Login exitoso: %s", user.email)
    return user, access_token, refresh_token


async def google_auth(data: GoogleAuthRequest, db: AsyncSession) -> tuple[User, str, str]:
    """
    Autenticar o registrar usuario con Google OAuth.
    Verifica el ID token con Google y crea/actualiza la cuenta.
    Retorna (user, access_token, refresh_token).
    """
    # Verificar ID token con la librería oficial de Google (valida aud, iss, exp)
    try:
        google_data = google_id_token.verify_oauth2_token(
            data.google_token,
            google_requests.Request(),
            audience=settings.google_client_id,
        )
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de Google inválido o expirado",
        )

    google_id = google_data.get("sub")
    email = google_data.get("email")
    name = google_data.get("name", "")
    picture = google_data.get("picture")

    if not google_id or not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No se pudo obtener información de Google",
        )

    # Buscar usuario existente por google_id o email
    result = await db.execute(
        select(User).where((User.google_id == google_id) | (User.email == email))
    )
    user = result.scalar_one_or_none()

    if user is None:
        # Crear nuevo usuario con datos de Google
        # Generar username a partir del email
        base_username = email.split("@")[0].replace(".", "_")[:45]
        username = base_username

        # Asegurar que el username sea único
        counter = 1
        for _ in range(100):
            existing = await db.execute(select(User).where(User.username == username))
            if existing.scalar_one_or_none() is None:
                break
            username = f"{base_username}_{counter}"
            counter += 1
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No se pudo generar un nombre de usuario único",
            )

        user = User(
            email=email,
            username=username,
            full_name=name,
            google_id=google_id,
            avatar_url=picture,
            auth_provider="google",
            is_verified=True,  # Google ya verificó el email
        )
        db.add(user)
        await db.flush()
        logger.info("Nuevo usuario Google registrado: %s (%s)", email, user.id)
    else:
        # Si el usuario ya existe con ese google_id, es un login normal
        if user.google_id == google_id:
            logger.info("Login Google exitoso: %s", email)
        elif user.google_id is None:
            # Usuario local existente — NO vincular automáticamente (evitar account takeover)
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ya existe una cuenta con ese email. Iniciá sesión con tu contraseña.",
            )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Cuenta desactivada",
        )

    # Generar tokens
    access_token, refresh_token = await _create_tokens(user.id, db)

    return user, access_token, refresh_token


async def refresh_access_token(refresh_token_str: str, db: AsyncSession) -> tuple[str, str]:
    """
    Validar refresh token, revocar el actual y emitir nuevos tokens (rotación).
    Retorna (new_access_token, new_refresh_token).
    """
    payload = decode_token(refresh_token_str)

    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token inválido o expirado",
        )

    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tipo de token inválido",
        )

    user_id = payload.get("sub")
    jti = payload.get("jti")
    if user_id is None or jti is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido",
        )

    # Verificar que el refresh token no esté revocado
    result_token = await db.execute(select(RefreshToken).where(RefreshToken.token_jti == jti))
    stored_token = result_token.scalar_one_or_none()

    if stored_token is None or stored_token.is_revoked:
        # Si está revocado, posible robo — revocar TODOS los tokens del usuario
        if stored_token and stored_token.is_revoked:
            await db.execute(
                update(RefreshToken)
                .where(RefreshToken.user_id == uuid.UUID(user_id))
                .values(is_revoked=True)
            )
            logger.warning("Posible robo de refresh token para user %s — revocando todos", user_id)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token inválido o revocado",
        )

    # Revocar el token actual (rotación)
    stored_token.is_revoked = True

    # Verificar que el usuario siga existente y activo
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()

    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado o cuenta desactivada",
        )

    # Emitir nuevos tokens (rotación)
    access_token, new_refresh_token = await _create_tokens(user.id, db)
    return access_token, new_refresh_token


async def forgot_password(email: str, db: AsyncSession) -> None:
    """
    Generar token de reset de contraseña y simular envío de email.
    No revela si el email existe por seguridad.
    """
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if user is not None and user.auth_provider == "local":
        # Generar código numérico de 6 dígitos
        reset_code = f"{secrets.randbelow(1_000_000):06d}"
        user.password_reset_token = reset_code
        user.password_reset_expires = datetime.now(UTC) + timedelta(minutes=15)

        await send_password_reset_email(user.email, reset_code)
        logger.info("Código de reset generado para: %s", email)
    else:
        # No revelar si el email existe
        logger.info("Solicitud de reset para email no encontrado o Google: %s", email)


async def reset_password(data: ResetPasswordRequest, db: AsyncSession) -> tuple[User, str, str]:
    """Resetear contraseña y retornar tokens para auto-login."""
    result = await db.execute(select(User).where(User.password_reset_token == data.token))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token de reset inválido",
        )

    # Verificar que el token no haya expirado
    if user.password_reset_expires is None or user.password_reset_expires < datetime.now(UTC):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token de reset expirado",
        )

    # Actualizar contraseña y limpiar token
    user.hashed_password = hash_password(data.new_password)
    user.password_reset_token = None
    user.password_reset_expires = None

    # Generar tokens para auto-login
    access_token, refresh_token = await _create_tokens(user.id, db)

    # Flush + refresh para que Pydantic pueda serializar todos los campos
    await db.flush()
    await db.refresh(user)

    logger.info("Contraseña reseteada exitosamente para: %s", user.email)
    return user, access_token, refresh_token


async def update_user_profile(user: User, data: UpdateProfileRequest, db: AsyncSession) -> User:
    """Actualizar perfil del usuario con los campos proporcionados."""
    update_data = data.model_dump(exclude_unset=True)

    # Verificar unicidad del username si se está actualizando
    if "username" in update_data and update_data["username"] is not None:
        existing = await db.execute(
            select(User).where(User.username == update_data["username"], User.id != user.id)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="El nombre de usuario ya está en uso",
            )

    # Aplicar cambios
    for field, value in update_data.items():
        if value is not None:
            setattr(user, field, value)

    await db.flush()
    await db.refresh(user)

    logger.info("Perfil actualizado para: %s", user.email)
    return user


async def change_password(user: User, data: ChangePasswordRequest, db: AsyncSession) -> None:
    """Cambiar la contraseña verificando la actual."""
    if not user.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tu cuenta usa autenticación de Google. No puedes cambiar la contraseña.",
        )
    if not verify_password(data.current_password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="La contraseña actual es incorrecta",
        )
    user.hashed_password = hash_password(data.new_password)
    await db.flush()
    logger.info("Contraseña cambiada para: %s", user.email)


async def delete_account(user: User, password: str | None, db: AsyncSession) -> None:
    """Eliminar definitivamente la cuenta y todos sus datos.

    Para cuentas locales exige la contraseña actual. El borrado de datos
    relacionados (XP, prácticas, posts, seguidores, notificaciones, etc.) lo
    resuelve la cascada de FKs (ondelete=CASCADE); las lecciones creadas por el
    usuario quedan con created_by=NULL (ondelete=SET NULL).
    """
    if user.hashed_password:  # noqa: SIM102
        if not password or not verify_password(password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="La contraseña es incorrecta",
            )
    # El modelo User no tiene relaciones ORM, así que esto solo emite el DELETE
    # de la fila; el resto de datos del usuario los borra la cascada de FKs en la
    # BD. Usamos el ORM (no Core) para que la instancia salga del identity map.
    user_email = user.email
    await db.delete(user)
    # Commit explícito: el borrado es irreversible y queremos que sea durable
    # antes de limpiar la sesión/cookie del request.
    await db.commit()
    logger.info("Cuenta eliminada: %s", user_email)


async def logout_user(user_id: uuid.UUID, db: AsyncSession) -> None:
    """Revocar todos los refresh tokens del usuario (server-side logout)."""
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.is_revoked == False)
        .values(is_revoked=True)
    )
    logger.info("Todos los refresh tokens revocados para user: %s", user_id)
