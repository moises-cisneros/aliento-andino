"""
generate_dataset.py
===================
Generador del **dataset sintético** para el modelo de *Detección de acordes
mediante IA* (HU-19) de PianoVision AI.

Cada muestra es un vector **chroma** (Pitch Class Profile, PCP) de 12
dimensiones: la energía relativa de cada una de las 12 clases de altura
musical (C, C#, D, ... B). El chroma es el descriptor estándar de la
literatura de *Music Information Retrieval* (MIR) para reconocer acordes,
porque colapsa todas las octavas en 12 bins y es robusto al timbre.

¿Por qué datos sintéticos? No existe un corpus público etiquetado de
acordes de piano ya convertidos a chroma. En lugar de grabar miles de
acordes a mano, generamos los vectores con un **modelo físico** simple del
sonido de un piano:

  * cada nota del acorde aporta su frecuencia fundamental, y
  * sus **armónicos** (2º armónico = octava, 3º = quinta justa,
    5º = tercera mayor, ...), que en un piano real "ensucian" el chroma.
  * se suma ruido de fondo, resonancia simpática y ruido de medición.

Esto produce vectores realistas y, sobre todo, con **confusiones plausibles**
(p. ej. un Do mayor y su relativo La menor comparten dos notas), que es lo
que obliga al modelo a aprender de verdad la estructura del acorde.

Salida: ``data/chords_dataset.csv``  (un encabezado + N filas).
Ejecutar:  ``python generate_dataset.py``
"""
from __future__ import annotations

import csv
import os

import numpy as np

# --------------------------------------------------------------------------- #
# Configuración (reproducible: misma semilla -> mismo dataset)
# --------------------------------------------------------------------------- #
SEED = 42
N_PER_CLASS = 400          # muestras por clase  ->  48 clases x 400 = 19 200 filas
BG_NOISE = 0.12            # energía de fondo (silencio / ruido ambiente)
MEAS_NOISE = 0.11          # ruido gaussiano de medición del micrófono
DROP_PROB = 0.13           # prob. de que una nota del acorde suene muy débil (mal pulsada)
CONTAM_PROB = 0.24         # prob. de "fuga" de un 2º acorde (pedal / transición)
CONTAM_GAIN = (0.18, 0.42) # rango de energía de esa contaminación
ROUND = 5                  # decimales guardados en el CSV

# Armónicos del piano:  armónico -> (semitonos por encima de la nota, peso medio)
HARMONIC_WEIGHTS = {
    2: (0, 0.55),   # 2º armónico  -> octava            -> misma clase de altura
    3: (7, 0.35),   # 3º armónico  -> quinta justa
    4: (0, 0.22),   # 4º armónico  -> dos octavas
    5: (4, 0.18),   # 5º armónico  -> tercera mayor (17ª)
    6: (7, 0.12),   # 6º armónico  -> quinta
}

PITCH_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# Calidad del acorde -> intervalos en semitonos desde la fundamental
QUALITIES = {
    "maj": [0, 4, 7],        # mayor          (1 - 3 - 5)
    "min": [0, 3, 7],        # menor          (1 - b3 - 5)
    "dim": [0, 3, 6],        # disminuido     (1 - b3 - b5)
    "dom7": [0, 4, 7, 10],   # 7ª de dominante(1 - 3 - 5 - b7)
}

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_CSV = os.path.join(HERE, "data", "chords_dataset.csv")


def _add_notes(chroma: np.ndarray, notes: list[int], gain_lo: float, gain_hi: float,
               rng: np.random.Generator, allow_drop: bool = False) -> None:
    """Suma a `chroma` la energía de un conjunto de notas + sus armónicos."""
    for n in notes:
        gain = rng.uniform(gain_lo, gain_hi)           # "voicing": cada nota suena distinto
        if allow_drop and rng.random() < DROP_PROB:    # nota mal pulsada / casi inaudible
            gain *= rng.uniform(0.05, 0.30)
        chroma[n] += gain
        for _h, (semi, w) in HARMONIC_WEIGHTS.items():  # aporte de los armónicos
            chroma[(n + semi) % 12] += gain * w * rng.uniform(0.7, 1.3)


def synth_chroma(root: int, intervals: list[int], rng: np.random.Generator) -> np.ndarray:
    """Sintetiza un vector chroma (12,) para un acorde dado, con ruido realista."""
    chroma = rng.uniform(0.0, BG_NOISE, 12)            # piso de energía
    notes = [(root + i) % 12 for i in intervals]

    _add_notes(chroma, notes, 0.55, 1.0, rng, allow_drop=True)

    # Fuga de un 2º acorde (resonancia del pedal o transición entre acordes):
    # la causa nº1 de confusión real en reconocimiento de acordes.
    if rng.random() < CONTAM_PROB:
        other_root = int(rng.integers(0, 12))
        other_q = list(QUALITIES.values())[int(rng.integers(0, len(QUALITIES)))]
        other_notes = [(other_root + i) % 12 for i in other_q]
        _add_notes(chroma, other_notes, *CONTAM_GAIN, rng)

    chroma += rng.normal(0.0, MEAS_NOISE, 12)          # ruido de medición
    chroma = np.clip(chroma, 0.0, None)

    norm = np.linalg.norm(chroma)                      # normalización L2 (como en MIR real)
    if norm > 0:
        chroma /= norm
    return chroma


def main() -> None:
    rng = np.random.default_rng(SEED)
    os.makedirs(os.path.dirname(OUT_CSV), exist_ok=True)

    header = [f"pc_{name}" for name in PITCH_NAMES] + ["root", "quality", "label"]
    rows = 0
    with open(OUT_CSV, "w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(header)
        for root in range(12):
            root_name = PITCH_NAMES[root]
            for quality, intervals in QUALITIES.items():
                label = f"{root_name}:{quality}"
                for _ in range(N_PER_CLASS):
                    chroma = synth_chroma(root, intervals, rng)
                    writer.writerow(
                        [round(float(v), ROUND) for v in chroma]
                        + [root_name, quality, label]
                    )
                    rows += 1

    n_classes = 12 * len(QUALITIES)
    print(f"[OK] Dataset escrito en: {OUT_CSV}")
    print(f"     Muestras: {rows}  |  Clases: {n_classes}  |  Features: 12 (chroma)")
    print(f"     Calidades: {', '.join(QUALITIES)}  |  Semilla: {SEED}")


if __name__ == "__main__":
    main()
