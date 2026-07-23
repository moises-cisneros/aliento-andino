"""
semantic_faq.py
===============
Prototipo (y banco de pruebas) del **asistente FAQ semántico OFFLINE** de Vivi.

Implementa un *embedder liviano* basado en **hashing de n-gramas** (feature
hashing) + similitud coseno. La gracia: es **determinista y sin modelo**, así
que el MISMO algoritmo corre idéntico en Python (este archivo) y en Dart
(`mobile/.../offline/lightweight_embedder.dart`) ⇒ mismo espacio vectorial,
100% offline, anda en cualquier celular.

Captura reformulaciones porque mezcla unigramas de palabra, n-gramas de
carácter (toleran typos / variaciones morfológicas) y bigramas de palabra.

Interfaz `Embedder` intercambiable: el día de mañana se reemplaza por un
MiniLM-TFLite (~30 MB) sin tocar el resto del pipeline.

Ejecutar:  python semantic_faq.py     (corre la evaluación con preguntas reformuladas)
"""
from __future__ import annotations

import json
import math
import os
from dataclasses import dataclass

DIM = 1024  # dimensión del vector (potencia de 2 -> índice por máscara de bits)

# Mapa de acentos -> base (debe ser IDÉNTICO en Dart)
_ACCENTS = str.maketrans("áéíóúüñ", "aeiouun")

HERE = os.path.dirname(os.path.abspath(__file__))
FAQ_PATH = os.path.normpath(
    os.path.join(HERE, "..", "..", "mobile", "assets", "faq", "pianovision_faq.json")
)


def normalize(text: str) -> str:
    text = text.lower().translate(_ACCENTS)
    out = []
    for ch in text:
        out.append(ch if (ch.isalnum() and ch.isascii()) else " ")
    return " ".join("".join(out).split())


def fnv1a(s: str) -> int:
    """FNV-1a 32-bit sobre los bytes ASCII de `s` (idéntico en Dart)."""
    h = 0x811C9DC5
    for b in s.encode("ascii", "ignore"):
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def features(text: str) -> list[str]:
    toks = normalize(text).split()
    feats: list[str] = []
    for tok in toks:
        feats.append("w:" + tok)                 # unigrama de palabra
        padded = "^" + tok + "$"
        for n in (3, 4):                         # n-gramas de carácter
            for i in range(len(padded) - n + 1):
                feats.append("c:" + padded[i:i + n])
    for i in range(len(toks) - 1):               # bigramas de palabra
        feats.append("b:" + toks[i] + "_" + toks[i + 1])
    return feats


# Peso por tipo de feature: las palabras son más semánticas que los
# n-gramas de carácter (que aportan tolerancia a typos / morfología).
_WEIGHTS = {"w": 2.2, "b": 2.2, "c": 1.0}


def embed(text: str) -> list[float]:
    vec = [0.0] * DIM
    for f in features(text):
        w = _WEIGHTS[f[0]]
        h = fnv1a(f)
        idx = h & (DIM - 1)                      # índice (bits bajos)
        sign = 1.0 if ((h >> 16) & 1) == 0 else -1.0
        vec[idx] += sign * w
    norm = math.sqrt(sum(v * v for v in vec))
    if norm > 0:
        vec = [v / norm for v in vec]
    return vec


def cosine(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b))      # ambos ya normalizados L2


@dataclass
class Entry:
    id: str
    answer: str
    action: dict | None
    phrase_vecs: list[list[float]]


class SemanticFaq:
    def __init__(self, faq_path: str = FAQ_PATH):
        with open(faq_path, encoding="utf-8") as fh:
            data = json.load(fh)
        self.entries: list[Entry] = []
        for e in data["entries"]:
            vecs = [embed(p) for p in e["q"]]
            self.entries.append(
                Entry(e["id"], e["a"], e.get("action"), vecs)
            )

    def search(self, query: str) -> tuple[Entry, float]:
        qv = embed(query)
        best, best_score = self.entries[0], -1.0
        for ent in self.entries:
            score = max(cosine(qv, pv) for pv in ent.phrase_vecs)
            if score > best_score:
                best, best_score = ent, score
        return best, best_score


# --------------------------------------------------------------------------- #
# Banco de pruebas: preguntas REFORMULADAS (distintas a las del FAQ) -> id esperado
# --------------------------------------------------------------------------- #
TESTS = [
    ("necesito hacerme una cuenta nueva", "registro"),
    ("se me olvido la clave, no entro", "recuperar_password"),
    ("donde miro mi puntaje y mis sesiones", "progreso"),
    ("como pongo el tempo mas lento para practicar", "modo_entrenamiento"),
    ("quiero guardar esta cancion para despues", "guardar_leccion"),
    ("que hago para que la gente me siga", "seguir_usuarios"),
    ("donde cambio mi foto y mi biografia", "editar_perfil"),
    ("se puede practicar sin wifi", "modo_offline"),
    ("en que puesto del ranking voy", "rankings"),
    ("la camara revisa la posicion de mis manos", "postura_manos"),
    ("oye vivi que cosas sabes hacer", "que_es_vivi"),
    ("como activo los recordatorios", "notificaciones"),
    ("para que me sirven las medallas", "logros"),
    ("la app escucha lo que toco y lo reconoce", "deteccion_acordes"),
    ("como subo una publicacion a la comunidad", "crear_publicacion"),
    ("donde encuentro canciones faciles para empezar", "explorar_lecciones"),
]


def main() -> None:
    faq = SemanticFaq()
    print(f"FAQ: {len(faq.entries)} entradas  |  DIM={DIM}\n")
    ok = 0
    scores_hit, scores_miss = [], []
    print(f"{'consulta reformulada':<46} {'esperado':<22} {'predicho':<22} score  ok")
    print("-" * 104)
    for q, expected in TESTS:
        ent, score = faq.search(q)
        hit = ent.id == expected
        ok += hit
        (scores_hit if hit else scores_miss).append(score)
        print(f"{q:<46} {expected:<22} {ent.id:<22} {score:5.3f}  {'OK' if hit else 'X'}")
    print("-" * 104)
    print(f"Top-1 accuracy: {ok}/{len(TESTS)} = {ok/len(TESTS):.0%}")
    if scores_hit:
        print(f"Score aciertos : min={min(scores_hit):.3f}  mediana={sorted(scores_hit)[len(scores_hit)//2]:.3f}  max={max(scores_hit):.3f}")
    if scores_miss:
        print(f"Score fallos   : {[round(s,3) for s in scores_miss]}")
    # también: ¿qué score da una pregunta TOTALMENTE fuera de tema? (para umbral)
    off, off_s = faq.search("cual es la capital de francia y el precio del dolar")
    print(f"Pregunta fuera de tema -> {off.id} (score {off_s:.3f})  [debería quedar por debajo del umbral]")


if __name__ == "__main__":
    main()
