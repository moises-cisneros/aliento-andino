"""add client_id to practice_sessions for offline idempotency

Permite deduplicar envíos de práctica reintentados desde el cliente (sync
offline). Nullable + índice único: los NULL no chocan en Postgres, así que las
sesiones online sin client_id conviven con las offline deduplicadas.

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-06-19
"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "practice_sessions",
        sa.Column("client_id", sa.String(length=36), nullable=True),
    )
    op.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS ix_practice_sessions_client_id "
        "ON practice_sessions (client_id)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_practice_sessions_client_id")
    op.drop_column("practice_sessions", "client_id")
