# Qué rescatar del documento SW1-2025 ("MelodyPath") para Aliento Andino

**Fuente:** `D:\Universidad\SW1S12025\Documentacion de sw1final .docx` (PAPS + Perfil + Sprints de *MelodyPath*, una app de aprendizaje musical multi-instrumento: piano, guitarra, batería, canto).
**Destino:** `Aliento_Andino_Documento_Guia.docx` (nuestro documento base).
**Fecha:** 2026-11-16

## Idea clave
El documento 2025 es del **mismo dominio** (tutor musical con lecciones, ejercicios, evaluación, gamificación, comunidad e IA), así que su **estructura y secciones** se reutilizan casi al 100%. Solo hay que:
1. Cambiar los instrumentos: **piano/guitarra/batería/canto → quena, zampoña/siku, tarka y flauta**.
2. Cambiar el nombre: **MelodyPath → Aliento Andino**.
3. Añadir lo **diferencial** de Aliento Andino: evaluación **100% on-device**, afinación en **centésimas**, **postura/sujeción** por visión, calibración **"Soplo Suave"** y **tutor SLM local**.
4. Alinear el **stack** al real de Aliento Andino (Angular + Flutter + FastAPI + PostgreSQL), no al de MelodyPath (Next.js).

---

## Tabla de rescate (qué tomar, a dónde va, esfuerzo)

| # | Sección en MelodyPath (2025) | ¿Nuestro guía lo tiene? | Acción | Tipo | Prioridad |
|---|---|---|---|---|---|
| 1 | **Marco referencial / teórico** (2.1) y **Fundamentación teórica / Antecedentes** (Perfil 1.2) | ❌ No | **Rescatar** y adaptar al contexto andino (preservación cultural, música tradicional) | Texto | 🔴 Alta |
| 2 | **Alcance por módulos** (1.5: usuarios, instrumentos, lecciones, ejercicios, evaluaciones, gamificación, progreso, comunidad, IA) | 🟡 Parcial (lo tenemos como HU) | **Rescatar** el formato "Objetivo + Funcionalidades" como sección de Alcance; adaptar instrumentos y añadir soplo/postura/afinación | Texto | 🔴 Alta |
| 3 | **Elementos del sistema basado en computadoras** (1.6: Hardware, Software, Datos, Procesos, Gente, Documento) | ❌ No | **Rescatar** la estructura; adaptar stack (Next.js→Angular/Flutter, añadir MediaPipe/SLM on-device, micrófono+cámara) | Texto | 🔴 Alta |
| 4 | **Herramientas tecnológicas** (3: lenguajes, BD PostgreSQL, **Modelo C4**, Enterprise Architect, IaaS) | ❌ No (solo mención en 1.1.5) | **Rescatar** y ajustar a nuestro stack real; PostgreSQL y C4/EA se mantienen | Texto | 🔴 Alta |
| 5 | **Diagramas UML**: Modelo de **Contexto (C4)**, **Despliegue**, **Paquetes (capas)**, **Clases**, **Secuencia** (en los Sprints) | ❌ No | **Rehacer en Enterprise Architect** adaptados a la arquitectura de Aliento Andino. **Lo más valioso para empezar a desarrollar.** | Diagrama (imagen) | 🔴 Alta |
| 6 | **Scrum TaskBoard** (Backlog/To-Do/Doing/Done), **Burndown/BurnUp**, **Gráfica de Esfuerzo** | 🟡 Parcial (tenemos burndown) | Rescatar el formato de TaskBoard si lo piden | Diagrama | 🟡 Media |
| 7 | **Modelo de contexto** (4.1.7) y **criterios de calidad** (4.1.8) | 🟡 Parcial | Comparar y tomar lo que falte | Texto/Diagrama | 🟡 Media |
| 8 | Métricas, Estimación (VE/COCOMO/Planning Poker/Putnam), Riesgos, Recursos, Organización, Seguimiento | ✅ Sí (ya adaptado, con repos medidos) | **No rescatar** — el nuestro ya es específico de Aliento Andino | — | ⚪ Omitir |
| 9 | Sprints, Product Backlog, Historias de Usuario, Daily/Review/Retro | ✅ Sí (ya adaptado a viento) | **No rescatar** — redundante | — | ⚪ Omitir |

---

## Lo que MÁS sirve para "meterle al desarrollo"
En orden de utilidad directa para empezar a programar:

1. **Diagrama de Clases / Modelo de Datos** (#5). Es el puente directo a la **Épica 1 del backend**: define `User`, `Lesson`, `NoteSequence`, y el nuevo `FingeringChart`. Rehacerlo adaptado a Aliento Andino (sin acordes/manos; con `instrument`, `breath_marks`, `fingering_chart_id`, perfil de soplo) te deja listo para implementar los modelos SQLAlchemy.
2. **Diagrama de Despliegue + Paquetes/Capas** (#5). Fija la arquitectura: app Flutter (móvil) + Angular (web admin) + FastAPI (backend) + PostgreSQL, con la inferencia IA **on-device** (MediaPipe/SPICE/SLM) separada del backend.
3. **Diagrama de Contexto (C4 nivel 1)** (#5). Quién usa el sistema (estudiante, docente/admin) y con qué servicios habla (todo local para IA; backend solo para auth/social/contenido).
4. **Elementos del sistema (HW/SW)** (#3) y **Herramientas tecnológicas** (#4). Dejan documentado el stack y los requisitos de hardware (micrófono, cámara, GPU para MediaPipe).

> **Nota sobre diagramas:** en el documento 2025 son **imágenes** (hechas en Enterprise Architect). No se pueden "copiar" como texto; hay que **rehacerlos** adaptados a Aliento Andino. Como ya usan Enterprise Architect (y está disponible en esta sesión), puedo ayudarte a **definir el contenido exacto de cada diagrama** (entidades, relaciones, contenedores, nodos) para que los dibujen rápido.

---

## Plan sugerido para cerrar el documento base y arrancar
1. **Añadir al guía de Aliento Andino** (texto, lo puedo hacer): Marco teórico/antecedentes (#1), Alcance por módulos (#2), Elementos del sistema (#3) y Herramientas/stack (#4), todo adaptado a viento andino y on-device.
2. **Definir los diagramas UML** (#5) adaptados — empezando por el **modelo de datos** (clases) porque habilita la Épica 1.
3. Con el modelo de datos listo → **empezar la Épica 1 del backend** (modelos `Lesson`/`NoteSequence`/`FingeringChart` + migración Alembic + seeders de digitaciones).

Dime por cuál de los puntos (1, 2 o 3) quieres que empiece y lo hacemos.
