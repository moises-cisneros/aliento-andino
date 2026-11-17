# Feature: HU-05 Panel Web Docente: Creación de Lecciones y Catálogo Oficial de Digitaciones

Parent Issue: #22 | Sprint 1 | Delivery: one branch + PR per sub-issue (SUB-05-A #23 → SUB-05-B #55)
Test runners: Angular Web (`ng test`), Backend (`pytest`)

## Specs

S1: "Vista web con editor interactivo de notas musicales (notación científica, duración y digitación con marcas de respiración), validación de formulario reactivo y guardado vía API REST."
S2: "Archivos a crear o modificar: `apps/web/src/app/features/lessons/lesson-form-dialog/lesson-form-dialog.component.ts`, `apps/web/src/app/core/services/lesson-admin.service.ts`, `apps/web/src/app/core/models/lesson.model.ts`, `apps/web/src/app/features/lessons/lesson-list/lesson-list.component.ts`."
S3: "Contratos Técnicos: Servicio Angular: `LessonAdminService`, Método: `createLesson(data: LessonCreate): Observable<Lesson>`, Método: `updateLesson(id: string, data: LessonUpdate): Observable<Lesson>`, Modelo TypeScript: `LessonCreate` con campo `notes: NoteSequenceCreate[]`."
S4: "Manejo de Errores: Intento de enviar lección sin notas: Botón de guardado deshabilitado y mensaje de validación 'Debe agregar al menos una nota musical a la secuencia'. Error 401/403 de API: Toast de error notificando falta de privilegios administrativos."
S5: "Pruebas Obligatorias: Unitaria: `apps/web/src/app/features/lessons/lesson-form-dialog/lesson-form-dialog.component.spec.ts` validando validadores del formulario. Integración: Test de servicio `LessonAdminService` con `HttpClientTestingModule` interceptando `POST /api/v1/lessons`. E2E: Creación de una lección completa desde el panel administrativo web. Suites de pruebas pasando con 0 errores y cobertura mínima requerida."
S6: "Módulo administrativo en Angular 21 para registrar gráficamente el catálogo de digitaciones por instrumento y nota (orificios/tubos a cubrir, digitaciones alternas) con validación de unicidad en backend."
S7: "Archivos a crear o modificar: `apps/web/src/app/features/fingerings/fingering-catalog/fingering-catalog.component.ts`, `apps/web/src/app/core/services/fingering-admin.service.ts`, `apps/backend/app/routers/fingerings.py`, `apps/backend/app/schemas/fingering.py`."
S8: "Contratos Técnicos: Endpoint: `POST /api/v1/fingerings` con schema `FingeringCreate(instrument, note, octave, holes_covered, is_alternate)`, Endpoint: `GET /api/v1/fingerings?instrument={instrument}`, Validación de unicidad: No pueden existir dos digitaciones principales para la misma nota e instrumento."
S9: "Manejo de Errores: Conflicto de digitación duplicada: HTTP `409 Conflict` con detalle 'Digitación principal ya registrada para esta nota'."
S10: "Pruebas Obligatorias: Unitaria: Prueba de esquema Pydantic validando array de orificios/tubos. Integración: Test en Angular con formulario visual de orificios de Quena/Tarka. E2E: Alta de una nueva digitación alterna en el panel administrativo. Suites de pruebas pasando con 0 errores y cobertura mínima requerida."

## Tasks

- [ ] T1 (S1-S5) [inline]: Web — `LessonAdminService` (createLesson, updateLesson), `lesson-form-dialog.component.ts` (reactive form, note sequence editor with breath marks, validation, error handling), `lesson-list.component.ts` integration, and unit/integration/e2e tests (#23 SUB-05-A) — Branch `feat/23-angular-score-sequence-form`
- [ ] T2 (S6-S10) [inline]: Backend & Web — Backend model, schema, service, router `POST/GET /api/v1/fingerings` with 409 conflict on duplicate primary fingering, and Web `FingeringAdminService`, `FingeringCatalogComponent` (graphical Andean fingering editor for Quena/Tarka/Zampoña), routing and tests (#55 SUB-05-B) — Branch `feat/55-fingering-catalog-editor`

## Log

L1: "Implementa las subissues de la issue #22 (HU-05), realizalo con ODD, en un propio git worktree."
