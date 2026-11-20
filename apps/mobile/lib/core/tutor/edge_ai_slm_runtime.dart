import 'dart:async';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';

import 'package:mobile/core/tutor/local_slm_engine.dart';

/// Default on-device model: Qwen2.5-0.5B-Instruct, int8, MediaPipe `.task`.
///
/// It is public (no Hugging Face token) and ~520 MB. Override it at build time
/// with `--dart-define=SLM_MODEL_URL=...` (and `HUGGINGFACE_TOKEN` for gated
/// repos such as Gemma 3 1B).
class SlmModelConfig {
  static const String url = String.fromEnvironment(
    'SLM_MODEL_URL',
    defaultValue:
        'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
  );

  static const String huggingFaceToken = String.fromEnvironment(
    'HUGGINGFACE_TOKEN',
  );

  /// File name the model is installed under (last URL segment).
  static String get fileName => Uri.parse(url).pathSegments.last;

  /// Context window handed to the engine.
  static const int contextTokens = 1024;

  /// Hard cap on generated tokens: advice must stay under ~50 words.
  static const int maxOutputTokens = 120;
}

/// Minimal text generator the runtime needs. Kept separate from the plugin so
/// the runtime is unit-testable without native code.
abstract class SlmGenerator {
  Future<String> generate(String prompt);
  Future<void> close();
}

/// Loads a [SlmGenerator] for an already installed model.
typedef SlmGeneratorLoader = Future<SlmGenerator> Function(String modelRef);

/// [SlmRuntime] backed by MediaPipe LLM Inference through `flutter_edge_ai`.
///
/// Everything runs on the device: the model file is downloaded once and then
/// inference needs no network.
class EdgeAiSlmRuntime implements SlmRuntime {
  final SlmGeneratorLoader _loader;
  SlmGenerator? _generator;

  EdgeAiSlmRuntime({SlmGeneratorLoader? loader})
    : _loader = loader ?? _loadWithEdgeAi;

  @override
  bool get isLoaded => _generator != null;

  @override
  Future<void> loadModel(String modelPath) async {
    await _generator?.close();
    _generator = await _loader(modelPath);
  }

  @override
  Future<String> generateResponse(String prompt) {
    final generator = _generator;
    if (generator == null) {
      throw StateError('El modelo SLM no está cargado.');
    }
    return generator.generate(prompt);
  }

  @override
  void dispose() {
    final generator = _generator;
    _generator = null;
    if (generator != null) unawaited(generator.close());
  }
}

bool _edgeAiInitialized = false;

/// Registers the MediaPipe engine once per process.
Future<void> ensureEdgeAiInitialized() async {
  if (_edgeAiInitialized) return;
  await FlutterEdgeAi.initialize(
    huggingFaceToken: SlmModelConfig.huggingFaceToken.isEmpty
        ? null
        : SlmModelConfig.huggingFaceToken,
    inferenceEngines: [MediaPipeEngine()],
  );
  _edgeAiInitialized = true;
}

Future<SlmGenerator> _loadWithEdgeAi(String modelRef) async {
  await ensureEdgeAiInitialized();
  final model = await FlutterEdgeAi.getActiveModel(
    maxTokens: SlmModelConfig.contextTokens,
    // CPU is the only backend that is safe for `.task` models on iOS.
    preferredBackend: PreferredBackend.cpu,
  );
  return _EdgeAiGenerator(model);
}

class _EdgeAiGenerator implements SlmGenerator {
  final InferenceModel _model;
  _EdgeAiGenerator(this._model);

  @override
  Future<String> generate(String prompt) async {
    final session = await _model.openSession(temperature: 0.7, topK: 40);
    try {
      await session.addQueryChunk(Message(text: prompt, isUser: true));
      final reply = StringBuffer();
      var tokens = 0;
      await for (final token in session.getResponseAsync()) {
        reply.write(token);
        // MediaPipe ignores maxOutputTokens: bound the reply ourselves.
        if (++tokens >= SlmModelConfig.maxOutputTokens) {
          await session.stopGeneration();
          break;
        }
      }
      return reply.toString();
    } finally {
      await session.close();
    }
  }

  @override
  Future<void> close() => _model.close();
}
