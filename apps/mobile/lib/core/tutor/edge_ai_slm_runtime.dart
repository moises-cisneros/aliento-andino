import 'dart:async';
import 'dart:convert';

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
  static const int maxOutputTokens = 90;
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
    final session = await _model.openSession(temperature: 0.4, topK: 30);
    try {
      await session.addQueryChunk(Message(text: prompt, isUser: true));
      final reply = StringBuffer();
      var tokens = 0;
      var capped = false;
      await for (final token in session.getResponseAsync()) {
        reply.write(token);
        // MediaPipe ignores maxOutputTokens: bound the reply ourselves.
        if (++tokens >= SlmModelConfig.maxOutputTokens) {
          capped = true;
          await session.stopGeneration();
          break;
        }
      }
      return sanitizeSlmReply(reply.toString(), truncated: capped);
    } finally {
      await session.close();
    }
  }

  @override
  Future<void> close() => _model.close();
}

/// Repairs UTF-8 sequences that the engine surfaced as Latin-1 (`Ã©` -> `é`).
///
/// Byte-level BPE tokens can split a multi-byte character across tokens; the
/// plugin then decodes each half separately. Only `Â`/`Ã` + continuation
/// bytes are touched, so already-correct text is left alone.
String repairMojibake(String text) {
  return text.replaceAllMapped(RegExp('[ÂÃ][\u0080-¿]'), (m) {
    try {
      return utf8.decode(latin1.encode(m[0]!));
    } on FormatException {
      return m[0]!;
    }
  });
}

/// Turns raw model output into short plain text for the feedback card:
/// repairs encoding, strips markdown/list markers and caps the length at a
/// sentence boundary.
String sanitizeSlmReply(
  String raw, {
  int maxWords = 60,
  bool truncated = false,
}) {
  var text = repairMojibake(raw)
      // Some engines emit newlines as the two characters `\n`.
      .replaceAll(r'\n', ' ')
      .replaceAll(RegExp(r'[*#`>]+'), '')
      .replaceAll(RegExp(r'^\s*(\d+[.)]|[-•])\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\s*\n+\s*'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  if (truncated && !RegExp(r'[.!?]$').hasMatch(text)) {
    // The reply was cut by the token cap: drop the dangling sentence.
    final stop = text.lastIndexOf(RegExp(r'[.!?]'));
    text = stop > 0 ? text.substring(0, stop + 1) : '$text…';
  }

  final words = text.split(' ');
  if (words.length <= maxWords) return text;

  final clipped = words.take(maxWords).join(' ');
  final lastStop = clipped.lastIndexOf(RegExp(r'[.!?]'));
  if (lastStop > clipped.length ~/ 2) {
    return clipped.substring(0, lastStop + 1);
  }
  return '$clipped…';
}
