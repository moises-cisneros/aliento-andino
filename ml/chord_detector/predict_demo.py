"""
predict_demo.py
===============
Demostración de **inferencia** con el modelo entrenado: genera unos acordes
sintéticos de prueba, los pasa por el modelo y muestra la predicción con su
probabilidad (top-3). Sirve para enseñar en vivo que el modelo "escucha" un
chroma y devuelve el acorde.

Ejecutar:  ``python predict_demo.py``
"""
from __future__ import annotations

import os

import joblib
import numpy as np

from generate_dataset import PITCH_NAMES, QUALITIES, synth_chroma

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = os.path.join(HERE, "artifacts", "chord_model.joblib")

# Acordes de prueba (root_name, quality)
TEST_CHORDS = [
    ("C", "maj"),
    ("A", "min"),
    ("G", "dom7"),
    ("B", "dim"),
    ("F", "maj"),
]


def main() -> None:
    if not os.path.exists(MODEL):
        raise SystemExit("Falta el modelo. Corré primero: python train.py")
    clf = joblib.load(MODEL)
    rng = np.random.default_rng(123)  # semilla distinta a la del dataset

    print("Acorde real      ->  Predicción (top-3 con probabilidad)")
    print("-" * 62)
    ok = 0
    for root_name, quality in TEST_CHORDS:
        root = PITCH_NAMES.index(root_name)
        chroma = synth_chroma(root, QUALITIES[quality], rng).reshape(1, -1)
        proba = clf.predict_proba(chroma)[0]
        top = np.argsort(proba)[::-1][:3]
        pred = clf.classes_[top[0]]
        true = f"{root_name}:{quality}"
        ok += int(pred == true)
        top3 = "  ".join(f"{clf.classes_[i]} ({proba[i]*100:4.1f}%)" for i in top)
        mark = "OK " if pred == true else " X "
        print(f"[{mark}] {true:<12} ->  {top3}")

    print("-" * 62)
    print(f"Aciertos: {ok}/{len(TEST_CHORDS)}")


if __name__ == "__main__":
    main()
