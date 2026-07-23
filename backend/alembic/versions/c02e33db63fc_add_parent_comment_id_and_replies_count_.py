"""add parent_comment_id and replies_count to comments

Revision ID: c02e33db63fc
Revises: 8ad72a4a0b79
Create Date: 2026-05-24 11:30:58.795523
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = 'c02e33db63fc'
down_revision: Union[str, None] = '8ad72a4a0b79'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'comments',
        sa.Column(
            'parent_comment_id',
            postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.add_column(
        'comments',
        sa.Column(
            'replies_count',
            sa.Integer(),
            nullable=False,
            server_default='0',
        ),
    )
    op.create_index(
        'ix_comments_parent_comment_id',
        'comments',
        ['parent_comment_id'],
    )
    op.create_foreign_key(
        'fk_comments_parent_comment_id',
        'comments',
        'comments',
        ['parent_comment_id'],
        ['id'],
        ondelete='CASCADE',
    )


def downgrade() -> None:
    op.drop_constraint('fk_comments_parent_comment_id', 'comments', type_='foreignkey')
    op.drop_index('ix_comments_parent_comment_id', table_name='comments')
    op.drop_column('comments', 'replies_count')
    op.drop_column('comments', 'parent_comment_id')
