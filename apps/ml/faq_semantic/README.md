# 🤖 Vivi híbrido — Asistente offline (FAQ semántico) + Gemini en la nube

Arquitectura **por capas (router)** del asistente Vivi de Aliento Andino: Vivi
**siempre responde algo** (incluso sin internet) y **da lo mejor cuando hay
conexión** (Gemini/Vertex para lo avanzado).

```
        ┌─────────────────────────── pregunta del usuario ───────────────────────────┐
        │                                                                             │
   ¿hay internet?                                                                     │
        │                                                                             │
   ┌────┴─────┐                                                                       │
   │   SÍ     │   →  ☁️  Capa 3: Gemini/Vertex (agente con function calling,          │
   │          │          navega/resalta, razona, feedback avanzado)                  │
   │          │          └─ si la nube falla → cae a la capa offline                 │
   └──────────┘                                                                       │
   ┌──────────┐                                                                       │
   │   NO     │   →  📴  Capa 2: FAQ semántico OFFLINE (este proyecto)                │
   │          │          embeddings livianos + coseno sobre una base de conocimiento  │
   │          │          └─ sin match confiable → mensaje guía de respaldo            │
   └──────────┘                                                                       │
                                                                                      │
   🎵  Capa 1 (transversal, ya existente): IA on-device de MÚSICA                     │
       (detección de notas monofónicas YIN/SPICE en el cliente móvil) — también offline ←────┘
```

## ¿Por qué así? (la decisión)

"Responder _cualquier_ pregunta offline" exigiría un **LLM dentro del teléfono**
(Gemma/Gemini Nano): 500 MB–1.5 GB, mucha RAM, solo gama media/alta, y más
lento. Los apps de producción **no** hacen eso: usan un **router** que resuelve
lo común on-device y **escala a la nube** lo complejo. Eso es lo implementado.

## La capa offline (capa 2) — cómo funciona

No es un LLM: es **recuperación semántica** sobre una FAQ curada.

1. **Base de conocimiento**: [`mobile/assets/faq/aliento_andino_faq.json`](../../mobile/assets/faq/aliento_andino_faq.json)
   — 24 entradas (registro, guardar lección, rankings, progreso, modo offline,
   perfil, detección de acordes, postura…). Cada entrada tiene varias
   **formulaciones**, una **respuesta** y, opcional, una **acción de UI**
   (`navigate_to` / `highlight_element`) que reusa el ejecutor del tutor.
2. **Embedder liviano** (`LightweightEmbedder`): convierte texto en un vector de
   1024 dims con **hashing de n-gramas** (unigramas/bigramas de palabra +
   n-gramas de carácter, FNV-1a, normalización L2). **Determinista, sin modelo,
   0 MB extra**, anda en cualquier celular. El **mismo algoritmo** está en
   Python (`semantic_faq.py`) y en Dart (`lightweight_embedder.dart`) ⇒ mismo
   espacio vectorial.
3. **Búsqueda**: se embebe la pregunta y se toma el **coseno** máximo contra las
   formulaciones de cada entrada. Si el mejor `score ≥ 0.32` → respuesta (+
   acción). Si no → mensaje de respaldo.

### Interfaz intercambiable (upgrade a TFLite) — VERIFICADO ✅

Existe una **interfaz real** `Embedder` (`embedder.dart`): `LightweightEmbedder`
la implementa. Para el upgrade transformer ya está el **slot**
`TfliteMiniLmEmbedder` (mismo `Embedder`, dim 384). Se enchufa **sin tocar nada
más** —ni el router, ni el coseno, ni el umbral, ni el `OfflineFaqAssistant`:

```dart
final faq = OfflineFaqAssistant(embedder: TfliteMiniLmEmbedder());
```

Esto **no es promesa**: el test `offline_faq_assistant_test.dart` corre el
asistente con un `Embedder` alternativo de juguete (prueba que depende solo de
la interfaz) y verifica que el slot TFLite type-checea y encaja en el
constructor. Para activarlo de verdad faltan solo el binario `minilm.tflite` +
`vocab.txt` y la dependencia `tflite_flutter` (pasos documentados dentro de
`tflite_minilm_embedder.dart`).

## Resultados (verificado)

- **Prototipo Python** (`python semantic_faq.py`): **16/16 (100%)** de
  reformulaciones difíciles recuperadas bien; pregunta fuera de tema = 0.233
  (rechazada). De ahí salió el umbral **0.32**.
- **Port en Dart** (`flutter test test/features/tutor/offline_faq_assistant_test.dart`):
  **13/13 tests** ✅ — mismos resultados que el prototipo, acciones incluidas.
- **`flutter analyze`**: 0 errores en los archivos nuevos.

## Archivos

| Capa                            | Archivo                                                         |
| ------------------------------- | --------------------------------------------------------------- |
| Base de conocimiento            | `mobile/assets/faq/aliento_andino_faq.json`                     |
| Interfaz `Embedder` + coseno    | `mobile/lib/features/tutor/offline/embedder.dart`               |
| Embedder liviano (default)      | `mobile/lib/features/tutor/offline/lightweight_embedder.dart`   |
| Slot TFLite (upgrade)           | `mobile/lib/features/tutor/offline/tflite_minilm_embedder.dart` |
| Asistente offline (Dart)        | `mobile/lib/features/tutor/offline/offline_faq_assistant.dart`  |
| Router (nube/offline)           | `mobile/lib/features/tutor/data/tutor_repository.dart`          |
| Tests (Dart)                    | `mobile/test/features/tutor/offline_faq_assistant_test.dart`    |
| Prototipo + evaluación (Python) | `ml/faq_semantic/semantic_faq.py`                               |

## Probar

```bash
# Prototipo + evaluación de retrieval (Python, sin dependencias externas)
python ml/faq_semantic/semantic_faq.py

# Pruebas del cerebro offline en Dart (no requiere dispositivo)
cd mobile && flutter test test/features/tutor/offline_faq_assistant_test.dart

# En vivo: abrí la app, poné el celular en MODO AVIÓN y preguntale a Vivi
# "¿cómo guardo una lección?" → responde sin internet (y puede navegar/resaltar).
```
