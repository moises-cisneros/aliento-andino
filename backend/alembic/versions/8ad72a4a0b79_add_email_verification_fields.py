"""add email verification fields

Revision ID: 8ad72a4a0b79
Revises: 2db6b187f2e7
Create Date: 2026-05-24 10:14:26
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '8ad72a4a0b79'
down_revision: Union[str, None] = '2db6b187f2e7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column('email_verification_code', sa.String(length=6), nullable=True),
    )
    op.add_column(
        'users',
        sa.Column(
            'email_verification_expires',
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column('users', 'email_verification_expires')
    op.drop_column('users', 'email_verification_code')
