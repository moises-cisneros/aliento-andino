/// Interfaz de **embedding intercambiable**.
///
/// Cualquier implementación convierte un texto en un vector (idealmente
/// L2-normalizado). Esto permite cambiar el "motor" del asistente offline
/// — del [LightweightEmbedder] por hashing de n-gramas a un MiniLM exportado
/// a TFLite — **sin tocar** el resto del pipeline (búsqueda, coseno, umbral,
/// router). El [OfflineFaqAssistant] depende solo de esta interfaz.
abstract interface class Embedder {
  /// Dimensión del vector que produce este embedder.
  int get dim;

  /// Vector L2-normalizado que representa [text].
  List<double> embed(String text);
}

/// Similitud coseno entre dos vectores ya normalizados L2 (= producto punto).
/// Es independiente del embedder concreto que los haya producido.
double cosineSimilarity(List<double> a, List<double> b) {
  var dot = 0.0;
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    dot += a[i] * b[i];
  }
  return dot;
}
