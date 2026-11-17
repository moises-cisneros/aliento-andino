import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/tutor/local_slm_engine.dart';

class MockSlmRuntime implements SlmRuntime {
  bool _isLoaded = false;
  Duration delay;
  String? mockResponse;
  bool shouldFailLoad;
  bool shouldFailGeneration;

  MockSlmRuntime({
    this.delay = Duration.zero,
    this.mockResponse,
    this.shouldFailLoad = false,
    this.shouldFailGeneration = false,
  });

  @override
  bool get isLoaded => _isLoaded;

  @override
  Future<void> loadModel(String modelPath) async {
    if (shouldFailLoad) {
      throw Exception('Failed to load quantized SLM model');
    }
    await Future.delayed(delay);
    _isLoaded = true;
  }

  @override
  Future<String> generateResponse(String prompt) async {
    if (shouldFailGeneration) {
      throw Exception('Inference kernel error');
    }
    await Future.delayed(delay);
    return mockResponse ??
        'Buen trabajo en la Quena. Enfócate en sostener notas largas y mantener los hombros relajados.';
  }

  @override
  void dispose() {
    _isLoaded = false;
  }
}

void main() {
  group('LocalSlmEngine - Pruebas Unitarias', () {
    test(
      'Inicialización exitosa y generación de texto ante prompt sintético',
      () async {
        final runtime = MockSlmRuntime(
          mockResponse:
              'Excelente ejecución en Quena. Cubre bien el 3er orificio.',
        );
        final engine = LocalSlmEngine(
          runtime: runtime,
          freeRamProvider: () => 3500, // 3.5 GB libres (> 2 GB)
        );

        await engine.initializeModel(
          modelPath: 'assets/models/gemma-2-2b-it-int4.bin',
        );

        expect(engine.isModelInitialized, isTrue);
        expect(engine.isFallbackActive, isFalse);
        expect(
          engine.loadedModelPath,
          equals('assets/models/gemma-2-2b-it-int4.bin'),
        );

        final feedback = await engine.generatePedagogicalFeedback(
          prompt: 'Resumen de práctica Quena: 85% precisión, nota D4 calada.',
        );

        expect(
          feedback,
          equals('Excelente ejecución en Quena. Cubre bien el 3er orificio.'),
        );
        engine.dispose();
        expect(engine.isModelInitialized, isFalse);
      },
    );

    test(
      'Genera respuesta vacía del runtime y conmuta a consejo pedagógico determinista',
      () async {
        final runtime = MockSlmRuntime(mockResponse: '   ');
        final engine = LocalSlmEngine(
          runtime: runtime,
          freeRamProvider: () => 4096,
        );

        await engine.initializeModel(
          modelPath: 'assets/models/gemma-2-2b-it-int4.bin',
        );
        final feedback = await engine.generatePedagogicalFeedback(
          prompt: 'Práctica de Quena con fallos en orificio 3',
        );

        expect(feedback, contains('Quena'));
        expect(feedback, contains('3er orificio'));
      },
    );
  });

  group('LocalSlmEngine - Pruebas de Integración y Fallback Determinista', () {
    test(
      'Fallback automático cuando RAM libre es insuficiente (< 2 GB)',
      () async {
        final runtime = MockSlmRuntime();
        final engine = LocalSlmEngine(
          runtime: runtime,
          freeRamProvider: () => 1500, // 1.5 GB libres (< 2048 MB)
        );

        await engine.initializeModel(
          modelPath: 'assets/models/gemma-2-2b-it-int4.bin',
        );

        expect(engine.isModelInitialized, isFalse);
        expect(engine.isFallbackActive, isTrue);
        expect(runtime.isLoaded, isFalse);

        final feedback = await engine.generatePedagogicalFeedback(
          prompt: 'Práctica de Zampoña con ataque desafinado',
        );

        expect(feedback, contains('Zampoña'));
        expect(feedback, contains('ataque seco'));
      },
    );

    test(
      'Fallback automático cuando el runtime SLM es nulo o falla la carga',
      () async {
        final engineWithoutRuntime = LocalSlmEngine(
          runtime: null,
          freeRamProvider: () => 4096,
        );

        await engineWithoutRuntime.initializeModel(
          modelPath: 'assets/models/invalid.bin',
        );
        expect(engineWithoutRuntime.isFallbackActive, isTrue);

        final tarkaFeedback = await engineWithoutRuntime
            .generatePedagogicalFeedback(
              prompt: 'Práctica de Tarka con presión de aire inestable',
            );
        expect(tarkaFeedback, contains('Tarka'));
        expect(tarkaFeedback, contains('boquilla de madera'));

        final runtimeWithError = MockSlmRuntime(shouldFailLoad: true);
        final engineWithFailingRuntime = LocalSlmEngine(
          runtime: runtimeWithError,
          freeRamProvider: () => 4096,
        );

        await engineWithFailingRuntime.initializeModel(
          modelPath: 'assets/models/corrupt.bin',
        );
        expect(engineWithFailingRuntime.isFallbackActive, isTrue);
        final quenaFeedback = await engineWithFailingRuntime
            .generatePedagogicalFeedback(prompt: 'Quena afinación cents');
        expect(quenaFeedback, contains('embocadura'));
      },
    );

    test(
      'Fallback cuando el runtime arroja excepción durante inferencia',
      () async {
        final runtime = MockSlmRuntime(shouldFailGeneration: true);
        final engine = LocalSlmEngine(
          runtime: runtime,
          freeRamProvider: () => 3000,
        );

        await engine.initializeModel(modelPath: 'assets/models/gemma.bin');
        expect(engine.isModelInitialized, isTrue);

        final feedback = await engine.generatePedagogicalFeedback(
          prompt: 'Postura y hombros en práctica general',
        );

        expect(feedback, contains('espalda erguida'));
      },
    );
  });

  group(
    'LocalSlmEngine - Pruebas E2E y Límites de Rendimiento (<= 3 segundos)',
    () {
      test('Inferencia SLM se completa en <= 3 segundos', () async {
        final stopwatch = Stopwatch()..start();
        final runtime = MockSlmRuntime(
          delay: const Duration(milliseconds: 350),
          mockResponse:
              '¡Excelente progreso! Tu soplo en la Quena ha mejorado notablemente.',
        );
        final engine = LocalSlmEngine(
          runtime: runtime,
          freeRamProvider: () => 4000,
        );

        await engine.initializeModel(modelPath: 'assets/models/gemma-2-2b.bin');
        final feedback = await engine.generatePedagogicalFeedback(
          prompt: 'Quena sesión 100% afinación',
        );
        stopwatch.stop();

        expect(feedback, contains('Quena'));
        expect(stopwatch.elapsedMilliseconds, lessThanOrEqualTo(3000));
      });

      test(
        'Degrada a fallback determinista si la inferencia excede 3 segundos',
        () async {
          final runtime = MockSlmRuntime(
            delay: const Duration(
              milliseconds: 3500,
            ), // Excede el límite de 3.0s
            mockResponse: 'Esta respuesta tardía no debe ser retornada.',
          );
          final engine = LocalSlmEngine(
            runtime: runtime,
            freeRamProvider: () => 4000,
          );

          await engine.initializeModel(
            modelPath: 'assets/models/gemma-slow.bin',
          );
          final stopwatch = Stopwatch()..start();
          final feedback = await engine.generatePedagogicalFeedback(
            prompt: 'Práctica de Quena ritmo y tempo',
          );
          stopwatch.stop();

          // Debe retornar fallback pedagógico y no demorar más de ~3.1 segundos
          expect(
            feedback,
            isNot(equals('Esta respuesta tardía no debe ser retornada.')),
          );
          expect(feedback, contains('tempo'));
          expect(stopwatch.elapsedMilliseconds, lessThanOrEqualTo(3300));
        },
      );
    },
  );
}
