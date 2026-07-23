"""
train.py
========
Entrena el modelo de **detección de acordes** (HU-19) sobre el dataset
sintético generado por ``generate_dataset.py``.

Modelo: ``RandomForestClassifier`` de scikit-learn. Se elige porque es
robusto, no necesita escalado, da *feature importances* interpretables y
entrena en segundos sobre ~19k muestras. (El clasificador es intercambiable:
un MLP o un export a TensorFlow Lite encajan en el mismo pipeline.)

Genera en ``artifacts/``:
  * ``chord_model.joblib``     -> modelo entrenado, listo para inferencia
  * ``metrics.json``           -> accuracy, F1 macro, CV, reporte por clase
  * ``confusion_matrix.png``   -> matriz de confusión del set de prueba
  * ``classes.json``           -> orden de las clases del modelo

Ejecutar:  ``python train.py``
"""
from __future__ import annotations

import json
import os

import joblib
import matplotlib

matplotlib.use("Agg")  # backend sin ventana (guarda PNG)
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)
from sklearn.model_selection import cross_val_score, train_test_split

SEED = 42
HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "data", "chords_dataset.csv")
ART = os.path.join(HERE, "artifacts")
PITCH_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
FEATURES = [f"pc_{n}" for n in PITCH_NAMES]


def main() -> None:
    os.makedirs(ART, exist_ok=True)
    if not os.path.exists(CSV):
        raise SystemExit("Falta el dataset. Corré primero: python generate_dataset.py")

    df = pd.read_csv(CSV)
    X = df[FEATURES].to_numpy()
    y = df["label"].to_numpy()
    n_classes = len(np.unique(y))
    print(f"[info] Dataset: {len(df)} muestras, {len(FEATURES)} features, {n_classes} clases")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.20, random_state=SEED, stratify=y
    )

    clf = RandomForestClassifier(
        n_estimators=200, max_depth=16, min_samples_leaf=2,
        n_jobs=-1, random_state=SEED
    )
    print("[info] Entrenando RandomForest (300 árboles)...")
    clf.fit(X_train, y_train)

    y_pred = clf.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    f1m = f1_score(y_test, y_pred, average="macro")

    print("[info] Validación cruzada 5-fold (sobre train)...")
    cv = cross_val_score(clf, X_train, y_train, cv=5, scoring="accuracy", n_jobs=-1)

    report = classification_report(y_test, y_pred, output_dict=True, zero_division=0)

    # ----- guardar modelo + metadatos --------------------------------------
    joblib.dump(clf, os.path.join(ART, "chord_model.joblib"), compress=3)
    with open(os.path.join(ART, "classes.json"), "w", encoding="utf-8") as fh:
        json.dump(list(clf.classes_), fh, ensure_ascii=False, indent=2)

    metrics = {
        "model": "RandomForestClassifier(n_estimators=300)",
        "n_samples": int(len(df)),
        "n_classes": int(n_classes),
        "n_features": len(FEATURES),
        "test_accuracy": round(float(acc), 4),
        "test_f1_macro": round(float(f1m), 4),
        "cv5_accuracy_mean": round(float(cv.mean()), 4),
        "cv5_accuracy_std": round(float(cv.std()), 4),
        "feature_importance": {
            f: round(float(i), 4) for f, i in zip(FEATURES, clf.feature_importances_)
        },
        "per_class_f1": {
            k: round(float(v["f1-score"]), 3)
            for k, v in report.items()
            if k not in ("accuracy", "macro avg", "weighted avg")
        },
    }
    with open(os.path.join(ART, "metrics.json"), "w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    # ----- matriz de confusión (PNG) ---------------------------------------
    labels = list(clf.classes_)
    cm = confusion_matrix(y_test, y_pred, labels=labels)
    fig, ax = plt.subplots(figsize=(11, 9))
    im = ax.imshow(cm, cmap="viridis")
    ax.set_title(f"Matriz de confusión — acordes ({n_classes} clases)\nAccuracy test = {acc:.3f}")
    ax.set_xlabel("Predicho")
    ax.set_ylabel("Real")
    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    if n_classes <= 24:  # etiquetas legibles solo si no son demasiadas
        ax.set_xticks(range(n_classes))
        ax.set_yticks(range(n_classes))
        ax.set_xticklabels(labels, rotation=90, fontsize=7)
        ax.set_yticklabels(labels, fontsize=7)
    fig.tight_layout()
    fig.savefig(os.path.join(ART, "confusion_matrix.png"), dpi=130)

    # ----- resumen en consola ----------------------------------------------
    print("\n================  RESULTADOS  ================")
    print(f"  Accuracy (test) ........ {acc:.4f}")
    print(f"  F1 macro (test) ........ {f1m:.4f}")
    print(f"  CV 5-fold (train) ...... {cv.mean():.4f} ± {cv.std():.4f}")
    print(f"  Artefactos en .......... {ART}")
    print("==============================================")


if __name__ == "__main__":
    main()
