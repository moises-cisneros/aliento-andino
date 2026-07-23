"""add notification prefs to users

Revision ID: cde7b6b94b31
Revises: da1a5619d5ee
Create Date: 2026-05-24 09:34:42.154877
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'cde7b6b94b31'
down_revision: Union[str, None] = 'da1a5619d5ee'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column(
            'notifications_push_enabled',
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.add_column(
        'users',
        sa.Column(
            'notifications_email_enabled',
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )


def downgrade() -> None:
    op.drop_column('users', 'notifications_email_enabled')
    op.drop_column('users', 'notifications_push_enabled')
