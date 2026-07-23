# 🎹 Modelo de Detección de Acordes — PianoVision AI (HU-19)

Modelo de **Machine Learning** que reconoce el **acorde** que se está tocando a
partir de un descriptor de audio. Cubre la historia de usuario **HU-19 –
"Detección de acordes mediante IA"** del módulo *Procesamiento de Audio (DSP + IA)*.

> **TL;DR** — Clasificador entrenado (`RandomForest`) sobre un **dataset
> sintético de 19 200 muestras** y **48 clases de acordes**. Accuracy en test
> **0.863**, F1-macro **0.863**, validación cruzada 5-fold **0.856 ± 0.005**.

---

## 1. Problema y enfoque

Reconocer un acorde de piano = clasificar, a partir del sonido, cuál de las
combinaciones de notas se está ejecutando. En vez de trabajar sobre la forma
de onda cruda, usamos el descriptor estándar del área de *Music Information
Retrieval* (MIR): el **chroma** o **Pitch Class Profile (PCP)**.

- El **chroma** es un vector de **12 dimensiones**: la energía relativa de cada
  una de las 12 clases de altura (C, C#, D, D#, E, F, F#, G, G#, A, A#, B).
- Colapsa todas las octavas en 12 bins ⇒ un Do en cualquier octava suma al
  mismo bin. Por eso es robusto al registro y al timbre, y es el feature que
  usan sistemas reales de reconocimiento de acordes (Chordino, etc.).

En la app, el módulo de audio calcula el chroma de la señal del micrófono
(FFT → energía por nota) y este modelo lo traduce a una **etiqueta de acorde**.

## 2. ¿Por qué un dataset *sintético*?

No existe un corpus público y etiquetado de **acordes de piano ya convertidos a
chroma**. Grabar y etiquetar a mano decenas de miles de acordes era inviable
para el equipo, así que **generamos los datos** con un **modelo físico** simple
del sonido del piano (ver `generate_dataset.py`):

1. Cada nota del acorde aporta su **frecuencia fundamental**.
2. Y sus **armónicos**, que en un piano real "ensucian" el chroma:
   - 2º armónico → octava (misma clase de altura)
   - 3º armónico → quinta justa (+7 semitonos)
   - 5º armónico → tercera mayor (+4 semitonos), etc.
3. Se añade **ruido de fondo**, **ruido de medición** del micrófono, **notas
   mal pulsadas** (que casi no suenan) y, sobre todo, **fuga de un 2º acorde**
   (resonancia del pedal / transición entre acordes) — la causa nº1 de
   confusión real en este problema.

Ese realismo es lo que evita un accuracy "de juguete": el modelo **no llega a
100 %** justamente porque los acordes emparentados se confunden de forma
musicalmente coherente (ver §6).

> **Honestidad:** los datos son sintéticos, no grabaciones reales. El siguiente
> paso natural sería **afinar** (fine-tuning) el modelo con un set chico de
> audio real grabado en la app. La arquitectura y el pipeline no cambian.

## 3. El dataset

Archivo: [`data/chords_dataset.csv`](data/chords_dataset.csv)

| Propiedad | Valor |
|---|---|
| Muestras (filas) | **19 200** |
| Clases (acordes) | **48** = 12 fundamentales × 4 calidades |
| Calidades | `maj` (mayor), `min` (menor), `dim` (disminuido), `dom7` (7ª de dominante) |
| Features | **12** (`pc_C` … `pc_B`, chroma normalizado L2) |
| Balance | 400 muestras por clase (perfectamente balanceado) |
| Semilla | 42 (reproducible: misma semilla ⇒ mismo dataset) |

**Esquema de columnas:**

```
pc_C, pc_C#, pc_D, pc_D#, pc_E, pc_F, pc_F#, pc_G, pc_G#, pc_A, pc_A#, pc_B,  root, quality, label
└──────────────── 12 features chroma (entrada del modelo) ───────────────┘   └─ metadatos / etiqueta ─┘
```

**Ejemplo de filas (un Do mayor — notar la energía alta en C, E, G):**

```
pc_C ,pc_C#,pc_D ,...,pc_E ,...,pc_G ,...   root,quality,label
0.664,0.016,0.018,...,0.656,...,0.202,...   C   ,maj    ,C:maj
0.526,0.000,0.108,...,0.480,...,0.669,...   C   ,maj    ,C:maj
```

## 4. El modelo

- **Algoritmo:** `RandomForestClassifier` (scikit-learn) — 200 árboles,
  profundidad máx. 16. Robusto, no requiere escalado, e interpretable vía
  *feature importances*. (Es intercambiable: un MLP / red neuronal o un export
  a **TensorFlow Lite** para on-device encajan en el mismo pipeline.)
- **Split:** 80 % entrenamiento / 20 % prueba, estratificado por clase.
- **Validación:** además, 5-fold cross-validation sobre el set de entrenamiento.

## 5. Resultados

| Métrica | Valor |
|---|---|
| **Accuracy (test)** | **0.863** |
| **F1-macro (test)** | **0.863** |
| **CV 5-fold (accuracy)** | **0.856 ± 0.005** |
| Baseline aleatorio (48 clases) | ~0.021 |

Artefactos generados en [`artifacts/`](artifacts/):

- `metrics.json` — métricas completas + F1 por clase + importancia de features.
- `confusion_matrix.png` — matriz de confusión del set de prueba.
- `classes.json` — las 48 clases en el orden del modelo.
- `chord_model.joblib` — modelo entrenado (se regenera con `python train.py`).

## 6. Las confusiones tienen sentido musical (esto es lo bueno)

El demo de inferencia (`predict_demo.py`) muestra que los errores **no son
aleatorios**, sino musicalmente lógicos:

- **Acordes disminuidos** (`dim`) son **simétricos** (apilan terceras menores) ⇒
  un B° y un F° comparten notas y se confunden. El modelo refleja esa
  ambigüedad inherente.
- **G:dom7** se confunde con **B:dim**: G7 = G-B-D-**F**, y B° = B-D-**F** ⇒
  comparten 3 de 4 notas.
- **Relativos mayor/menor** (p. ej. C:maj ↔ A:min) comparten dos notas.

Un modelo que se equivoca *así* es señal de que aprendió la estructura armónica
real, no de que memorizó ruido.

## 7. Reproducir desde cero

```bash
# 1) entorno
python -m venv .venv
.venv\Scripts\activate            # Windows  (o: source .venv/bin/activate)
pip install -r requirements.txt

# 2) generar el dataset sintético  -> data/chords_dataset.csv
python generate_dataset.py

# 3) entrenar y evaluar            -> artifacts/*
python train.py

# 4) demo de inferencia en vivo
python predict_demo.py
```

## 8. Estructura

```
ml/chord_detector/
├── README.md                 # este archivo
├── requirements.txt          # numpy, scikit-learn, pandas, matplotlib, joblib
├── generate_dataset.py       # generador del dataset SINTÉTICO (modelo físico)
├── train.py                  # entrenamiento + métricas + matriz de confusión
├── predict_demo.py           # inferencia de ejemplo (5 acordes)
├── data/
│   └── chords_dataset.csv     # 19 200 muestras × (12 features + etiqueta)
└── artifacts/
    ├── chord_model.joblib     # modelo entrenado
    ├── metrics.json           # métricas
    ├── classes.json           # clases
    └── confusion_matrix.png   # matriz de confusión
```
