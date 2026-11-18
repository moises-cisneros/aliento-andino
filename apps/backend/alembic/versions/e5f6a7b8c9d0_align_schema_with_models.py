"""align migrated schema with Base.metadata

- lessons.instrument (+ ix_lessons_instrument)
- created_at NOT NULL en comment_likes, hashtags, post_hashtags, saved_posts
- user_xp: ix_user_xp_user_id unico y sin constraint unico redundante;
  ix_user_xp_total_xp se conserva (lo usan los rankings) y se crea si falta,
  el modelo declara index=True en total_xp

Cada operacion inspecciona primero el esquema y se omite si ya esta aplicada,
de modo que es segura en bases creadas con create_all o a mano. El downgrade
solo revierte cambios inocuos (nulabilidad, indices de user_xp); no elimina
lessons.instrument ni su indice porque pudieron existir antes de esta revision
y la columna puede contener datos.

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-11-18
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e5f6a7b8c9d0"
down_revision: Union[str, None] = "d4e5f6a7b8c9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_CREATED_AT_TABLES = ("comment_likes", "hashtags", "post_hashtags", "saved_posts")


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
    # --- lessons.instrument ---
    insp = _insp()
    cols = _columns(insp, "lessons")
    if cols:
        if "instrument" not in cols:
            op.add_column(
                "lessons",
                sa.Column(
                    "instrument",
                    sa.String(length=20),
                    nullable=False,
                    server_default="quena",
                ),
            )
        if "ix_lessons_instrument" not in _indexes(_insp(), "lessons"):
            op.create_index("ix_lessons_instrument", "lessons", ["instrument"])

    # --- created_at NOT NULL (se rellenan NULL antes de endurecer) ---
    for table in _CREATED_AT_TABLES:
        col = _columns(_insp(), table).get("created_at")
        if col is not None and col["nullable"]:
            op.execute(sa.text(f"UPDATE {table} SET created_at = now() WHERE created_at IS NULL"))
            op.alter_column(
                table,
                "created_at",
                existing_type=sa.DateTime(timezone=True),
                nullable=False,
            )

    # --- user_xp: indices ---
    insp = _insp()
    if insp.has_table("user_xp"):
        idx = _indexes(insp, "user_xp")
        if "ix_user_xp_total_xp" not in idx:
            op.create_index("ix_user_xp_total_xp", "user_xp", ["total_xp"])
        current = idx.get("ix_user_xp_user_id")
        if current is not None and not current.get("unique"):
            op.drop_index("ix_user_xp_user_id", table_name="user_xp")
            current = None
        if current is None:
            op.create_index("ix_user_xp_user_id", "user_xp", ["user_id"], unique=True)
        for uc in _insp().get_unique_constraints("user_xp"):
            if uc["column_names"] == ["user_id"] and uc.get("name"):
                op.drop_constraint(uc["name"], "user_xp", type_="unique")


def downgrade() -> None:
    # user_xp vuelve a la forma previa: constraint unico + indice no unico en user_id.
    insp = _insp()
    if insp.has_table("user_xp"):
        has_uc = any(
            uc["column_names"] == ["user_id"] for uc in insp.get_unique_constraints("user_xp")
        )
        idx = _indexes(insp, "user_xp")
        if "ix_user_xp_user_id" in idx and idx["ix_user_xp_user_id"].get("unique"):
            op.drop_index("ix_user_xp_user_id", table_name="user_xp")
            if not has_uc:
                op.create_unique_constraint("user_xp_user_id_key", "user_xp", ["user_id"])
            op.create_index("ix_user_xp_user_id", "user_xp", ["user_id"])

    for table in _CREATED_AT_TABLES:
        col = _columns(_insp(), table).get("created_at")
        if col is not None and not col["nullable"]:
            op.alter_column(
                table,
                "created_at",
                existing_type=sa.DateTime(timezone=True),
                nullable=True,
            )
