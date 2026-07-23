import 'dart:math' as math;

import 'embedder.dart';

/// Embedder **liviano y determinista** basado en *hashing de n-gramas* (feature
/// hashing). Es la implementación **por defecto** de [Embedder]: no usa modelo
/// ni internet y corre en cualquier celular.
///
/// El algoritmo es **idéntico** al del prototipo en Python
/// (`ml/faq_semantic/semantic_faq.py`), por lo que ambos producen el **mismo
/// espacio vectorial** (mismos hashes, mismos pesos, misma normalización).
///
/// Para pasar a embeddings *transformer* (MiniLM en TFLite, ~30 MB) se crea
/// otra clase que implemente [Embedder] (ver `tflite_minilm_embedder.dart`) y
/// se la inyecta en [OfflineFaqAssistant]; nada más cambia.
class LightweightEmbedder implements Embedder {
  const LightweightEmbedder();

  /// Dimensión del vector (potencia de 2 ⇒ índice por máscara de bits).
  static const int kDim = 1024;

  @override
  int get dim => kDim;

  /// Peso por tipo de feature: las palabras pesan más que los n-gramas de
  /// carácter (estos aportan tolerancia a typos / variaciones morfológicas).
  static const Map<String, double> _weights = {'w': 2.2, 'b': 2.2, 'c': 1.0};

  /// Acentos → letra base (debe coincidir con el mapa de Python).
  static const Map<String, String> _accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  /// Minúsculas, sin acentos, solo `[a-z0-9]` y espacios colapsados.
  static String normalize(String text) {
    var t = text.toLowerCase();
    _accents.forEach((k, v) => t = t.replaceAll(k, v));
    final sb = StringBuffer();
    for (final code in t.codeUnits) {
      final isLower = code >= 0x61 && code <= 0x7A; // a-z
      final isDigit = code >= 0x30 && code <= 0x39; // 0-9
      sb.writeCharCode((isLower || isDigit) ? code : 0x20); // resto → espacio
    }
    return sb
        .toString()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .join(' ');
  }

  /// FNV-1a de 32 bits sobre los bytes ASCII de [s] (idéntico a Python).
  static int _fnv1a(String s) {
    var h = 0x811C9DC5;
    for (final b in s.codeUnits) {
      // tras normalizar, todas las features son ASCII ⇒ codeUnits == bytes.
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  static List<String> _features(String text) {
    final toks = normalize(text).split(' ').where((s) => s.isNotEmpty).toList();
    final feats = <String>[];
    for (final tok in toks) {
      feats.add('w:$tok'); // unigrama de palabra
      final padded = '^$tok\$';
      for (final n in const [3, 4]) {
        // n-gramas de carácter
        for (var i = 0; i + n <= padded.length; i++) {
          feats.add('c:${padded.substring(i, i + n)}');
        }
      }
    }
    for (var i = 0; i + 1 < toks.length; i++) {
      feats.add('b:${toks[i]}_${toks[i + 1]}'); // bigrama de palabra
    }
    return feats;
  }

  @override
  List<double> embed(String text) {
    final vec = List<double>.filled(kDim, 0.0);
    for (final f in _features(text)) {
      final w = _weights[f[0]] ?? 1.0;
      final h = _fnv1a(f);
      final idx = h & (kDim - 1); // índice (bits bajos)
      final sign = ((h >> 16) & 1) == 0 ? 1.0 : -1.0;
      vec[idx] += sign * w;
    }
    var norm = 0.0;
    for (final v in vec) {
      norm += v * v;
    }
    norm = math.sqrt(norm);
    if (norm > 0) {
      for (var i = 0; i < kDim; i++) {
        vec[i] /= norm;
      }
    }
    return vec;
  }
}
