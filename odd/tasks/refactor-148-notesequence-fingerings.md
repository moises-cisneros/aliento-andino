# Feature: [REFACTOR-BACKEND] Alinear modelo NoteSequence con aerófonos andinos, corregir omisión de instrument en detalle y semillero de digitaciones

Issue: #148 | Sprint 3 | Delivery: one branch + PR (refactor/148-notesequence-fingerings-seeder)
Test runners: Backend Python (`ruff check .`, `ruff format --check .`, `pytest tests/ -v --cov=app`)

## Specs

S1: "En app/models/lesson.py y app/schemas/lesson.py, el modelo NoteSequence aun conserva campos heredados de esquemas polifonicos no aerofonos (finger de 1 a 5, hand izq/der, velocity, is_chord y chord_group), mientras que carece de breath_mark y fingering_id."
S2: "Ademas, en lesson_service.py (get_lesson_detail y get_recommended_lessons), el diccionario de respuesta omite el campo instrument, provocando que el cliente reciba quena por defecto incluso para lecciones de Zampona y Tarka."
S3: "Finalmente, la tabla fingerings esta vacia en la base de datos por falta de un semillero de digitaciones andinas."
S4: "Crear migracion Alembic que elimine de note_sequences: finger, hand, is_chord, chord_group."
S5: "Anadir a note_sequences: breath_mark (Boolean, default=False), fingering_id (UUID FK a fingerings.id, nullable=True) y fingering_data (JSONB, nullable=True)."
S6: "Actualizar modelos SQLAlchemy (app/models/lesson.py) y esquemas Pydantic (app/schemas/lesson.py)."
S7: "Corregir lesson_service.py (get_lesson_detail y get_recommended_lessons) para incluir explicitamente instrument: lesson.instrument."
S8: "En app/routers/admin_lessons.py y lesson_service.py, aceptar y aplicar filtro por parametro instrument."
S9: "Purgar textos de acordes en seed_history.py y actualizar seed_lessons.py."
S10: "Crear apps/backend/seed_fingerings.py para poblar el catalogo de digitaciones oficiales (Quena, Zampona, Tarka) e integrarlo en seed_all.py."
S11: "Actualizar tests unitarios y de integracion en tests/test_lessons.py y tests/test_fingerings.py."
S12: "Criterios de Aceptacion: GET /api/v1/lessons/{id} devuelve el instrument real de la leccion (quena, zampona, tarka). GET /admin/lessons?instrument=zampona filtra correctamente en base de datos. python seed_all.py puebla lecciones y digitaciones oficiales para los 3 instrumentos andinos. ruff check . y pytest tests/ pasan con 100% de exito y >= 80% de cobertura."

## Tasks

- [x] T1 (S4, S5, S6) [inline]: Migración Alembic f1a2b3c4d5e6 y actualización de modelos SQLAlchemy y esquemas Pydantic de NoteSequence (eliminar campos polifónicos, agregar breath_mark, fingering_id FK y fingering_data)
- [x] T2 (S2, S7, S8) [inline]: Corrección de endpoints y servicio de lecciones para incluir instrument en detalle/recomendadas y filtro por instrumento en admin
- [x] T3 (S9, S10) [inline]: Semillero de digitaciones andinas apps/backend/seed_fingerings.py e integración con seed_lessons.py, seed_history.py y seed_all.py
- [x] T4 (S11, S12) [inline]: Actualización y creación de suites de tests unitarios/integración en tests/test_lessons.py y tests/test_fingerings.py, con ruff check y pytest coverage >= 80%

## Log

L1: "De las issues que estan en el repo cual me recomiendas comenzar a realizarla? -> Recomendada Issue #148 -> Usuario autoriza: 'Si'"
L2: Verification backend: ruff check . passed (0 errors), ruff format --check . passed (113 files already formatted), pytest tests/ passed (286 passed, 1 skipped, 12 warnings).
Risk: item 1 (Alembic migration and database schema alignment for note_sequences and fingerings seeder)
