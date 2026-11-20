import 'dart:async';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/tutor/edge_ai_slm_runtime.dart';
import 'package:mobile/core/tutor/local_slm_engine.dart';
import 'package:mobile/core/tutor/tutor_prompt_builder.dart';

/// Where the model file lives and how it gets onto the device.
abstract class SlmModelStore {
  /// Identifier handed to [SlmRuntime.loadModel].
  String get modelRef;

  Future<bool> isInstalled();

  /// Downloads the model (one time). [onProgress] receives 0..100.
  Future<void> install({void Function(int percent)? onProgress});
}

/// [SlmModelStore] backed by `flutter_edge_ai`.
class EdgeAiModelStore implements SlmModelStore {
  @override
  String get modelRef => SlmModelConfig.url;

  @override
  Future<bool> isInstalled() async {
    await ensureEdgeAiInitialized();
    return FlutterEdgeAi.isModelInstalled(SlmModelConfig.fileName);
  }

  @override
  Future<void> install({void Function(int percent)? onProgress}) async {
    await ensureEdgeAiInitialized();
    final token = SlmModelConfig.huggingFaceToken;
    await FlutterEdgeAi.installModel(
          modelType: ModelType.qwen,
          fileType: ModelFileType.task,
        )
        .fromNetwork(SlmModelConfig.url, token: token.isEmpty ? null : token)
        .withProgress((percent) => onProgress?.call(percent))
        .install();
  }
}

/// On-device pedagogical tutor.
///
/// Generates practice feedback with the local SLM when the model has been
/// downloaded, and degrades to the deterministic [RuleBasedTutorFallback]
/// otherwise (no model, low RAM, timeout, inference error). It never starts a
/// large download by itself: [installModel] must be called explicitly.
class LocalTutorService {
  static final LocalTutorService instance = LocalTutorService();

  /// Budget for one generation on a phone CPU (the engine default is 3 s).
  /// Measured on an x86 emulator: ~30 s for a 120-token reply.
  static const Duration generationTimeout = Duration(seconds: 60);

  final SlmModelStore _store;
  final LocalSlmEngine Function() _engineFactory;
  final TutorPromptBuilder _promptBuilder;

  LocalSlmEngine? _engine;
  Future<LocalSlmEngine>? _engineLoading;

  LocalTutorService({
    SlmModelStore? store,
    LocalSlmEngine Function()? engineFactory,
    TutorPromptBuilder promptBuilder = const TutorPromptBuilder(),
  }) : _store = store ?? EdgeAiModelStore(),
       _engineFactory =
           engineFactory ??
           (() => LocalSlmEngine(
             runtime: EdgeAiSlmRuntime(),
             generationTimeout: generationTimeout,
           )),
       _promptBuilder = promptBuilder;

  /// Whether the model file is already on the device.
  Future<bool> isModelInstalled() async {
    try {
      return await _store.isInstalled();
    } catch (_) {
      return false;
    }
  }

  /// Downloads the model and drops any engine cached without it.
  Future<void> installModel({void Function(int percent)? onProgress}) async {
    await _store.install(onProgress: onProgress);
    _engine?.dispose();
    _engine = null;
    _engineLoading = null;
  }

  /// Feedback for a finished practice. Never throws: any failure falls back to
  /// the deterministic rules so the UI always has text to show.
  Future<String> generateFeedback(
    PracticeSummary summary,
    InstrumentType instrument,
  ) async {
    final prompt = _promptBuilder.buildPrompt(summary, instrument);
    try {
      final engine = await _readyEngine();
      return await engine.generatePedagogicalFeedback(prompt: prompt);
    } catch (_) {
      return const RuleBasedTutorFallback().generateFeedback(prompt);
    }
  }

  /// `true` when the model is loaded and ready to generate.
  bool get isUsingModel => _engine?.isModelInitialized ?? false;

  /// `true` when the last feedback text came from the model (not the rules
  /// fallback after a timeout, an error or a missing model).
  bool get lastFeedbackFromModel => _engine?.lastFeedbackFromModel ?? false;

  Future<LocalSlmEngine> _readyEngine() {
    final cached = _engine;
    if (cached != null) return Future.value(cached);
    return _engineLoading ??= _createEngine();
  }

  Future<LocalSlmEngine> _createEngine() async {
    final engine = _engineFactory();
    if (await isModelInstalled()) {
      await engine.initializeModel(modelPath: _store.modelRef);
    }
    _engine = engine;
    _engineLoading = null;
    return engine;
  }

  /// Releases the model from memory.
  void dispose() {
    _engine?.dispose();
    _engine = null;
    _engineLoading = null;
  }
}
