# Secciones nuevas para Aliento Andino (borrador para revisión)

> Rescatadas y **adaptadas** del documento SW1-2025 (MelodyPath) al dominio de Aliento Andino:
> instrumentos de viento andinos (quena, zampoña/siku, tarka y flauta), evaluación **100% on-device**
> (afinación en centésimas, postura/sujeción, "Soplo Suave", tutor SLM local) y stack real
> (Flutter + Angular + FastAPI + PostgreSQL). Revísalas y las integramos al documento guía.

---

## A. Antecedentes

El aprendizaje de los instrumentos de viento andinos —quena, zampoña/siku, tarka y flauta— ha
dependido históricamente de la transmisión oral y de maestros presenciales, muchas veces en
contextos comunitarios. Este modelo, valioso culturalmente, está limitado por la disponibilidad de
maestros, la distancia geográfica y el costo, lo que dificulta que nuevas generaciones accedan a una
formación técnica adecuada y pone en riesgo la preservación de este patrimonio musical.

Con el avance de la tecnología han surgido afinadores, cartas de digitación y emuladores de panflauta
en tiendas móviles, pero ninguno integra en una sola plataforma la **evaluación real de la ejecución
del estudiante** (afinación en centésimas y postura) con una **guía pedagógica** y contenido
específicamente andino. Las soluciones existentes suelen ser instrumentos virtuales o afinadores
genéricos, sin retroalimentación personalizada ni seguimiento del progreso.

Por ello surge la necesidad de **Aliento Andino**: una plataforma que combine **pedagogía andina,
inteligencia artificial on-device y gamificación**, para un aprendizaje dinámico, accesible y
respetuoso de la tradición.

## B. Fundamentación teórica

- **Preservación y difusión del patrimonio musical andino.** El proyecto se apoya en la necesidad de
  documentar y transmitir las técnicas de ejecución (embocadura, digitación, soplo) de los
  instrumentos de viento andinos, acercándolas a nuevos estudiantes mediante medios digitales.
- **Aprendizaje basado en gamificación.** Elementos como niveles, rachas, logros andinos y retos
  aumentan la motivación y el compromiso del estudiante.
- **Aprendizaje autodidacta asistido por tecnología.** La plataforma permite practicar al propio
  ritmo con recursos interactivos, retroalimentación inmediata y evaluación automática.
- **Aprendizaje progresivo.** El contenido se organiza por niveles (iniciación, principiante,
  intermedio, avanzado), habilitando el avance gradual según el desempeño.
- **Evaluación multimodal inteligente y local (on-device).** Mediante procesamiento de señales de
  audio (detección de frecuencia fundamental y desviación en centésimas) y visión computacional
  (postura y sujeción), el sistema evalúa la ejecución **sin enviar audio ni video a la nube**,
  garantizando privacidad, operación offline y cero costo por alumno.

## C. Descripción del problema (resumen)

Aprender un instrumento de viento andino de forma autodidacta es, en la práctica, una experiencia
limitada por la falta de retroalimentación inmediata: el estudiante no sabe con certeza si produce la
nota correcta, si su afinación y soplo son adecuados o si su digitación y postura son las apropiadas.
A esto se suman el costo y la escasez de maestros, y la ausencia de herramientas que evalúen la
ejecución real sobre un instrumento físico y mantengan la motivación. Aliento Andino responde a esta
necesidad con evaluación acústica y visual en vivo, tutor pedagógico local y gamificación.

---

## D. Alcance por módulos

Plataforma de aprendizaje interactivo de instrumentos de viento andinos (quena, zampoña/siku, tarka y
flauta), con lecciones personalizadas por nivel, ejercicios, evaluación multimodal on-device,
gamificación y comunidad.

| Módulo | Objetivo | Funcionalidades |
|---|---|---|
| **Gestión de usuarios y acceso** | Acceso seguro y gestión de perfiles | Registro, inicio/cierre de sesión (JWT/Google OAuth), edición de perfil, selección de **instrumento principal**, nivel inicial, **perfil de calibración de soplo** |
| **Gestión de instrumentos** | Seleccionar y aprender distintos instrumentos andinos | Selección de Quena, Zampoña/Siku, Tarka y Flauta; contenido y **guía de digitación** por instrumento; cambio de instrumento activo |
| **Lecciones y tutoriales personalizados** | Contenido adaptado al nivel | Lecciones por nivel (iniciación→avanzado); rutas personalizadas según diagnóstico; contenido teórico y práctico; acceso progresivo (bloqueo/desbloqueo); repertorio folclórico andino |
| **Ejercicios interactivos** | Practicar lo aprendido | Identificación de notas, **afinación en centésimas**, ejercicios de ritmo y articulación, lectura en pentagrama con marcas de respiración, retroalimentación inmediata |
| **Evaluación multimodal** | Medir el nivel de ejecución real | **Evaluación acústica** (f₀ y desviación en centésimas, SPICE/YIN), **evaluación visual** (postura y sujeción con MediaPipe), score ponderado, resultados y retroalimentación |
| **Calibración "Soplo Suave"** | Adaptar la exigencia a la capacidad pulmonar | Asistente de soplo (suave/medio/fuerte), umbral de decibeles y estabilidad, perfiles de sensibilidad |
| **Sistema de retos (gamificación)** | Motivar con dinámicas de juego | Retos diarios/semanales, puntos (XP), niveles, rachas, **logros andinos** ("Primer Soplo Limpio", "Maestro del Siku"), desbloqueo de contenido |
| **Seguimiento de progreso** | Visualizar el avance | Nivel actual, lecciones completadas, XP acumulado, estadísticas de precisión tonal y constancia |
| **Comunidad de usuarios** | Fomentar la interacción | Feed social, seguidores, aplausos y comentarios, rankings por instrumento, compartir logros |
| **Tutor inteligente (IA on-device)** | Guía pedagógica contextual | Tutor SLM local en español, explicaciones y correcciones de técnica, recomendación de ejercicios según desempeño, 100% offline |

---

## E. Elementos del sistema basado en computadoras

### E.1 Hardware
- **Servidor:** infraestructura en la nube (VM tipo Google Cloud Compute Engine) para el backend
  (autenticación, contenido, social, rankings) y la base de datos; crecimiento horizontal para
  usuarios concurrentes. **No** ejecuta la IA de práctica (esta corre en el dispositivo).
- **Cliente:** smartphone (Android 8.0+/iOS 13.0+) con **micrófono** (captura de audio del
  instrumento), **cámara frontal** (análisis de postura) y GPU/NPU para MediaPipe y modelos TFLite;
  equipo de escritorio con navegador para el panel web administrativo.
- **Medios de comunicación:** conexión a internet (≥10 Mbps) solo para sincronización, contenido y
  social; la evaluación en vivo funciona **offline**.
- **Otros dispositivos:** opcional, auriculares; no requiere teclado MIDI ni hardware especializado.

### E.2 Software
- **Servidores:** backend **FastAPI (Python)** con SQLAlchemy y Alembic; **PostgreSQL**; despliegue en
  contenedores **Docker**; Nginx como proxy inverso.
- **Clientes:** app móvil en **Flutter/Dart**; panel web administrativo en **Angular/TypeScript**.
- **IA on-device:** detección de pitch **Google SPICE (TFLite) / YIN**; visión **MediaPipe Pose +
  Hands**; tutor **SLM local** (Gemma 2 2B / Llama 3.2 INT4) vía MediaPipe LLM Inference (móvil) /
  WebLLM–WebGPU (web).
- **Otro software:** renderizado de partituras (VexFlow/music21), reproducción MIDI de referencia.

### E.3 Datos
- Usuarios y perfiles (instrumento principal, nivel, perfil de soplo), lecciones y repertorio,
  **tablas de digitación (FingeringChart)** por instrumento, secuencias de notas con marcas de
  respiración, sesiones de práctica (centésimas, control de aire, postura, score), gamificación
  (XP, rachas, logros) y datos sociales (posts, seguidores, comentarios).

### E.4 Procesos
- Captura de audio (16 kHz) y video (30 FPS) en el dispositivo → extracción de telemetría JSON
  compacta (pitch, centésimas, estabilidad, alineación) → afinador/diagrama de digitación en vivo →
  tutor SLM bajo demanda → persistencia de la sesión y XP en el backend al finalizar.

### E.5 Gente
- **Estudiantes** (usuarios finales), **docentes/administradores** (gestión de contenido,
  digitaciones, moderación y reportes) y el **equipo de desarrollo**.

### E.6 Documento
- Documento guía (PAPS + Perfil), manuales de usuario y técnico, catálogo de digitaciones y material
  pedagógico andino.

---

## F. Herramientas tecnológicas para el desarrollo

| Capa / propósito | Tecnología |
|---|---|
| App móvil | **Flutter / Dart** (Android e iOS) |
| Frontend web (admin) | **Angular / TypeScript** |
| Backend / API REST | **FastAPI / Python** (SQLAlchemy, Alembic) |
| Base de datos | **PostgreSQL** |
| Audio DSP (pitch) | SPICE (TFLite) / YIN / aubio |
| Visión (postura) | OpenCV / **MediaPipe Pose + Hands** |
| Tutor IA on-device | TensorFlow Lite + MediaPipe LLM Inference / WebLLM (Gemma 2 2B / Llama 3.2) |
| Notación musical | VexFlow / music21 (MusicXML, MIDI) |
| Contenedores / despliegue (IaaS) | **Docker**, Docker Compose, VM en la nube, GitHub Actions (CI/CD) |
| Modelado de arquitectura | **Modelo C4** (contexto, contenedores, componentes, código) |
| Herramienta de modelado | **Enterprise Architect** (UML: clases, despliegue, paquetes, secuencia) |
| Control de versiones | Git + GitHub (GitFlow, Conventional Commits) |

> **Diferencia con MelodyPath (2025):** aquel usaba Next.js y la IA/el análisis de audio podían ser
> en la nube; Aliento Andino usa **Angular + Flutter** y mantiene la **IA 100% on-device** por
> privacidad, operación offline y cero costo por alumno (RNF-01).

---

*Pendiente tras tu revisión: integrar estas secciones al documento guía (.docx) y definir los
diagramas UML (contexto C4, despliegue, paquetes, clases/modelo de datos, secuencia) adaptados.*
