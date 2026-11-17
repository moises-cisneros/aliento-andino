"""add user preferences and breath rms

Revision ID: a2b3c4d5e6f7
Revises: f8a9b0c1d2e3
Create Date: 2026-11-17 02:20:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'a2b3c4d5e6f7'
down_revision: Union[str, None] = 'f8a9b0c1d2e3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column(
            'preferred_instruments',
            sa.JSON(),
            nullable=True,
        ),
    )
    op.add_column(
        'users',
        sa.Column(
            'breath_sensitivity_rms',
            sa.Float(),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column('users', 'breath_sensitivity_rms')
    op.drop_column('users', 'preferred_instruments')
