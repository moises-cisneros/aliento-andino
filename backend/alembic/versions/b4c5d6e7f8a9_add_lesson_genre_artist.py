"""add genre and artist to lessons

Revision ID: b4c5d6e7f8a9
Revises: f9e8d7c6b5a4
Create Date: 2026-06-22 13:10:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'b4c5d6e7f8a9'
down_revision: Union[str, None] = 'f9e8d7c6b5a4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('lessons', sa.Column('genre', sa.String(length=40), nullable=True))
    op.add_column('lessons', sa.Column('artist', sa.String(length=120), nullable=True))
    op.create_index('ix_lessons_genre', 'lessons', ['genre'])


def downgrade() -> None:
    op.drop_index('ix_lessons_genre', table_name='lessons')
    op.drop_column('lessons', 'artist')
    op.drop_column('lessons', 'genre')
