"""add fingerings table

Revision ID: b3c4d5e6f7a8
Revises: a2b3c4d5e6f7
Create Date: 2026-11-17 06:30:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSON

revision: str = "b3c4d5e6f7a8"
down_revision: Union[str, None] = "a2b3c4d5e6f7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "fingerings",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("instrument", sa.String(length=20), nullable=False),
        sa.Column("note", sa.String(length=10), nullable=False),
        sa.Column("octave", sa.Integer(), nullable=False),
        sa.Column("holes_covered", JSON(), nullable=False),
        sa.Column("is_alternate", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_fingerings_instrument",
        "fingerings",
        ["instrument"],
        unique=False,
    )
    op.create_index(
        "ix_fingerings_instrument_note_octave",
        "fingerings",
        ["instrument", "note", "octave"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_fingerings_instrument_note_octave", table_name="fingerings")
    op.drop_index("ix_fingerings_instrument", table_name="fingerings")
    op.drop_table("fingerings")
