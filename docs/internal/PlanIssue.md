# PlanIssue — Checklist de Issues del Proyecto

> Sincronizado con el issue #153 (DOCS-SYNC · Sprint 3).
> Última actualización contra `main` en `32f690a`.

## Sprint 0 — Fundacionales

- [x] #1 — Configuración inicial del monorepo
- [x] #2 — Docker compose base
- [x] #3 — CI básico

## Sprint 1 — Onboarding y prácticas

- [x] #20 — API de lecciones
- [x] #21 — Catálogo de lecciones móvil
- [x] #23 — Formulario reactivo de lecciones web
- [x] #34 — Modelo de sesión de práctica
- [x] #35 — POST /practice/session idempotente
- [x] #37 — Historial de prácticas móvil
- [x] #38 — GET /practice/history
- [x] #40 — Paginación por cursor para feed social en backend
- [x] #41 — Feed social móvil
- [x] #43 — Consulta Agrupada por XP Semanal y Filtros por Instrumento (SUB-12-A)
- [x] #44 — Tabs de Leaderboard y Podio Animado en Móvil (SUB-12-B)
- [x] #46 — Contrato de racha e insignias
- [x] #47 — Vitrina de insignias andinas
- [x] #55 — Catálogo de digitaciones web
- [x] #59 — Descarga offline de lecciones
- [x] #62 — Pantalla de perfil
- [x] #63 — PUT /users/me

## Sprint 2 — Calidad y refactor

- [x] #65 — Servicio de notificaciones locales y alertas de racha en Flutter
- [x] #70 — Calibración de soplo
- [x] #71 — Widget de Quena
- [x] #72 — Widget de Zampoña
- [x] #75 — Widget de Tarka
- [x] #76 — Auto-close de HUs padre
- [x] #77 — Outbox offline
- [x] #78 — XP en sesión
- [x] #79 — Ruff limpio
- [x] #80 — SLM on-device
- [x] #81 — Telemetría a prompt pedagógico
- [x] #82 — API v1 lecciones
- [x] #83 — Lint Angular
- [x] #84 — Catálogo tabs móvil
- [x] #85 — MediaPipe Pose
- [x] #86 — Cambio dinámico de instrumento
- [x] #87 — Preferencias y calibración
- [x] #88 — Pantalla de perfil
- [x] #89 — Formulario de lecciones andinas
- [x] #91 — Persistencia offline
- [x] #93 — Historial de prácticas backend
- [x] #94 — Historial móvil
- [x] #95 — Worktree obligatorio
- [x] #96 — Cobertura mobile ≥75%
- [x] #97 — Cobertura en CI
- [x] #98 — Racha e insignias backend
- [x] #99 — Vitrina de insignias
- [x] #100 — MediaPipe Hands
- [x] #101 — Overlay de oclusión
- [x] #102 — POST /posts/{id}/react
- [x] #103 — Recordatorio diario API
- [x] #104 — Guías por instrumento
- [x] #105 — Test bandeja de moderación
- [x] #106 — Analítica backend
- [x] #107 — Dashboard web

## Sprint 3 — Red social, gamificación, wiki y despliegue

- [x] #108 — XP semanal backend
- [x] #110 — Tabs leaderboard móvil
- [x] #111 — Nginx SSL
- [x] #112 — E2E smoke
- [x] #113 — Limitar prompts al dominio andino
- [x] #114 — Instrument restringido al dominio andino
- [x] #115 — Retirar detector de acordes de contenido no andino
- [x] #116 — Recordatorios completos
- [x] #117 — Feed social con aplausos, audio preview y nomenclatura
- [x] #118 — Reintento con backoff ante AudioHardwareException
- [x] #119 — Tests de modelos y ciclo de migraciones Alembic
- [x] #120 — Tests del servicio y latencia real en server.py
- [x] #121 — Publicar modelo C4 como página del portal Docusaurus
- [x] #122 — Guarda de CI para exigir Closes por sub-issue
- [x] #74 — Sincronización de dependencias y etiquetas con GitHub Issues (correctiva docs)
- [x] #123 — Retirar detector de acordes de contenido no andino (correctiva)
- [x] #124 — Guarda de CI para exigir Closes por sub-issue (correctiva)
- [x] #126 — Tests del servicio y latencia real en server.py (correctiva)
- [x] #127 — Restringir Instrument al dominio andino (correctiva)
- [x] #128 — Reintento con backoff ante AudioHardwareException (correctiva)
- [x] #129 — Publicar modelo C4 como página del portal Docusaurus (correctiva)
- [x] #130 — Limitar prompts, tutor y notificaciones al dominio andino (correctiva)
- [x] #131 — Unificar heads de Alembic y alinear esquema con los modelos
- [x] #132 — Feed social con aplausos, audio preview y nomenclatura (correctiva)
- [x] #133 — Recordatorios completos: alerta nocturna, permisos (correctiva)
- [x] #134 — Unificar heads de Alembic y alinear esquema (correctiva)
- [x] #135 — Tests de modelos y ciclo de migraciones Alembic (correctiva)
- [x] #142 — Catálogo curricular andino y filtro por instrumento
- [x] #143 — Selector de instrumento mobile
- [x] #144 — Catálogo curricular andino (SUB-142, correctiva)
- [x] #145 — Reemplazar iconopiano por logo andino
- [x] #146 — Purgar restos de piano en mobile
- [x] #147 — Alternancia de instrumentos LessonsBloc
- [x] #148 — Alinear NoteSequence con aerófonos andinos y semillero de digitaciones
- [x] #149 — Unificar InstrumentType y corregir modelos acústicos
- [x] #154 — Alinear NoteSequence con aerófonos andinos (correctiva)
- [x] #155 — Unificar InstrumentType y corregir modelos acústicos (correctiva)

## Pendientes (abiertas)

- [ ] #136 — Tracking E2E claves/hardware
- [ ] #137 — Google Sign-In producción
- [ ] #138 — SMTP real
- [ ] #139 — Cámara 60 FPS MediaPipe
- [ ] #140 — Latencia YIN <50ms
- [ ] #141 — Racha 3 días reloj
- [ ] #150 — Digitaciones en cascada
- [ ] #151 — Editor notas docente
- [ ] #152 — Tutor pedagógico andino
- [ ] #153 — DOCS-SYNC (este issue)

## Pendientes de verificar

Los issues #123–#135, #144, #154 y #155 son issues correctivas (par principal + número de seguimiento en el mismo commit).
Sus títulos se infirieron desde los mensajes de commit en `git log --oneline --all` contra `32f690a`.
Se recomienda confirmar los títulos exactos en el panel de GitHub/milestone para las issues correctivas que comparten nombre con su par principal.

**Reporte:** 90 marcadas [x] · 10 abiertas [ ] · 0 movidas a Pendientes (títulos inferidos desde commits, no inventados).
