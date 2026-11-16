# 🎵 AndeanBreath AI — Tutor Inteligente de Instrumentos de Viento Andinos

## Descripción del Proyecto

Adaptar la arquitectura de **PianoVision AI** para crear **AndeanBreath AI**: una plataforma de aprendizaje basado en IA para instrumentos de viento andinos (quena, zampoña, tarka, flauta). El sistema debe:

- Analizar el **audio en tiempo real** del usuario (nota tocada, calidad del soplo, afinación).
- Adaptar la dificultad según la **capacidad pulmonar/respiratoria** de cada estudiante.
- Guiar al alumno desde la **postura y agarre del instrumento** (mediante visión computacional) hasta la ejecución de melodías.
- Proveer una **red social** de estudiantes en proceso similar.
- Funcionar con **agentes inteligentes e IA local** (Gemini + modelos de audio locales).

La arquitectura base (Flutter + FastAPI + Angular + PostgreSQL + GCP) se **reutiliza y extiende** con nuevos módulos de IA.

---

## Diferencias Clave vs PianoVision

| Aspecto | PianoVision (Piano) | AndeanBreath (Viento Andino) |
|---|---|---|
| Instrumento | Piano (teclas) | Quena, Zampoña, Tarka, Flauta |
| Entrada primaria | MIDI / audio de teclas | Audio de soplo / micrófono |
| IA de audio | Chord detector (acordes) | **Note + Breath detector** (nota + intensidad soplo) |
| Evaluación física | No aplica | **Postura + agarre** via cámara (visión computacional) |
| Adaptación | Nivel fijo | **Adaptación respiratoria** por usuario |
| Contexto cultural | Occidental | **Andino** (escalas pentatónicas, notas culturales) |

---

## Componentes Nuevos a Desarrollar

### 1. 🎤 ML: Breath & Note Detector
**Reemplaza** `ml/chord_detector` con un nuevo módulo `ml/breath_note_detector`.

- **Input**: Audio PCM en tiempo real (micrófono del celular).
- **Output**:
  - Nota detectada (ej. `LA4`, `SOL3`)
  - Intensidad del soplo (`0.0–1.0`)
  - Calidad del tono (`clean`, `breathy`, `overblown`)
  - Afinación en cents (`-50` a `+50`)
- **Tecnología**:
  - `librosa` + `aubio` para pitch detection (YIN algorithm)
  - Modelo CNN ligero para clasificación de calidad de soplo
  - Perfil respiratorio por usuario (calibración inicial)

### 2. 👁️ ML: Posture Vision Detector
Nuevo módulo `ml/posture_detector`.

- **Input**: Frame de cámara del celular (imagen JPEG).
- **Output**:
  - `instrument_held_correctly: bool`
  - `hand_position: str` (ej. "left_hand_upper", "right_hand_lower")
  - `embouchure_score: float` (0–1, calidad de la embocadura)
  - `feedback: str` (texto de corrección)
- **Tecnología**: MediaPipe Pose + clasificador custom por instrumento.

### 3. 🧠 Backend: Nuevos Servicios y Rutas

#### Nuevas rutas FastAPI:

| Ruta | Método | Descripción |
|---|---|---|
| `/breath/calibrate` | POST | Calibración respiratoria inicial del usuario |
| `/breath/analyze` | POST | Analizar audio (nota + soplo + afinación) |
| `/posture/analyze` | POST | Analizar frame de cámara (postura + agarre) |
| `/instruments/{id}/lessons` | GET | Lecciones adaptadas al instrumento |
| `/learning-path/adaptive` | GET | Ruta de aprendizaje personalizada por perfil |

#### Nuevos modelos de base de datos:

- `Instrument` — quena, zampoña, tarka, flauta (con descripción cultural)
- `BreathProfile` — capacidad pulmonar calibrada por usuario
- `PostureSession` — registro de sesiones de evaluación de postura
- `BreathSession` — registro de sesiones de análisis de soplo
- `AndesCulturalNote` — notas culturales sobre cada instrumento

#### Nuevos servicios:
- `breath_analysis_service.py` — orquesta el ML de audio
- `posture_service.py` — orquesta el ML de visión
- `adaptive_learning_service.py` — ajusta dificultad según perfil respiratorio
- `andean_tutor_service.py` — extiende `tutor_service.py` con contexto andino

### 4. 📱 Mobile: Nuevas Pantallas Flutter

Las pantallas existentes se adaptan; se agregan:

- **InstrumentSelectionScreen** — elegir instrumento al inicio
- **BreathCalibrationScreen** — calibrar capacidad pulmonar (soplo suave → fuerte)
- **PostureCheckScreen** — cámara en tiempo real para verificar agarre
- **BreathPracticeScreen** — pantalla de práctica con visualizador de soplo en tiempo real
- **AndesCultureScreen** — información cultural de cada instrumento

### 5. 🌐 Web Admin: Extensiones Angular

- Panel de gestión de instrumentos andinos
- Visualizador de estadísticas de soplo por estudiante
- Módulo de contenido cultural (agregar notas culturales, videos)
- Gestión de rutas de aprendizaje adaptativas

---

## Plan de Implementación por Fases

### Fase 1: Fundamentos del Dominio (Semana 1)
1. Renombrar/adaptar modelos de BD para instrumentos andinos
2. Crear seed data de instrumentos (quena, zampoña, tarka, flauta) con lecciones básicas
3. Adaptar el onboarding móvil para selección de instrumento + calibración inicial

### Fase 2: IA de Audio (Semana 2)
1. Desarrollar `ml/breath_note_detector` con detección de pitch (YIN/CREPE)
2. Implementar perfil respiratorio adaptativo por usuario
3. Conectar con backend vía `/breath/analyze`
4. Integrar en Flutter con captura de audio en tiempo real

### Fase 3: IA de Visión (Semana 3)
1. Implementar `ml/posture_detector` con MediaPipe
2. Crear perfiles de postura por instrumento
3. Integrar en Flutter con cámara en tiempo real
4. Feedback visual en pantalla

### Fase 4: Rutas de Aprendizaje Adaptativas (Semana 4)
1. Motor de adaptación según perfil respiratorio
2. Curriculum estructurado (postura → notas básicas → escala pentatónica → melodías)
3. Sistema de logros adaptados (soplo suave, sostenido, limpio)
4. Red social de estudiantes de vientos andinos

### Fase 5: Contenido Cultural + Pulido (Semana 5)
1. Contenido cultural de cada instrumento
2. Afinación específica andina (escala pentatónica)
3. Evaluación completa end-to-end
4. Despliegue en GCP

---

## Preguntas Abiertas

> **¿Qué fase o componente se implementa primero?**
> Opciones: backend (modelos y rutas), ML de audio, onboarding Flutter, o panel web.

> **¿Existen datos de audio de quena/zampoña/tarka para entrenar el modelo ML?**
> Si no, se puede usar datasets públicos o síntesis de audio de viento.

> **¿El proyecto mantiene el nombre "PianoVision" internamente o se renombra?**
> Sugerencia: "AndeanBreath" o "VientoAndino" para claridad académica.

> **¿La IA local corre en el dispositivo móvil (TFLite on-device) o en servidor local (FastAPI)?**
> Flutter con TFLite puede correr modelos directamente en el teléfono.

---

## Verificación del Plan

### Tests Automatizados
- `pytest backend/tests/` — tests existentes de backend (sin romper)
- Tests nuevos de `breath_analysis_service` y `posture_service`

### Verificación Manual
- Flujo completo: registro → selección de instrumento → calibración respiratoria → lección → evaluación
- Verificar que la IA adapta la dificultad según soplo suave vs fuerte
- Verificar detección de postura con cámara frontal

---

## Stack Tecnológico Completo

```
┌──────────────────────────────────────────────┐
│            AndeanBreath AI                   │
├─────────────┬────────────┬───────────────────┤
│ Flutter App │ FastAPI    │ Angular Admin     │
│ (Mobile)    │ Backend    │ (Web)             │
├─────────────┼────────────┼───────────────────┤
│ Audio       │ Gemini AI  │ Charts +          │
│ Capture     │ + Local ML │ Analytics         │
│ Camera      │            │                   │
├─────────────┴────────────┴───────────────────┤
│         PostgreSQL + GCP Infrastructure      │
├──────────────────────────────────────────────┤
│  ml/breath_note_detector  (librosa + aubio)  │
│  ml/posture_detector      (MediaPipe)        │
└──────────────────────────────────────────────┘
```
