# Feature: HU-04 Catálogo Curricular y Reproductor de Lecciones Musicales

Parent Issue: #19 | Sprint 1 | Delivery: one branch + PR per sub-issue (SUB-04-A #20 → SUB-04-B #21)
Test runners: Backend (`pytest`), Flutter (`flutter test`)

## Specs

S1: "Endpoints en FastAPI para listar categorías y lecciones con sus notas serializadas, filtrables por `instrument` (`quena`, `zampona`, `tarka`) y `difficulty` (`principiante`, `intermedio`, `avanzado`)."
S2: "Contratos Técnicos: Endpoint: `GET /api/v1/lessons?instrument=quena&difficulty=principiante`, Endpoint: `GET /api/v1/lessons/{lesson_id}` -> `LessonWithNotes`, Método en servicio: `LessonService.get_lessons(db, instrument, difficulty, skip, limit) -> list[LessonListItem]`, Método en servicio: `LessonService.get_lesson_by_id(db, lesson_id) -> LessonWithNotes`."
S3: "Manejo de Errores: `lesson_id` no existente: HTTP `404 Not Found` con `{\"detail\": \"Lección no encontrada\"}`. Instrumento o dificultad inválidos: HTTP `422 Unprocessable Entity`."
S4: "Pruebas Obligatorias Backend: Unitaria: `apps/backend/tests/test_lessons.py` validando filtros y serialización de notas. Integración: Consulta HTTP asíncrona validando respuesta relacional con `note_sequences`. E2E: Flujo completo de consulta de catálogo vía REST. Suites pasando con 0 errores y cobertura mínima."
S5: "Interfaz en Flutter con catálogo filtrable por tabs de instrumentos y pantalla de práctica donde la melodía avanza compás a compás con botones táctiles ergonómicos >= 48px (52px en botones críticos) según `apps/mobile/DESIGN.md`."
S6: "Contratos Técnicos Mobile: Clase: `LessonRepository`, Método: `Future<List<LessonModel>> getLessons({required InstrumentType instrument, String? difficulty})`, Método: `Future<LessonModel> getLessonById(String lessonId)`."
S7: "Manejo de Errores Mobile: Pérdida de red: Cargar lección desde caché local SQLite si ya fue descargada; mostrar banner offline si no está en caché."
S8: "Pruebas Obligatorias Mobile: Unitaria: `apps/mobile/test/features/lessons/lesson_player_bloc_test.dart` probando eventos `StartPlayback`, `NoteEvaluated`, `PausePlayback`. Integración: Test de integración entre `LessonRepository` y `LessonPlayerBloc`. E2E: Ejecución de una lección completa desde catálogo hasta pantalla de resultados."

## Tasks

- [x] T1 (S1-S4) [inline]: Backend — `GET /api/v1/lessons` y `GET /api/v1/lessons/{lesson_id}`, `LessonService.get_lessons` y `get_lesson_by_id`, validaciones y tests (#20 SUB-04-A) — Branch `feat/20-lessons-rest-api`
- [ ] T2 (S5-S8) [inline]: Mobile — `LessonRepository` getLessons/getLessonById por InstrumentType, `LessonPlayerBloc`, `LessonListScreen` y `LessonPlayerScreen`, tests unitarios, integración y E2E (#21 SUB-04-B) — Branch `feat/21-mobile-lesson-player`

## Log

L1: "Implementa las subissues de la issue #19 (HU-04), realizalo con ODD, en un propio git worktree."
L2: Verification backend: `ruff check .` 0 errors, `ruff format --check .` clean, `pytest tests/test_lessons.py -v` 20 passed. Full suite `pytest tests/ -q` 166 passed.
