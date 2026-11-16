"""Epica 1: nucleo de datos viento andino (FingeringChart, instrumento, soplo, centesimas)

Revision ID: a7d1e2f3b4c5
Revises: f8a9b0c1d2e3
Create Date: 2026-11-16 00:00:00.000000
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = 'a7d1e2f3b4c5'
down_revision: Union[str, None] = 'f8a9b0c1d2e3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1) Nueva tabla de digitaciones (FingeringChart)
    op.create_table(
        'fingering_charts',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('instrument', sa.String(length=20), nullable=False),
        sa.Column('pitch', sa.String(length=10), nullable=False),
        sa.Column('holes', postgresql.JSON(), nullable=False),
        sa.Column('alternate_fingerings', postgresql.JSON(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint('instrument', 'pitch', name='uq_fingering_instrument_pitch'),
    )
    op.create_index('ix_fingering_charts_instrument', 'fingering_charts', ['instrument'])

    # 2) users: instrumento principal/secundarios, perfil de soplo, embocadura
    op.add_column('users', sa.Column('primary_instrument', sa.String(length=20), nullable=True))
    op.add_column('users', sa.Column('secondary_instruments', postgresql.JSON(), nullable=True))
    op.add_column('users', sa.Column('breath_capacity_profile', postgresql.JSON(), nullable=True))
    op.add_column('users', sa.Column('embouchure_level', sa.String(length=20), nullable=True))

    # 3) lessons: instrumento, marcas de respiracion, articulacion
    op.add_column('lessons', sa.Column('instrument', sa.String(length=20),
                                       nullable=False, server_default='quena'))
    op.add_column('lessons', sa.Column('breath_marks', postgresql.JSON(), nullable=True))
    op.add_column('lessons', sa.Column('articulation_patterns', postgresql.JSON(), nullable=True))
    op.create_index('ix_lessons_instrument', 'lessons', ['instrument'])

    # 4) note_sequences: quitar piano (finger/hand/is_chord/chord_group),
    #    anadir viento (breath_mark/articulation/fingering_chart_id)
    op.add_column('note_sequences', sa.Column('breath_mark', sa.Boolean(),
                                              nullable=False, server_default=sa.false()))
    op.add_column('note_sequences', sa.Column('articulation', sa.String(length=20), nullable=True))
    op.add_column('note_sequences', sa.Column('fingering_chart_id',
                                              postgresql.UUID(as_uuid=True), nullable=True))
    op.create_foreign_key(
        'fk_note_sequences_fingering_chart', 'note_sequences', 'fingering_charts',
        ['fingering_chart_id'], ['id'], ondelete='SET NULL',
    )
    op.drop_column('note_sequences', 'finger')
    op.drop_column('note_sequences', 'hand')
    op.drop_column('note_sequences', 'is_chord')
    op.drop_column('note_sequences', 'chord_group')

    # 5) practice_sessions: metricas de viento (centesimas, soplo, postura, instrumento)
    op.add_column('practice_sessions', sa.Column('cents_deviation_avg', sa.Float(), nullable=True))
    op.add_column('practice_sessions', sa.Column('breath_control_score', sa.Float(), nullable=True))
    op.add_column('practice_sessions', sa.Column('posture_score', sa.Float(), nullable=True))
    op.add_column('practice_sessions', sa.Column('instrument_used', sa.String(length=20), nullable=True))


def downgrade() -> None:
    op.drop_column('practice_sessions', 'instrument_used')
    op.drop_column('practice_sessions', 'posture_score')
    op.drop_column('practice_sessions', 'breath_control_score')
    op.drop_column('practice_sessions', 'cents_deviation_avg')

    op.add_column('note_sequences', sa.Column('chord_group', sa.Integer(), nullable=True))
    op.add_column('note_sequences', sa.Column('is_chord', sa.Boolean(),
                                              nullable=False, server_default=sa.false()))
    op.add_column('note_sequences', sa.Column('hand', sa.String(length=10), nullable=True))
    op.add_column('note_sequences', sa.Column('finger', sa.Integer(), nullable=True))
    op.drop_constraint('fk_note_sequences_fingering_chart', 'note_sequences', type_='foreignkey')
    op.drop_column('note_sequences', 'fingering_chart_id')
    op.drop_column('note_sequences', 'articulation')
    op.drop_column('note_sequences', 'breath_mark')

    op.drop_index('ix_lessons_instrument', table_name='lessons')
    op.drop_column('lessons', 'articulation_patterns')
    op.drop_column('lessons', 'breath_marks')
    op.drop_column('lessons', 'instrument')

    op.drop_column('users', 'embouchure_level')
    op.drop_column('users', 'breath_capacity_profile')
    op.drop_column('users', 'secondary_instruments')
    op.drop_column('users', 'primary_instrument')

    op.drop_index('ix_fingering_charts_instrument', table_name='fingering_charts')
    op.drop_table('fingering_charts')
