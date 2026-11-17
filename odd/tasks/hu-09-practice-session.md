# Feature: HU-09 Evaluación Integral de Sesión de Práctica y Telemetría Compacta

Parent Issue: #33 | Sprint 2 | Delivery: one branch + PR per sub-issue (SUB-09-A #34 → SUB-09-B #35), ask-on-risk
Test runners: Flutter (`flutter test`), Backend (`pytest`)

## Specs

S1: "Ponderación configurable: Afinación 50%, Ritmo 30%, Postura 20%."
S2: "Serialización de la sesión en un paquete JSON liviano (<5 KB)."
S3: "Sincronización con el endpoint `/api/v1/practice/session` con soporte para reintento offline y `client_id` idempotente."
S4: "Clase: `PracticeSessionModel`, Método: `Map<String, dynamic> toJson()`, Campos: `lesson_id`, `client_id`, `score`, `correct_notes`, `total_notes`, `wrong_notes`, `missed_notes`, `average_tempo`, `total_time_seconds`, `errors_detail`."
S5: "Dispositivo sin conexión: Guardar en base de datos Drift SQLite local con flag `is_synced = false`."
S6: "Endpoint: `POST /api/v1/practice/session`, Schema de entrada: `PracticeSubmitRequest`, Schema de salida: `PracticeSessionResponse`, Método en servicio: `PracticeService.submit_practice_session(db, user_id, request: PracticeSubmitRequest)`"
S7: "Petición repetida con el mismo `client_id`: Retornar la sesión existente sin sumar XP duplicado (HTTP 200 idempotente)."
S8: "Score fuera de rango (<0 o >100): HTTP `422 Unprocessable Entity`."
S9: "Recibir el resultado en FastAPI, validar schema Pydantic, evitar duplicación por `client_id`, persistir en PostgreSQL y actualizar XP y racha del usuario en una sola transacción asíncrona."

Assumption: legacy `POST /api/practice/submit` stays working (no breaking change); the new endpoint coexists.

## Tasks

- [ ] T1 (S1-S5) [inline]: Mobile — `PracticeSessionModel` + weighted score + `PracticeSessionRepository` + Drift `is_synced` + sync to new endpoint. (#34 SUB-09-A) — Branch `feat/34-practice-session-serializer`
- [ ] T2 (S6-S9) [inline]: Backend — `POST /api/v1/practice/session`, `PracticeService.submit_practice_session`, tests. (#35 SUB-09-B) — Branch `feat/35-practice-session-endpoint`

## Log

L1: "Implementa las subissues de la issue #33 (HU-09), realizalo con ODD, en un propio git worktree."
L2: "Actualiza a como esta definido en los issues y continualos"
