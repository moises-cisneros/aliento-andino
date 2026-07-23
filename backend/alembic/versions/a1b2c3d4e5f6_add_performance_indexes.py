"""add performance indexes on FKs and moderation queue

Agrega índices faltantes en claves foráneas muy consultadas que degradaban a
O(n) los JOIN/WHERE al escalar:
  - practice_sessions(user_id), practice_sessions(lesson_id)
  - note_sequences(lesson_id, position)
  - reports(status, created_at), reports(reporter_id), reports(reported_user_id)

Idempotente (CREATE INDEX IF NOT EXISTS) por si algún índice ya existiera.

Revision ID: a1b2c3d4e5f6
Revises: c02e33db63fc
Create Date: 2026-06-18
"""
from typing import Sequence, Union

from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "c02e33db63fc"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_INDEXES = [
    ("ix_practice_sessions_user_id", "practice_sessions", "(user_id)"),
    ("ix_practice_sessions_lesson_id", "practice_sessions", "(lesson_id)"),
    ("ix_note_sequences_lesson_position", "note_sequences", "(lesson_id, position)"),
    ("ix_reports_status_created", "reports", "(status, created_at)"),
    ("ix_reports_reporter_id", "reports", "(reporter_id)"),
    ("ix_reports_reported_user_id", "reports", "(reported_user_id)"),
]


def upgrade() -> None:
    for name, table, cols in _INDEXES:
        op.execute(f"CREATE INDEX IF NOT EXISTS {name} ON {table} {cols}")


def downgrade() -> None:
    for name, _table, _cols in _INDEXES:
        op.execute(f"DROP INDEX IF EXISTS {name}")
