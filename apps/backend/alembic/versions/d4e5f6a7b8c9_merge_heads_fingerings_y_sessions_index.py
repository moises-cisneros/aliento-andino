"""merge heads: fingerings table + practice_sessions composite index

Unifica las dos cabezas de Alembic (a3c4d5e6f7a8 y b3c4d5e6f7a8) para que
`alembic upgrade head` vuelva a funcionar. No cambia el esquema.

Revision ID: d4e5f6a7b8c9
Revises: a3c4d5e6f7a8, b3c4d5e6f7a8
Create Date: 2026-11-18
"""
from typing import Sequence, Union

revision: str = "d4e5f6a7b8c9"
down_revision: Union[str, Sequence[str], None] = ("a3c4d5e6f7a8", "b3c4d5e6f7a8")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
