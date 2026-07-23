"""add_rankings_module

Revision ID: 4c8e1f3a7b02
Revises: 3b7f2a9c8e01
Create Date: 2026-04-05 23:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# Identificadores de revisión usados por Alembic
revision: str = '4c8e1f3a7b02'
down_revision: Union[str, None] = '3b7f2a9c8e01'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- Campo xp_level en tabla users ---
    op.add_column('users', sa.Column('xp_level', sa.Integer(), nullable=False, server_default='1'))

    # --- Tabla user_xp ---
    op.create_table('user_xp',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('total_xp', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('weekly_xp', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('level', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('current_streak', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('longest_streak', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('total_practice_sessions', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('total_practice_minutes', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('total_lessons_completed', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('total_perfect_scores', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('average_score', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('last_practice_date', sa.Date(), nullable=True),
        sa.Column('week_start_date', sa.Date(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id'),
    )
    op.create_index('ix_user_xp_user_id', 'user_xp', ['user_id'])
    op.create_index('ix_user_xp_total_xp', 'user_xp', ['total_xp'])
    op.create_index('ix_user_xp_weekly_xp', 'user_xp', ['weekly_xp'])

    # --- Tabla achievements ---
    op.create_table('achievements',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('code', sa.String(length=50), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('description', sa.String(length=500), nullable=False),
        sa.Column('icon', sa.String(length=50), nullable=False),
        sa.Column('category', sa.String(length=30), nullable=False),
        sa.Column('xp_reward', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('requirement_type', sa.String(length=30), nullable=False),
        sa.Column('requirement_value', sa.Integer(), nullable=False),
        sa.Column('rarity', sa.String(length=20), nullable=False, server_default="'common'"),
        sa.Column('order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('code'),
    )

    # --- Tabla user_achievements ---
    op.create_table('user_achievements',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('achievement_id', sa.UUID(), nullable=False),
        sa.Column('unlocked_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['achievement_id'], ['achievements.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'achievement_id', name='uq_user_achievement'),
    )
    op.create_index('ix_user_achievements_user_id', 'user_achievements', ['user_id'])
    op.create_index('ix_user_achievements_achievement_id', 'user_achievements', ['achievement_id'])


def downgrade() -> None:
    op.drop_table('user_achievements')
    op.drop_table('achievements')
    op.drop_table('user_xp')
    op.drop_column('users', 'xp_level')
