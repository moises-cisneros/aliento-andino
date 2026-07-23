import 'embedder.dart';

/// **Slot listo para el upgrade a embeddings transformer** (MiniLM en TFLite).
///
/// Implementa la MISMA interfaz [Embedder] que [LightweightEmbedder], así que
/// se enchufa directo en el asistente **sin tocar nada más**:
///
/// ```dart
/// final faq = OfflineFaqAssistant(embedder: TfliteMiniLmEmbedder());
/// ```
///
/// Esto demuestra que el slot es real: esta clase YA es un [Embedder] válido y
/// el `OfflineFaqAssistant` la acepta. Lo único que falta para activarlo es
/// material externo (el binario del modelo + una dependencia), por eso [embed]
/// lanza [UnimplementedError] con los pasos.
///
/// ### Pasos para activarlo (≈30 MB, más "inteligente")
/// 1. `flutter pub add tflite_flutter` (runtime de TFLite para Flutter).
/// 2. Bajar `all-MiniLM-L6-v2` exportado a TFLite + su `vocab.txt`
///    (p. ej. con `optimum`/`tensorflow` desde el modelo de HuggingFace) y
///    declararlos como assets: `assets/models/minilm.tflite`, `.../vocab.txt`.
/// 3. En el constructor: cargar el `Interpreter.fromAsset(...)` y el vocab.
/// 4. En [embed]:
///    a. **Tokenizar** con WordPiece usando el vocab (greedy longest-match).
///    b. Construir los tensores `input_ids` / `attention_mask`.
///    c. `interpreter.run(...)` → embeddings por token (384 dims).
///    d. **Mean-pooling** con la máscara + **normalización L2**.
/// 5. Regenerar los vectores del FAQ con el MISMO modelo para que vivan en el
///    mismo espacio (el `OfflineFaqAssistant` ya los vectoriza al cargar, así
///    que basta cambiar el embedder: quedan consistentes automáticamente).
class TfliteMiniLmEmbedder implements Embedder {
  const TfliteMiniLmEmbedder();

  /// all-MiniLM-L6-v2 produce vectores de 384 dimensiones.
  @override
  int get dim => 384;

  @override
  List<double> embed(String text) {
    throw UnimplementedError(
      'TfliteMiniLmEmbedder es un slot: agregá la dependencia tflite_flutter '
      'y el modelo minilm.tflite + vocab.txt, e implementá la inferencia '
      '(ver pasos en el doc de la clase). La interfaz Embedder ya está lista.',
    );
  }
}
