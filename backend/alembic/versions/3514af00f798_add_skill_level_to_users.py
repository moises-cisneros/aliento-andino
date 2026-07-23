"""add skill_level to users

Revision ID: 3514af00f798
Revises: 4c8e1f3a7b02
Create Date: 2026-05-23 22:30:15.472186
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Identificadores de revisión usados por Alembic
revision: str = '3514af00f798'
down_revision: Union[str, None] = '4c8e1f3a7b02'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column('skill_level', sa.String(length=20), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('users', 'skill_level')
