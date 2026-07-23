"""add subscription_trial_used to users

Revision ID: f9e8d7c6b5a4
Revises: 414b8ca818b5
Create Date: 2026-06-22 11:42:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# Identificadores de revisión usados por Alembic
revision: str = 'f9e8d7c6b5a4'
down_revision: Union[str, None] = '414b8ca818b5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column(
            'subscription_trial_used',
            sa.Boolean(),
            server_default=sa.text('false'),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column('users', 'subscription_trial_used')
