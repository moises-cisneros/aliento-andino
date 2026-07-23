# PERFIL DEL PROYECTO

**Proyecto:** PianoVision AI
**Materia:** Ingeniería de Software I (INF422 – SB)
**Carrera:** Ingeniería en Ciencias de la Computación y Telecomunicaciones — UAGRM
**Grupo:** 8
**Gestión:** Semestre I – 2026

---

## Ficha técnica del proyecto

| Campo | Detalle |
|---|---|
| Nombre del producto | PianoVision AI |
| Tipo de producto | Plataforma educativa multiplataforma (app móvil + panel web administrativo + backend) |
| Dominio | Educación musical asistida por inteligencia artificial |
| Usuarios objetivo | Estudiantes principiantes e intermedios de piano; administradores de contenido |
| Plataformas | Android 8.0+ · iOS 13.0+ (móvil) · Navegadores modernos (panel web) |
| Modelo de negocio | Freemium (versión gratuita + suscripción premium mensual/anual) |
| Marco de trabajo | Scrum (sprints de 3 semanas) |

---

## 1. Introducción

El aprendizaje del piano ha dependido históricamente de la presencia de un profesor que observe al estudiante, corrija sus errores y ajuste el ritmo de la enseñanza a su progreso. Este modelo, aunque eficaz, resulta costoso, poco flexible en horarios y geográficamente limitado, lo que deja fuera a una gran cantidad de personas interesadas en aprender música de forma autodidacta.

**PianoVision AI** es una plataforma tecnológica orientada al aprendizaje interactivo del piano que utiliza procesamiento digital de audio, visión por computadora e inteligencia artificial para analizar en tiempo real la ejecución musical del usuario. El sistema reconoce las notas que el estudiante toca, evalúa su precisión y su ritmo, y entrega retroalimentación automática personalizada, ofreciendo una experiencia equivalente a la de un profesor virtual de piano disponible en cualquier momento.

El presente documento constituye el **Perfil del Proyecto**: define el contexto, los antecedentes, el problema que se busca resolver, la justificación, los objetivos, el alcance y las limitaciones que enmarcan el desarrollo de PianoVision AI. Sirve como punto de partida conceptual sobre el cual se construyen los artefactos de planificación y desarrollo descritos en los sprints posteriores.

## 2. Antecedentes

El interés por digitalizar la enseñanza musical no es nuevo. En la actualidad existen aplicaciones comerciales de aprendizaje de piano ampliamente difundidas —como *Simply Piano*, *flowkey*, *Yousician* o *Piano Academy*— que han demostrado que el mercado de la educación musical asistida por software es real y está en crecimiento. Sin embargo, estas soluciones presentan limitaciones relevantes: son de **código cerrado**, operan bajo suscripciones de pago, y varias dependen de la conexión de un **teclado MIDI físico** o de condiciones controladas para funcionar correctamente.

Como parte del análisis previo de este proyecto (ver **Primera Parte — Análisis de Aplicaciones Similares y Estimación**, [parte-1-aplicaciones-similares.md](parte-1-aplicaciones-similares.md)), se estudiaron en profundidad tres referentes de código abierto, maduros y en producción, que cubren las dimensiones funcionales principales del sistema:

| Aplicación de referencia | Aporte al diseño de PianoVision AI |
|---|---|
| **MuseScore Studio** | Notación musical, reproducción asistida y comunidad social educativa |
| **PianoBooster** | Práctica guiada y evaluación en tiempo real de la ejecución contra una partitura esperada |
| **Nootka** | Detección de notas por micrófono (pitch detection) y exámenes con corrección automática |

De ese estudio comparativo se concluyó que **ninguna herramienta existente combina simultáneamente**: (a) la detección de notas por audio sin necesidad de hardware MIDI adicional, (b) el análisis de la ejecución mediante visión por computadora, (c) la retroalimentación generada por inteligencia artificial, y (d) una capa de gamificación y comunidad orientada a la retención del estudiante. Esa combinación define el espacio de oportunidad que PianoVision AI busca ocupar.

## 3. Planteamiento del problema

El aprendizaje autodidacta del piano enfrenta un obstáculo central: **la ausencia de retroalimentación inmediata y confiable**. Cuando un estudiante practica solo, no dispone de un mecanismo que le indique en el momento si está tocando las notas correctas, si respeta el tempo de la pieza o si su técnica es adecuada, por lo que tiende a consolidar errores difíciles de corregir más adelante.

Las alternativas digitales disponibles atenúan parcialmente este problema, pero introducen barreras propias: requieren la compra de un teclado MIDI, funcionan bajo modelos de pago poco accesibles, son de código cerrado —lo que impide adaptarlas a un contexto educativo específico— y, en general, no integran en una sola solución el análisis de audio, el análisis visual de la ejecución y la retroalimentación inteligente.

> **Formulación del problema:** ¿Cómo proporcionar a un estudiante principiante o intermedio de piano una evaluación automática, inmediata y personalizada de su ejecución musical —sin necesidad de un profesor presencial ni de hardware especializado— utilizando únicamente la cámara y el micrófono de un dispositivo móvil convencional?

## 4. Justificación

El desarrollo de PianoVision AI se justifica desde tres perspectivas:

- **Social y educativa.** Democratiza el acceso al aprendizaje del piano al eliminar la dependencia de un profesor presencial en las etapas inicial e intermedia, reduciendo barreras económicas y geográficas. El estudiante practica de forma autónoma mientras recibe evaluación inmediata de su interpretación.

- **Tecnológica.** Aprovecha la disponibilidad masiva de cámaras y micrófonos en los teléfonos inteligentes para reemplazar el hardware MIDI especializado. La detección de notas mediante procesamiento de audio en tiempo real (algoritmo YIN para monofonía y FFT para detección de acordes), el análisis de digitación por visión computacional y la retroalimentación generada por modelos de inteligencia artificial (Gemini, sobre Vertex AI) hacen posible una experiencia de tutoría virtual sobre dispositivos de uso cotidiano.

- **Económica.** El modelo *freemium* permite un acceso gratuito a contenido básico que facilita la adopción, a la vez que sostiene la plataforma mediante una suscripción premium con contenido avanzado, análisis detallado del desempeño e historial de progreso.

Adicionalmente, en el plano **académico**, el proyecto constituye un caso integral de aplicación de la Ingeniería de Software: combina el desarrollo móvil (Flutter), web (Angular) y de servicios backend (FastAPI), bajo el marco de trabajo Scrum, integración continua y prácticas de calidad como pruebas automatizadas, control de versiones y arquitectura limpia.

## 5. Objetivos

### 5.1. Objetivo general

Desarrollar un sistema de software educativo multiplataforma para la enseñanza integral del piano, que combine una aplicación móvil (Android/iOS) construida con Flutter y una plataforma web administrativa construida con Angular y FastAPI, capaz de analizar la ejecución musical del usuario en tiempo real mediante procesamiento de audio, visión por computadora e inteligencia artificial, y de entregar una experiencia de aprendizaje personalizada, adaptativa e interactiva que abarque desde el nivel inicial hasta el intermedio.

### 5.2. Objetivos específicos

- Implementar un sistema de aprendizaje adaptativo basado en una evaluación diagnóstica inicial del nivel del usuario.
- Desarrollar un motor de notación musical capaz de interpretar y renderizar archivos MusicXML y MIDI, sincronizándolos con la ejecución del usuario.
- Integrar un sistema de análisis de audio en tiempo real para la identificación de notas, la evaluación de la precisión y la detección del ritmo (tempo).
- Incorporar visión por computadora para el análisis de la postura y la digitación de las manos sobre el teclado.
- Generar retroalimentación automática y personalizada del desempeño mediante inteligencia artificial.
- Incorporar un sistema de gamificación (puntos, niveles, rachas, logros y rankings) para mejorar la retención y la motivación del usuario.
- Diseñar un sistema híbrido que combine contenido disponible sin conexión (offline) con las funcionalidades avanzadas de IA en línea (online).
- Desarrollar una plataforma web administrativa para la gestión de usuarios, contenidos, moderación y la generación de reportes analíticos.

## 6. Alcance

El proyecto contempla el desarrollo de los siguientes componentes y funcionalidades:

**Componentes del sistema**

- **Aplicación móvil (Flutter):** cliente principal para el estudiante, disponible en Android e iOS.
- **Plataforma web administrativa (Angular):** panel para administradores de contenido y moderación.
- **Backend de servicios (FastAPI + PostgreSQL):** API REST, lógica de negocio, autenticación y persistencia.
- **Servicios de IA y procesamiento:** análisis de audio, visión por computadora y generación de retroalimentación.

**Funcionalidades incluidas**

- Registro, autenticación segura (JWT) y gestión de perfiles de usuario.
- Evaluación diagnóstica inicial y generación de rutas de aprendizaje personalizadas.
- Biblioteca de lecciones, ejercicios y canciones organizadas por nivel de dificultad.
- Guía visual de ejecución previa a la práctica (notas a presionar, demostración paso a paso).
- Detección de notas por audio en tiempo real y evaluación de precisión y tempo.
- Análisis de la ejecución mediante cámara (postura y digitación).
- Retroalimentación automática del desempeño con recomendaciones de mejora.
- Gamificación: puntos, niveles, rachas, logros y ranking global.
- Funcionalidad offline para contenido básico y descarga de lecciones.
- Panel administrativo: gestión de usuarios, contenidos, moderación y reportes analíticos exportables.

## 7. Limitaciones y supuestos

**Limitaciones**

- El sistema está orientado a estudiantes de nivel **inicial e intermedio**; no abarca el repertorio ni la evaluación de nivel profesional o de conservatorio.
- Las funcionalidades avanzadas de inteligencia artificial **requieren conexión a internet**; en modo offline solo está disponible el contenido básico previamente descargado.
- La precisión de la detección de notas y de la digitación depende de las **condiciones del entorno** (iluminación, ángulo de la cámara, ruido acústico y calidad del micrófono).
- El análisis polifónico (acordes) se centra en **acordes simples**; la transcripción polifónica compleja queda fuera del alcance de esta versión.

**Supuestos**

- El usuario dispone de un dispositivo móvil con cámara (mínimo 720p) y micrófono funcionales, compatible con Android 8.0+ o iOS 13.0+.
- El usuario cuenta con un piano acústico o teclado electrónico físico sobre el cual practicar frente a la cámara.
- Para las funciones en línea, el usuario dispone de una conexión a internet estable.

## 8. Marco conceptual

A continuación se definen los conceptos clave que sustentan el proyecto:

- **DSP (Procesamiento Digital de Señales):** conjunto de técnicas para analizar señales de audio; en PianoVision AI se emplea para detectar la frecuencia fundamental de las notas tocadas.
- **Detección de pitch (YIN / FFT):** algoritmos que estiman la altura tonal de un sonido. YIN se usa para sonidos monofónicos (una nota a la vez) y la FFT (Transformada Rápida de Fourier) para identificar componentes de acordes.
- **Visión por computadora (Computer Vision):** análisis automático de imágenes de la cámara para localizar el teclado y la posición de los dedos del usuario.
- **MusicXML / MIDI:** formatos estándar de representación de notación y eventos musicales que el sistema interpreta y sincroniza con la práctica.
- **Inteligencia Artificial generativa:** modelos (Gemini sobre Vertex AI) que producen retroalimentación textual personalizada a partir del desempeño del usuario.
- **Gamificación:** aplicación de mecánicas de juego (puntos, niveles, rachas, logros, rankings) para incrementar la motivación y la retención.
- **JWT (JSON Web Token):** mecanismo de autenticación basado en tokens firmados utilizado para proteger el acceso a los servicios del sistema.
- **Scrum:** marco de trabajo ágil bajo el cual se organiza el desarrollo del proyecto en sprints iterativos e incrementales.

---

*Fin del Perfil del Proyecto.*
