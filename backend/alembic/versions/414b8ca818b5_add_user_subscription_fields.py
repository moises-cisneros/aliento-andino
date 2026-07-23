"""add user subscription fields

Revision ID: 414b8ca818b5
Revises: c3d4e5f6a7b8
Create Date: 2026-06-21 23:43:29.603148
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# Identificadores de revisión usados por Alembic
revision: str = '414b8ca818b5'
down_revision: Union[str, None] = 'c3d4e5f6a7b8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Solo las columnas de suscripción (se quitó drift no relacionado del
    # autogenerate para no tocar índices/constraints de otras tablas).
    op.add_column('users', sa.Column('subscription_status', sa.String(length=20), server_default='free', nullable=False))
    op.add_column('users', sa.Column('subscription_plan', sa.String(length=20), nullable=True))
    op.add_column('users', sa.Column('subscription_started_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('users', sa.Column('subscription_expires_at', sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'subscription_expires_at')
    op.drop_column('users', 'subscription_started_at')
    op.drop_column('users', 'subscription_plan')
    op.drop_column('users', 'subscription_status')
