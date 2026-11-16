# Product Backlog — Aliento Andino

**Tutor Virtual de Instrumentos de Viento Andinos** (adaptación de PianoVision AI)
Instrumentos soportados: **Quena · Zampoña/Siku · Tarka**
Versión: 1.0 · Fecha: 2026-11-15

> Este backlog adapta las 34 historias de usuario originales de PianoVision a instrumentos de
> viento andinos monofónicos. Se mantiene la numeración y los módulos del documento guía para
> no romper las referencias de los sprints; cada HU indica su **estado de migración** y la
> **trazabilidad** a los requerimientos del docente (RF/RNF) y a las Épicas del plan.

## Leyenda de estados

| Estado | Significado |
|---|---|
| 🟢 **MANTENER** | La HU es universal; se conserva casi sin cambios (ajustes menores de redacción). |
| 🟡 **ADAPTAR** | Se conserva el propósito pero se reemplaza lo específico de piano por viento andino. |
| 🔴 **ELIMINAR** | No aplica a viento monofónico; la ranura se reutiliza para una funcionalidad del plan. |
| 🔵 **NUEVO** | Funcionalidad exigida por Aliento Andino que no existía en PianoVision. |

---

## MÓDULO: AUTENTICACIÓN Y GESTIÓN DE USUARIOS

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-01** | Registro de usuario | **Como** usuario nuevo, **quiero** registrarme con nombre, correo y contraseña y elegir mi instrumento principal (Quena, Zampoña o Tarka), **para** acceder a la plataforma y comenzar mi ruta de aprendizaje de viento andino. | Alta | 🟡 ADAPTAR | RF-04 · Épica 1 |
| **HU-02** | Autenticación de usuario | **Como** usuario registrado, **quiero** iniciar sesión de forma segura (JWT / Google OAuth), **para** acceder a mi perfil y progreso. | Alta | 🟢 MANTENER | RNF — · Épica 1 |
| **HU-03** | Recuperación de contraseña | **Como** usuario, **quiero** recuperar mi contraseña olvidada, **para** restablecer el acceso a mi cuenta. | Media | 🟢 MANTENER | Épica 1 |

## MÓDULO: EVALUACIÓN DIAGNÓSTICA

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-04** | Evaluación diagnóstica inicial | **Como** usuario nuevo, **quiero** completar una evaluación de nivel para mi instrumento (producción de sonido, embocadura/soplo y digitaciones básicas), **para** que el sistema genere una ruta de aprendizaje personalizada. | Alta | 🟡 ADAPTAR | RF-01 · Épica 1 |
| **HU-05** | Selección de conceptos dominados | **Como** usuario, **quiero** indicar las técnicas que ya domino (p. ej. escala pentatónica, articulación), **para** que se omitan en mi ruta de aprendizaje. | Alta | 🟡 ADAPTAR | RF-01 · Épica 1 |

## MÓDULO: RUTA DE APRENDIZAJE PERSONALIZADA

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-06** | Generación de ruta de aprendizaje | **Como** usuario, **quiero** que el sistema genere automáticamente una ruta (iniciación, embocadura, digitación, escalas pentatónicas y piezas folclóricas) según mi nivel, **para** avanzar progresivamente. | Alta | 🟡 ADAPTAR | RF-01 · Épica 4 |
| **HU-07** | Exploración libre de lecciones | **Como** usuario, **quiero** seleccionar cualquier lección del catálogo de mi instrumento, **para** aprender a mi propio ritmo. | Media | 🟢 MANTENER | Épica 3 |
| **HU-08** | Seguimiento de progreso | **Como** usuario, **quiero** visualizar mi avance en la ruta de aprendizaje, **para** conocer mi progreso general. | Alta | 🟢 MANTENER | Épica 6 |

## MÓDULO: MOTOR DE NOTACIÓN MUSICAL

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-09** | Renderizado de partituras | **Como** usuario, **quiero** visualizar partituras monofónicas cargadas desde MusicXML con marcas de respiración, **para** estudiar la notación de la pieza. | Alta | 🟡 ADAPTAR | RF-01 · Épica 3 |
| **HU-10** | Reproducción de nota de referencia (MIDI) | **Como** usuario, **quiero** escuchar la reproducción MIDI / nota de referencia de la lección, **para** guiarme en la afinación y la práctica. | Alta | 🟢 MANTENER | Épica 3 |
| **HU-11** | Visualización de pentagrama y digitación | **Como** usuario, **quiero** ver el pentagrama (clave de Sol, tesitura del instrumento, figuras rítmicas y marcas de respiración) junto al diagrama de digitación de la nota, **para** leer y ejecutar correctamente. | Alta | 🟡 ADAPTAR | RF-04 · Épica 3 |
| **HU-12** | Sincronización partitura–reproducción | **Como** usuario, **quiero** que la partitura se resalte sincronizada con la reproducción, **para** seguir la música en tiempo real. | Alta | 🟢 MANTENER | Épica 3 |

## MÓDULO: DIGITACIONES ANDINAS *(nuevo módulo)*

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-13** | Guía de digitación del instrumento activo | **Como** usuario, **quiero** ver un diagrama interactivo de digitación de mi instrumento (6 orificios + trasero en Quena, hileras Ira/Arka en Zampoña, 6 orificios en Tarka) que muestre orificios/tubos tapados, destapados y medio tapados para cada nota, **para** saber exactamente cómo ejecutarla. | Alta | 🔵 NUEVO *(sustituye "Modo lección guiada" piano)* | RF-04 · Épica 3 (3.1–3.2) |

## MÓDULO: SISTEMA DE PRÁCTICA INTERACTIVA

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-14** | Modo práctica libre | **Como** usuario, **quiero** practicar libremente sin restricciones, **para** explorar y reforzar lo aprendido. | Media | 🟢 MANTENER | Épica 3 |
| **HU-15** | Modo entrenamiento con parámetros | **Como** usuario, **quiero** configurar la velocidad (BPM), aislar fragmentos y ajustar el tempo andino (huayno, saya, tinku), **para** practicar de forma enfocada. | Alta | 🟡 ADAPTAR | RF-01 · Épica 3 |
| **HU-16** | Retroalimentación en tiempo real | **Como** usuario, **quiero** recibir retroalimentación inmediata de la nota tocada y su desviación en centésimas, **para** corregir errores de afinación al instante. | Alta | 🟡 ADAPTAR | RF-03 · Épica 2–3 |

## MÓDULO: PROCESAMIENTO DE AUDIO (AFINACIÓN MONOFÓNICA, DSP + IA)

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-17** | Detección de frecuencia fundamental (f₀) | **Como** usuario, **quiero** que el sistema detecte con precisión la nota que ejecuto (SPICE/YIN monofónico, latencia < 100 ms) y su desviación en centésimas, **para** evaluar mi afinación en vivo. | Alta | 🟡 ADAPTAR | RF-03 · RNF-03 · Épica 2 (2.1) |
| **HU-18** | Análisis de precisión rítmica | **Como** usuario, **quiero** que el sistema evalúe el ritmo de mi ejecución, **para** mejorar mi precisión temporal. | Alta | 🟢 MANTENER | RF-03 · Épica 2 |
| **HU-19** | Afinador visual en centésimas | **Como** usuario, **quiero** un afinador de aguja que muestre si mi soplo está calado (grave), afinado (±10 cents) o alto (agudo) con accesibilidad cromática y modo oscuro/claro, **para** ajustar mi afinación con tolerancia configurable. | Alta | 🔵 NUEVO *(sustituye "Detección de acordes")* | RF-03 · Épica 3 (3.3) |

## MÓDULO: ANÁLISIS DE POSTURA CON IA

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-20** | Evaluación de postura y sujeción | **Como** usuario, **quiero** que la cámara frontal analice mi postura (verticalidad del instrumento, ángulo de codos, alineación de cabeza/torso y posición de dedos sobre orificios/tubos) mediante MediaPipe Pose+Hands, **para** recibir una puntuación de postura (0–100) y correcciones técnicas en tiempo real. | Media | 🟡 ADAPTAR | RF-02 · Épica 2 (2.2) |
| **HU-21** | Retroalimentación correctiva de postura | **Como** usuario, **quiero** recibir alertas visuales cuando mi sujeción o embocadura sea incorrecta, **para** prevenir malos hábitos y mejorar la técnica. | Media | 🟡 ADAPTAR | RF-02 · Épica 2 |

## MÓDULO: GAMIFICACIÓN

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-22** | Sistema de puntos y niveles | **Como** usuario, **quiero** ganar puntos y subir de nivel al completar lecciones, **para** mantenerme motivado. | Media | 🟢 MANTENER | RF-05 · Épica 6 |
| **HU-23** | Rachas de práctica | **Como** usuario, **quiero** ver mis rachas de práctica diaria, **para** incentivar la constancia. | Media | 🟢 MANTENER | RF-05 · Épica 6 |
| **HU-24** | Logros y medallas andinas | **Como** usuario, **quiero** desbloquear logros andinos ("Primer Soplo Limpio", "Maestro del Siku", "Control de Aire 30s", "Escala Pentatónica Completa"), **para** celebrar mis avances. | Media | 🟡 ADAPTAR | RF-05 · Épica 1 (1.4) · Épica 6 |
| **HU-25** | Rankings por instrumento | **Como** usuario, **quiero** ver mi posición en rankings semanales/globales segmentados por instrumento (Top Quenistas, Zampoñistas, Tarkistas), **para** competir amistosamente. | Baja | 🟡 ADAPTAR | RF-05 · Épica 6 (6.2) |
| **HU-26** | Compartir progreso en el feed social | **Como** usuario, **quiero** compartir un resumen de mi práctica (obra, instrumento, precisión y medalla) en el feed, **para** motivar a otros y recibir aplausos/comentarios. | Baja | 🟡 ADAPTAR | RF-05 · Épica 6 (6.1) |

## MÓDULO: FUNCIONALIDAD OFFLINE / ON-DEVICE

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-27** | Descarga de lecciones para modo offline | **Como** usuario, **quiero** descargar lecciones, **para** practicar sin conexión a internet en cualquier momento. | Media | 🟢 MANTENER | RNF-01 · Épica 3 |
| **HU-28** | Evaluación 100% local sin conexión | **Como** usuario, **quiero** acceder a ejercicios y a la evaluación de afinación/postura sin internet y sin enviar audio ni video a la nube, **para** practicar en cualquier lugar con privacidad y cero costo. | Media | 🟡 ADAPTAR | RNF-01 · RNF-02 · Épica 2 |

## MÓDULO: PLATAFORMA WEB ADMINISTRATIVA

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-29** | Gestión de usuarios (Admin) | **Como** administrador, **quiero** gestionar cuentas de usuario (moderación, sanciones, reportes), **para** mantener el control del sistema. | Alta | 🟢 MANTENER | RF-05 · Épica 7 |
| **HU-30** | Gestión de contenido educativo (Admin) | **Como** administrador, **quiero** crear, editar y eliminar lecciones y repertorio andino con marcas de respiración, tempo andino y selección de instrumento, **para** mantener el catálogo actualizado. | Alta | 🟡 ADAPTAR | RF-01 · Épica 7 (7.2) |
| **HU-31** | Gestión de digitaciones (Admin) | **Como** administrador, **quiero** registrar gráficamente el catálogo de digitaciones por instrumento y nota (orificios/tubos a cubrir, digitaciones alternas) con validación de unicidad, **para** administrar las tablas de digitación oficiales. | Alta | 🟡 ADAPTAR *(antes "Config. de niveles y rutas")* | RF-04 · Épica 1 (1.2) · Épica 7 (7.1) |
| **HU-32** | Reportes analíticos por instrumento (Admin) | **Como** administrador, **quiero** visualizar reportes de precisión tonal, uso y abandono filtrados por instrumento andino, **para** tomar decisiones pedagógicas. | Media | 🟡 ADAPTAR | RF-05 · Épica 7 |

## MÓDULO: NOTIFICACIONES Y PERFIL

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-33** | Notificaciones push de práctica | **Como** usuario, **quiero** recibir recordatorios de práctica, **para** mantener una rutina consistente. | Baja | 🟢 MANTENER | RF-05 · Épica 6 |
| **HU-34** | Gestión de perfil y perfil de soplo | **Como** usuario, **quiero** editar mi perfil, instrumento(s) y mi perfil de calibración respiratoria, **para** personalizar mi experiencia y la sensibilidad del evaluador. | Media | 🟡 ADAPTAR | RF-06 · Épica 1 · Épica 5 |

---

## Nuevas HU requeridas por Aliento Andino (no existían en PianoVision)

> Cubren RF-01 (tutor SLM) y RF-06 ("Soplo Suave"), que no tenían equivalente en las 34 HU de piano.
> Se proponen como altas prioridades para no dejar RF del docente sin respaldo en el backlog.

| ID | Nombre corto | Historia de usuario (Como / Quiero / Para) | Prioridad | Estado | Trazabilidad |
|---|---|---|---|---|---|
| **HU-35** | Calibración respiratoria "Soplo Suave" | **Como** usuario, **quiero** un asistente que mida mi soplo (suave/medio/fuerte) durante unos segundos y registre mi umbral de decibeles y estabilidad, **para** que los ejercicios se adapten a mi capacidad pulmonar sin penalizaciones injustas. | Alta | 🔵 NUEVO | RF-06 · Épica 5 (5.1–5.2) |
| **HU-36** | Tutor pedagógico local (SLM on-device) | **Como** usuario, **quiero** conversar con un tutor inteligente que funciona 100% en mi dispositivo y me explique conceptos y corrija mis errores de ejecución (p. ej. "cubre bien el 3er orificio de la Quena"), **para** aprender con retroalimentación contextual offline. | Alta | 🔵 NUEVO | RF-01 · RNF-01 · RNF-04 · Épica 4 |
| **HU-37** | Cambio dinámico de instrumento activo | **Como** usuario con varios instrumentos, **quiero** cambiar el instrumento activo desde mi perfil, **para** que el afinador, la guía de digitación y las lecciones se adapten automáticamente. | Media | 🔵 NUEVO | RF-04 · Épica 1 · Épica 3 |

---

## Resumen de la migración

- **Total propuesto:** 34 HU originales (reenumeradas en los mismos módulos) + **3 HU nuevas** (HU-35 a HU-37) = **37 HU**.
- **Eliminada de piano:** "Detección de acordes mediante IA" (viento andino es estrictamente **monofónico**) → ranura reutilizada para el **Afinador en centésimas** (HU-19).
- **Reconvertidas:** "Modo lección guiada" → **Guía de digitación** (HU-13); "Configuración de niveles y rutas" → **Gestión de digitaciones Admin** (HU-31).
- **Conceptos de piano retirados en toda la redacción:** acordes/armonía, manos (izq/der), dedos 1–5, teclado, claves de Fa; sustituidos por centésimas, orificios/tubos, embocadura/soplo y monofonía.
- **Cobertura de requerimientos del docente:** RF-01 (HU-04/05/06/36), RF-02 (HU-20/21), RF-03 (HU-16/17/18/19), RF-04 (HU-01/11/13/31/37), RF-05 (HU-22→26/29/32/33), RF-06 (HU-34/35). RNF-01/02/03/04 reflejados en HU-17 y HU-28.

> **Pendiente de decidir contigo:** ¿dejamos 34 HU "duras" absorbiendo HU-35/36/37 dentro de los módulos (renumerando), o mantenemos 37 como aquí? Lo ajusto antes de llevarlo al `.docx`.
