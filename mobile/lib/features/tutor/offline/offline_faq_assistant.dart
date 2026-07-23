import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../data/tutor_repository.dart' show TutorAction;
import 'embedder.dart';
import 'lightweight_embedder.dart';

/// Resultado de una búsqueda en el FAQ.
class FaqMatch {
  final String id;
  final String answer;
  final TutorAction? action;
  final double score;
  const FaqMatch(this.id, this.answer, this.action, this.score);
}

class _FaqEntry {
  final String id;
  final String answer;
  final TutorAction? action;
  final List<List<double>> phraseVecs; // un vector por cada formulación
  _FaqEntry(this.id, this.answer, this.action, this.phraseVecs);
}

/// **Cerebro offline de Vivi**: busca en una base de conocimiento (FAQ) la
/// respuesta más parecida a la pregunta del usuario, usando embeddings
/// livianos ([LightweightEmbedder]) + similitud coseno. No necesita internet.
///
/// Carga perezosa: la FAQ se lee y se vectoriza la primera vez que se la usa
/// (es barato: ~140 frases) y queda en memoria.
class OfflineFaqAssistant {
  /// Umbral de confianza fijado empíricamente en el banco de pruebas de
  /// Python (aciertos ≥ 0.39; preguntas fuera de tema ≤ 0.23).
  static const double matchThreshold = 0.32;

  final String assetPath;
  final Embedder _embedder;
  List<_FaqEntry>? _entries;

  /// [embedder] es intercambiable: por defecto usa el [LightweightEmbedder]
  /// (n-gramas, 0 MB). Para el upgrade, pasá un `TfliteMiniLmEmbedder()`.
  OfflineFaqAssistant({
    Embedder? embedder,
    this.assetPath = 'assets/faq/pianovision_faq.json',
  }) : _embedder = embedder ?? const LightweightEmbedder();

  Future<void> _ensureReady() async {
    if (_entries != null) return;
    final raw = await rootBundle.loadString(assetPath);
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = <_FaqEntry>[];
    for (final e in (data['entries'] as List)) {
      final m = e as Map<String, dynamic>;
      final phrases = (m['q'] as List).cast<String>();
      final vecs = phrases.map(_embedder.embed).toList();
      TutorAction? action;
      if (m['action'] is Map) {
        final a = m['action'] as Map<String, dynamic>;
        action = TutorAction(
          tool: (a['tool'] as String?) ?? '',
          args: (a['args'] as Map<String, dynamic>?) ?? const {},
        );
      }
      list.add(_FaqEntry(m['id'] as String, m['a'] as String, action, vecs));
    }
    _entries = list;
  }

  /// Mejor coincidencia para [query]. El `score` es el coseno máximo contra
  /// todas las formulaciones de la entrada ganadora. Devuelve `null` solo si la
  /// FAQ no pudo cargarse.
  Future<FaqMatch?> bestMatch(String query) async {
    await _ensureReady();
    final entries = _entries;
    if (entries == null || entries.isEmpty) return null;

    final qv = _embedder.embed(query);
    _FaqEntry? best;
    var bestScore = -1.0;
    for (final ent in entries) {
      var s = -1.0;
      for (final pv in ent.phraseVecs) {
        final c = cosineSimilarity(qv, pv);
        if (c > s) s = c;
      }
      if (s > bestScore) {
        bestScore = s;
        best = ent;
      }
    }
    if (best == null) return null;
    return FaqMatch(best.id, best.answer, best.action, bestScore);
  }
}
