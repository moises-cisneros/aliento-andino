# Observaciones: PianoVision AI vs. Proyecto de Aliento Andino

Análisis técnico detallado de las diferencias entre el proyecto base (PianoVision)
y el nuevo proyecto de instrumentos de viento andinos, revisando el código real existente.

---

## 1. Capa de Machine Learning (ML)

### PianoVision — `ml/chord_detector`
| Aspecto | Detalle |
|---|---|
| Problema | Clasificación de **acordes de piano** a partir de audio |
| Feature de entrada | **Chroma / PCP** — vector de 12 dimensiones (energía por clase de altura) |
| Modelo | `RandomForestClassifier` (200 árboles, sklearn) |
| Clases | **48 acordes** (12 fundamentales × 4 calidades: maj, min, dim, dom7) |
| Dataset | **19.200 muestras sintéticas** (modelo físico del piano) |
| Accuracy | **0.863** (test), 0.856 ± 0.005 (CV 5-fold) |
| Salida | Etiqueta de acorde (`C:maj`, `A:min`, etc.) |
| Inferencia | Post-grabación o en tiempo real (chroma vía FFT) |

### Proyecto Andino — Nuevo módulo `ml/breath_note_detector`
| Aspecto | Detalle |
|---|---|
| Problema | **Multi-tarea**: detectar nota + intensidad de soplo + calidad del tono + afinación |
| Feature de entrada | Audio PCM crudo del micrófono (no solo chroma) |
| Algoritmos | **YIN/CREPE** (pitch), RMS/envelope (intensidad soplo), CNN (calidad) |
| Clases | Notas en escala pentatónica andina + métricas continuas (float) |
| Dataset | **No existe aún** — se debe generar/recolectar audio real de quena/zampoña/tarka |
| Salida | `{nota, intensidad_soplo, calidad_tono, afinacion_cents}` |
| Inferencia | **Tiempo real obligatorio** (streaming de audio) |

> **Observación clave**: El piano produce notas discretas y precisas (tecla = nota exacta).
> Los instrumentos de viento producen notas **continuas y analógicas**: la misma nota puede
> sonar "limpia", "con aire" o "soplada" dependiendo de la técnica. Esto hace la clasificación
> **significativamente más compleja**. Además, se necesita un **segundo modelo** que no existe
> en PianoVision: el detector de postura y embocadura con MediaPipe.

---

## 2. Modelo de Base de Datos (Backend)

### PianoVision — `models/lesson.py`

El modelo `Lesson` tiene estos campos clave orientados a piano:

```python
tempo_bpm: int          # velocidad del metrónomo
time_signature: str     # "4/4", "3/4"
key_signature: str      # "C", "G", "F#"
```

El modelo `NoteSequence` define cada nota con:

```python
note: str       # "C4", "F#4", "Bb3", "REST" — notación occidental
duration: float # beats (1.0=negra, 0.5=corchea)
finger: int     # dedo recomendado (piano: 1-5)
hand: str       # "left", "right", "both"
velocity: int   # velocidad MIDI (volumen de la tecla)
is_chord: bool  # si es parte de un acorde simultáneo
```

El modelo `PracticeSession` registra:

```python
correct_notes: int      # notas acertadas
wrong_notes: int        # notas erróneas
average_tempo: float    # tempo promedio del usuario
tempo_accuracy: float   # precisión vs tempo esperado
```

### Proyecto Andino — Modelos nuevos requeridos

Los modelos de la BD deben cambiar o extenderse radicalmente:

**Tabla `instruments`** (nueva, no existe en piano):
```python
name: str            # "quena", "zampoña", "tarka", "flauta"
description: str     # descripción cultural
origin_region: str   # "Bolivia", "Perú", "Ecuador"
fingering_chart_url  # imagen de digitación
```

**Tabla `breath_profiles`** (nueva, sin equivalente en piano):
```python
user_id: UUID
instrument_id: UUID
min_intensity: float   # soplo mínimo registrado (0.0–1.0)
avg_intensity: float   # soplo promedio
max_intensity: float   # soplo máximo
calibrated_at: datetime
```

**Cambios en `NoteSequence`** — los campos de piano NO aplican a viento:

| Campo piano | Estado en viento | Razón |
|---|---|---|
| `finger` | ❌ Se elimina | El dedo no aplica igual; se usa digitación de huecos |
| `hand` | ❌ Se elimina | Los vientos no distinguen mano izquierda/derecha igual |
| `velocity` | ❌ Se elimina | No hay velocity MIDI; se reemplaza por `breath_intensity` |
| `is_chord` | ❌ Se elimina | Los vientos de filo no producen acordes |
| `tempo_bpm` | ✅ Se conserva | El tempo sigue siendo relevante |

**Campos nuevos en `NoteSequence`** para viento:
```python
breath_intensity: float    # intensidad de soplo esperada (0.0–1.0, relativa al perfil)
breath_technique: str      # "sostenido", "staccato", "ligado", "vibrato"
hole_fingering: str        # JSON con qué huecos tapar (ej: "[1,2,3,4]")
```

**Cambios en `PracticeSession`** para viento:

| Campo piano | Estado en viento |
|---|---|
| `correct_notes` | ✅ Se conserva |
| `wrong_notes` | ✅ Se conserva |
| `tempo_accuracy` | ✅ Se conserva |
| `average_tempo` | ✅ Se conserva |
| `errors_detail` | ✅ Se extiende (incluye afinación en cents) |

**Campos nuevos en `PracticeSession`** para viento:
```python
avg_pitch_accuracy: float      # precisión de afinación promedio (cents)
avg_breath_intensity: float    # intensidad promedio del soplo
breath_quality_scores: JSON    # distribución clean/breathy/overblown
posture_sessions: relationship # sesiones de análisis de postura vinculadas
```

---

## 3. Servicio de Práctica (Backend)

### PianoVision — `practice_service.py`

La lógica de evaluación es simple y binaria:

```python
# Calcula precisión de tempo
tempo_accuracy = max(0, min(100, 100 - abs(1 - ratio) * 100))

# Registra: correct_notes, wrong_notes, missed_notes
# No hay análisis de calidad del sonido — el piano produce notas exactas
```

### Proyecto Andino — Nuevas funciones requeridas

La evaluación se vuelve **multi-dimensional y adaptativa**:

```python
# 1. Normalización por perfil respiratorio del usuario
def normalize_breath(raw_intensity, user_profile):
    """Ajusta la intensidad al rango calibrado del usuario."""
    return (raw_intensity - profile.min) / (profile.max - profile.min)

# 2. Evaluación de afinación (nuevo, no existe en piano)
def evaluate_pitch(detected_cents, expected_note, tolerance=25):
    """Evalúa si la nota está dentro del rango de afinación aceptable."""
    return abs(detected_cents - expected_cents) <= tolerance

# 3. Evaluación de calidad del soplo (nuevo)
def evaluate_breath_quality(quality_label, expected_technique):
    """Compara técnica de soplo producida vs. esperada."""
    return quality_label == expected_technique
```

---

## 4. Servicio del Tutor IA (Backend)

### PianoVision — `tutor_service.py`

El tutor conoce estas rutas y puede navegar:

```python
_ROUTES = {
    "/lessons": "Inicio de lecciones (escalas, acordes, melodías, ritmo)",
    "/progress": "Mi progreso",
    "/rankings": "Rankings",
    "/social": "Feed de la red social",
    ...
}
```

El agente tiene conocimiento de **piano**: escalas, acordes, melodías, ritmo.

### Proyecto Andino — Extensiones del tutor

El tutor debe incorporar:

1. **Rutas nuevas**: `/breath/calibrate`, `/posture/check`, `/instruments/select`
2. **Conocimiento de digitación andina**: qué huecos tapar para cada nota en cada instrumento
3. **Contexto cultural**: historia de la quena, origen de la zampoña, significado ritual de la tarka
4. **Adaptación respiratoria**: el tutor sabe el perfil pulmonar del usuario y ajusta su lenguaje
   ("Tu soplo es suave — esto es válido en el aliento andino, enfócate en la embocadura")
5. **Evaluación de postura**: el tutor puede pedir al usuario que muestre su agarre ante la cámara

---

## 5. App Móvil Flutter

### PianoVision — Features existentes

```
features/
├── auth/           ✅ Reutilizable sin cambios
├── lessons/        ⚠️  Requiere adaptación (digitación de piano → huecos de viento)
├── tutor/          ⚠️  Requiere extensión (nuevo contexto andino)
├── social/         ✅ Reutilizable con ajustes mínimos
├── rankings/       ✅ Reutilizable sin cambios
├── profile/        ⚠️  Requiere campo de perfil respiratorio
├── onboarding/     ⚠️  Requiere flujo de selección de instrumento andino
├── notifications/  ✅ Reutilizable sin cambios
└── subscription/   ✅ Reutilizable sin cambios
```

### Proyecto Andino — Pantallas nuevas (no existen en piano)

```
features/ (nuevas)
├── instrument_selection/   NUEVA — elegir quena/zampoña/tarka/flauta
├── breath_calibration/     NUEVA — sesión de calibración pulmonar
├── posture_check/          NUEVA — análisis de postura via cámara
├── breath_practice/        NUEVA — práctica con visualizador de soplo en tiempo real
└── andean_culture/         NUEVA — contenido cultural por instrumento
```

---

## 6. Complejidad Técnica Comparada

| Dimensión | PianoVision | Aliento Andino | Diferencia |
|---|---|---|---|
| Entrada de sensor | 1 (micrófono, notas exactas) | 3 (micrófono continuo + cámara + calibración) | **3× más complejo** |
| Modelos ML | 1 (chord detector, clasificación) | 2 (breath+pitch detector + posture detector) | **Doble** |
| Métricas de evaluación | 3 (nota, tempo, score) | 6+ (nota, afinación cents, soplo, calidad, postura, embocadura) | **2× más métricas** |
| Adaptación por usuario | No (nivel fijo) | Sí (perfil respiratorio individual) | **Nuevo paradigma** |
| Contexto cultural en IA | No | Sí (instrumentos, regiones, tradiciones) | **Nuevo** |
| Modelos BD nuevos | 0 | 4+ (Instrument, BreathProfile, PostureSession, BreathSession) | **Nuevo** |
| Dataset ML disponible | Sí (sintético generado) | No (debe recolectarse) | **Bloqueante** |

---

## 7. Observaciones Críticas para el Equipo

> **Lo que se puede reutilizar directamente (≈40% del código base):**
> - Infraestructura: Dockerfile, docker-compose, Nginx, GCP, CI/CD → sin cambios
> - Auth, social, rankings, notifications, subscriptions → sin cambios
> - La arquitectura FastAPI + SQLAlchemy + Alembic → sin cambios
> - Flutter app shell, navegación, tema visual → con ajustes mínimos

> **Lo que requiere adaptación profunda (≈35%):**
> - Modelos de BD: `Lesson`, `NoteSequence`, `PracticeSession` → campos nuevos y eliminados
> - Servicio de práctica: lógica de evaluación completamente diferente
> - Servicio del tutor: conocimiento de dominio andino
> - Pantallas de lecciones en Flutter: visualización de digitación de huecos

> **Lo que debe construirse desde cero (≈25%):**
> - `ml/breath_note_detector`: pitch + soplo + afinación en tiempo real
> - `ml/posture_detector`: MediaPipe + clasificador por instrumento
> - Pantallas nuevas: calibración, postura, cultura andina
> - Dataset de audio real de instrumentos andinos
> - Motor de adaptación respiratoria

> **Riesgo principal — Dataset:**
> El `chord_detector` del piano usa 19.200 muestras **sintéticas** que se
> generan con código. Para el detector de soplo andino, se necesitan **grabaciones
> reales** de quena, zampoña, tarka y flauta con diferentes técnicas y diferentes
> usuarios. Sin este dataset, el modelo ML de audio no puede entrenarse.
> **Acción recomendada:** iniciar recolección de audio en paralelo con el desarrollo.
