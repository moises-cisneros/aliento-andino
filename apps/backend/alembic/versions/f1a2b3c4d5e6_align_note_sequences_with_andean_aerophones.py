"""align note_sequences with andean aerophones

- Drop polyphonic columns from note_sequences: finger, hand, is_chord, chord_group
- Add aerophone columns to note_sequences:
  * breath_mark (Boolean, NOT NULL, default=False)
  * fingering_id (UUID FK to fingerings.id, nullable=True)
  * fingering_data (JSON/JSONB, nullable=True)
- Add index ix_note_sequences_fingering_id on note_sequences(fingering_id)

Revision ID: f1a2b3c4d5e6
Revises: e5f6a7b8c9d0
Create Date: 2026-11-18
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = "f1a2b3c4d5e6"
down_revision: Union[str, None] = "e5f6a7b8c9d0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _insp() -> sa.Inspector:
    return sa.inspect(op.get_bind())


def _columns(insp: sa.Inspector, table: str) -> dict:
    if not insp.has_table(table):
        return {}
    return {c["name"]: c for c in insp.get_columns(table)}


def _indexes(insp: sa.Inspector, table: str) -> dict:
    if not insp.has_table(table):
        return {}
    return {i["name"]: i for i in insp.get_indexes(table)}


def upgrade() -> None:
    insp = _insp()
    cols = _columns(insp, "note_sequences")
    if not cols:
        return

    # 1. Eliminar columnas polifónicas heredadas si existen
    for poly_col in ("finger", "hand", "is_chord", "chord_group"):
        if poly_col in cols:
            op.drop_column("note_sequences", poly_col)

    # Re-inspeccionar columnas
    cols = _columns(_insp(), "note_sequences")

    # 2. Agregar breath_mark (respiración / corte de fraseo para vientos)
    if "breath_mark" not in cols:
        op.add_column(
            "note_sequences",
            sa.Column(
                "breath_mark",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("false"),
            ),
        )

    # 3. Agregar fingering_id (FK opcional al catálogo oficial de digitaciones)
    if "fingering_id" not in cols:
        op.add_column(
            "note_sequences",
            sa.Column(
                "fingering_id",
                UUID(as_uuid=True),
                sa.ForeignKey("fingerings.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )

    # 4. Crear índice para fingering_id
    idxs = _indexes(_insp(), "note_sequences")
    if "ix_note_sequences_fingering_id" not in idxs:
        op.create_index(
            "ix_note_sequences_fingering_id",
            "note_sequences",
            ["fingering_id"],
            unique=False,
        )

    # 5. Agregar fingering_data (JSON / JSONB con estado de orificios/tubos)
    if "fingering_data" not in cols:
        json_type = JSONB().with_variant(sa.JSON(), "sqlite")
        op.add_column(
            "note_sequences",
            sa.Column(
                "fingering_data",
                json_type,
                nullable=True,
            ),
        )


def downgrade() -> None:
    insp = _insp()
    cols = _columns(insp, "note_sequences")
    if not cols:
        return

    idxs = _indexes(insp, "note_sequences")
    if "ix_note_sequences_fingering_id" in idxs:
        op.drop_index("ix_note_sequences_fingering_id", table_name="note_sequences")

    if "fingering_data" in cols:
        op.drop_column("note_sequences", "fingering_data")

    if "fingering_id" in cols:
        op.drop_column("note_sequences", "fingering_id")

    if "breath_mark" in cols:
        op.drop_column("note_sequences", "breath_mark")

    # Reintegrar columnas previas si faltan
    cols = _columns(_insp(), "note_sequences")
    if "finger" not in cols:
        op.add_column("note_sequences", sa.Column("finger", sa.Integer(), nullable=True))
    if "hand" not in cols:
        op.add_column("note_sequences", sa.Column("hand", sa.String(length=10), nullable=True))
    if "is_chord" not in cols:
        op.add_column(
            "note_sequences",
            sa.Column("is_chord", sa.Boolean(), nullable=True, server_default=sa.text("false")),
        )
    if "chord_group" not in cols:
        op.add_column("note_sequences", sa.Column("chord_group", sa.Integer(), nullable=True))
