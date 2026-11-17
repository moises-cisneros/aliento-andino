"""add composite index (user_id, created_at DESC) to practice_sessions

Speeds up the paginated practice history (HU-10 / SUB-10-B).

Revision ID: a3c4d5e6f7a8
Revises: a2b3c4d5e6f7
Create Date: 2026-11-17
"""
from typing import Sequence, Union

from alembic import op

revision: str = "a3c4d5e6f7a8"
down_revision: Union[str, None] = "a2b3c4d5e6f7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_practice_sessions_user_id_created_at "
        "ON practice_sessions (user_id, created_at DESC)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_practice_sessions_user_id_created_at")
