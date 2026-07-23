"""add hashtags and post_hashtags tables

Soporte de hashtags clickeables con feed propio. `hashtags` guarda el tag
normalizado (minúscula, sin '#') + contador; `post_hashtags` enlaza post↔hashtag.

Revision ID: c1a2b3c4d5e6
Revises: b2c3d4e5f6a7
Create Date: 2026-06-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "c1a2b3c4d5e6"
down_revision: Union[str, None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "hashtags",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tag", sa.String(length=100), nullable=False),
        sa.Column(
            "posts_count", sa.Integer(), nullable=False, server_default="0"
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_hashtags_tag", "hashtags", ["tag"], unique=True)

    op.create_table(
        "post_hashtags",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "post_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("posts.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "hashtag_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("hashtags.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("post_id", "hashtag_id", name="uq_post_hashtag"),
    )
    op.create_index(
        "ix_post_hashtags_hashtag_id", "post_hashtags", ["hashtag_id"]
    )


def downgrade() -> None:
    op.drop_table("post_hashtags")
    op.drop_table("hashtags")
