# Feature: HU-19 Gestión de Perfil de Usuario y Calibración Respiratoria

Parent Issue: #61 | Sprint 2 | Delivery: one branch + PR per sub-issue (SUB-19-B #63, SUB-19-A #62)
Test runners: Python (`pytest tests/test_users.py -v`, `ruff check .`), Flutter (`flutter test`, `flutter analyze`)

## Specs

S1: "Como usuario de Aliento Andino, quiero editar mi información de perfil, instrumento(s) preferidos y consultar/reajustar mi perfil de calibración respiratoria, para personalizar mi experiencia de estudio y sincronizar la sensibilidad del evaluador con mi capacidad física."
S2: "Pantalla de edición de datos personales, avatar e instrumentos de interés (Quena, Zampoña, Tarka)."
S3: "Visualización del umbral de soplo calibrado con opción de iniciar una nueva sesión de calibración (\"Soplo Suave\")."
S4: "Endpoint `PUT /api/v1/users/me` que persiste y sincroniza las preferencias entre dispositivos."
S5: "Endpoint en FastAPI para actualizar datos de perfil, preferencias de instrumento y umbrales de soplo basal. Archivos a crear o modificar: `apps/backend/app/routers/users.py`, `apps/backend/app/schemas/user.py`, `apps/backend/tests/test_users.py`."
S6: "Contratos Técnicos Backend: Endpoint: `PUT /api/v1/users/me`, Schema: `UserUpdate(full_name, avatar_url, preferred_instruments, breath_sensitivity_rms)`. Manejo de Errores: Valores de RMS inválidos (<0 o >1): HTTP `422 Unprocessable Entity`."
S7: "Pruebas Obligatorias Backend: Unitaria: Test de validación Pydantic para `UserUpdate`. Integración: Test de actualización de datos en base de datos PostgreSQL. E2E: Llamada autenticada con Bearer token verificando respuesta HTTP 200."
S8: "Interfaz móvil con formulario de edición de datos, selector de instrumentos favoritos y tarjeta de estado de calibración de soplo con botón de re-calibración. Archivos a crear o modificar: `apps/mobile/lib/features/profile/presentation/screens/profile_edit_screen.dart`, `apps/mobile/lib/features/profile/presentation/widgets/breath_profile_card.dart`."
S9: "Contratos Técnicos Móvil: Widget: `ProfileEditScreen`, Widget: `BreathProfileCard(double rmsThreshold, DateTime lastCalibrated)`. Manejo de Errores: Error al guardar cambios en red: Persistir localmente en SQLite y marcar para sincronización en background."
S10: "Pruebas Obligatorias Móvil: Unitaria: Validación de formulario de edición de perfil. Integración: Test de widget interactuando con el BLoC de perfil. E2E: Edición de apodo y verificación de actualización inmediata en UI."

## Tasks

- [x] T1 (S4, S5, S6, S7) [inline]: Backend — `PUT /api/v1/users/me`, schema `UserUpdate` con validación de instrumentos andinos y umbral RMS [0.0, 1.0], migración de columnas en `users`, y tests unitario/integración/E2E (#63 SUB-19-B) — Branch `feat/63-put-users-me`
- [x] T2 (S1, S2, S3, S8, S9, S10) [inline]: Mobile — `ProfileEditScreen`, `BreathProfileCard`, selector de instrumentos preferidos (Quena, Zampoña, Tarka), integración con BLoC de perfil, persistencia offline, tests unitario, integración y E2E (#62 SUB-19-A) — Branch `feat/62-profile-screen-mobile`

## Log

L1: "Implementa las subissues de la issue #63 (HU-19), realizalo con ODD, en un propio git worktree."
L2: Verification backend SUB-19-B: `pytest tests/test_users.py -v` (19 passed, 0 failures), `ruff check .` (0 errors), `ruff format --check .` (clean). PR #87 merged to main (fb50772).
L3: Verification mobile SUB-19-A: `flutter test test/features/profile/` (6 passed, 100% green), `flutter analyze` (0 errors, 0 warnings), `dart format` (clean). Ready for PR and closure of #62 and HU-19 #61.
