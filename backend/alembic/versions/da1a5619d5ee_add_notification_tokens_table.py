"""add notification_tokens table

Revision ID: da1a5619d5ee
Revises: 3514af00f798
Create Date: 2026-05-24 09:13:49.231360
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Identificadores de revisión usados por Alembic
revision: str = 'da1a5619d5ee'
down_revision: Union[str, None] = '3514af00f798'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'notification_tokens',
        sa.Column('id', sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', sa.dialects.postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('token', sa.String(length=255), nullable=False),
        sa.Column('platform', sa.String(length=20), nullable=False, server_default='android'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.UniqueConstraint('token', name='uq_notification_token'),
    )
    op.create_index(
        'ix_notification_tokens_user_id',
        'notification_tokens',
        ['user_id'],
    )


def downgrade() -> None:
    op.drop_index('ix_notification_tokens_user_id', table_name='notification_tokens')
    op.drop_table('notification_tokens')
