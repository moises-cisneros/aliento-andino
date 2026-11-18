"""Script para crear o promover un usuario Administrador en Aliento Andino."""

import argparse
import asyncio
import os
import uuid

from sqlalchemy import select

from app.database import async_session
from app.models.user import User
from app.utils.security import hash_password


async def create_or_promote_admin(
    email: str | None = None,
    username: str | None = None,
    password: str | None = None,
    full_name: str | None = None,
):
    email = email or os.getenv("ADMIN_EMAIL", "admin@alientoandino.org")
    username = username or os.getenv("ADMIN_USERNAME", "admin")
    password = password or os.getenv("ADMIN_PASSWORD", "Admin1234!")
    full_name = full_name or os.getenv("ADMIN_NAME", "Administrador Aliento Andino")

    if not email or not password:
        print("⚠️ ADMIN_EMAIL o ADMIN_PASSWORD vacíos. Omitiendo aprovisionamiento de admin.")
        return

    async with async_session() as db:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()

        if user:
            user.is_admin = True
            user.is_active = True
            user.is_verified = True
            user.hashed_password = hash_password(password)
            print(f"✅ Usuario existente '{email}' actualizado como Administrador.")
        else:
            # Verificar si el username ya existe
            username_result = await db.execute(select(User).where(User.username == username))
            if username_result.scalar_one_or_none():
                username = f"{username}_{uuid.uuid4().hex[:4]}"

            user = User(
                id=uuid.uuid4(),
                email=email,
                username=username,
                full_name=full_name,
                hashed_password=hash_password(password),
                is_active=True,
                is_admin=True,
                is_verified=True,
                auth_provider="local",
            )
            db.add(user)
            print(f"✅ Nuevo Administrador creado: {email}")

        await db.commit()
        print("🔑 Credenciales listas:")
        print(f"   Email:    {email}")
        print(f"   Password: {password}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Crear usuario Administrador")
    parser.add_argument("--email", default=None)
    parser.add_argument("--username", default=None)
    parser.add_argument("--password", default=None)
    parser.add_argument("--name", default=None)

    args = parser.parse_args()
    asyncio.run(
        create_or_promote_admin(
            email=args.email,
            username=args.username,
            password=args.password,
            full_name=args.name,
        )
    )
