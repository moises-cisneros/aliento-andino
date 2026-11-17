import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/tutor/local_slm_engine.dart';
import 'package:mobile/core/tutor/tutor_prompt_builder.dart';
import 'package:mobile/features/lessons/data/models/practice_session_model.dart';
import 'package:mobile/features/tutor/presentation/widgets/tutor_feedback_card.dart';

class TestMockSlmRuntime implements SlmRuntime {
  bool _isLoaded = false;
  final Duration delay;
  final String response;

  TestMockSlmRuntime({this.delay = Duration.zero, required this.response});

  @override
  bool get isLoaded => _isLoaded;

  @override
  Future<void> loadModel(String modelPath) async {
    _isLoaded = true;
  }

  @override
  Future<String> generateResponse(String prompt) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    return response;
  }

  @override
  void dispose() {
    _isLoaded = false;
  }
}

void main() {
  group('E2E - Flujo Completo Post-Lección con Tutor Pedagógico On-Device', () {
    testWidgets(
      'Flujo E2E exitoso: Telemetría -> PromptBuilder -> LocalSlmEngine -> TutorFeedbackCard',
      (WidgetTester tester) async {
        // 1. Simulación de sesión de práctica finalizada con telemetría postular y acústica
        final sessionModel = PracticeSessionModel(
          id: 'session-e2e-001',
          userId: 'user-andino-1',
          lessonId: 'lesson-quena-octava-1',
          score: 82.0,
          correctNotes: 16,
          totalNotes: 20,
          wrongNotes: 4,
          missedNotes: 0,
          averageTempo: 62.0,
          expectedTempo: 60,
          tempoAccuracy: 0.92,
          totalTimeSeconds: 40.0,
          errorsDetail: [
            {'error': 'Fuga de aire en 3er orificio de Quena'},
            {'error': 'Afinación calada en nota A4'},
          ],
        );

        final summary = PracticeSummary.fromSession(
          sessionModel,
          postureStabilityScore: 0.93,
          averageCentsDeviation: -14.5,
        );

        // 2. Construcción de prompt pedagógico estructurado
        const promptBuilder = TutorPromptBuilder();
        final prompt = promptBuilder.buildPrompt(summary, InstrumentType.quena);

        expect(prompt, contains('Instrumento: Quena'));
        expect(prompt, contains('Puntaje: 82.0 / 100'));
        expect(prompt, contains('Fuga de aire en 3er orificio de Quena'));

        // 3. Inferencia acústica y pedagógica con LocalSlmEngine (< 3s)
        final stopwatch = Stopwatch()..start();
        final mockRuntime = TestMockSlmRuntime(
          response:
              '¡Gran esfuerzo en la Quena! Asegúrate de cubrir bien el 3er orificio para sellar la octava y soplar suavemente.',
        );

        final slmEngine = LocalSlmEngine(
          runtime: mockRuntime,
          freeRamProvider: () => 3500, // RAM adecuada (> 2 GB)
        );

        await slmEngine.initializeModel(
          modelPath: 'assets/models/gemma-2-2b-it-int4.bin',
        );
        final generatedFeedback = await slmEngine.generatePedagogicalFeedback(
          prompt: prompt,
        );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThanOrEqualTo(3000));
        expect(generatedFeedback, contains('3er orificio'));

        // 4. Renderizado en TutorFeedbackCard y validación de UI
        bool acknowledged = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    TutorFeedbackCard(
                      feedback: generatedFeedback,
                      instrument: InstrumentType.quena,
                      onAcknowledge: () {
                        acknowledged = true;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tutor_feedback_card')), findsOneWidget);
        expect(find.text('Tutor Pedagógico'), findsOneWidget);
        expect(find.text('Consejo para Quena'), findsOneWidget);
        expect(find.text('On-Device'), findsOneWidget);

        final textFinder = find.byKey(const Key('tutor_feedback_text'));
        expect(textFinder, findsOneWidget);
        expect(tester.widget<Text>(textFinder).data, contains('3er orificio'));

        // Interacción del estudiante
        final buttonFinder = find.byKey(const Key('tutor_acknowledge_button'));
        expect(buttonFinder, findsOneWidget);
        await tester.tap(buttonFinder);
        await tester.pump();
        expect(acknowledged, isTrue);

        slmEngine.dispose();
      },
    );

    testWidgets(
      'Flujo E2E con degradación elegante a fallback determinista y renderizado visual',
      (WidgetTester tester) async {
        // Dispositivo con RAM insuficiente (< 2 GB)
        final sessionModel = PracticeSessionModel(
          id: 'session-e2e-low-ram',
          userId: 'user-andino-2',
          lessonId: 'lesson-zampona-01',
          score: 65.0,
          correctNotes: 13,
          totalNotes: 20,
          wrongNotes: 7,
          missedNotes: 0,
          averageTempo: 50.0,
          expectedTempo: 60,
          tempoAccuracy: 0.83,
          totalTimeSeconds: 50.0,
          errorsDetail: [
            {'error': 'Ataque desafinado en tubos centrales'},
          ],
        );

        final summary = PracticeSummary.fromSession(
          sessionModel,
          postureStabilityScore: 0.85,
          averageCentsDeviation: 22.0,
        );

        const promptBuilder = TutorPromptBuilder();
        final prompt = promptBuilder.buildPrompt(
          summary,
          InstrumentType.zampona,
        );

        final lowRamEngine = LocalSlmEngine(
          runtime: null,
          freeRamProvider: () => 1200, // 1.2 GB libres (< 2 GB)
        );

        await lowRamEngine.initializeModel(
          modelPath: 'assets/models/llama-3.2-1b.bin',
        );
        expect(lowRamEngine.isFallbackActive, isTrue);

        final fallbackFeedback = await lowRamEngine.generatePedagogicalFeedback(
          prompt: prompt,
        );
        expect(fallbackFeedback, contains('Zampoña'));
        expect(fallbackFeedback, contains('ataque seco'));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TutorFeedbackCard(
                feedback: fallbackFeedback,
                instrument: InstrumentType.zampona,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final textFinder = find.byKey(const Key('tutor_feedback_text'));
        expect(textFinder, findsOneWidget);
        expect(tester.widget<Text>(textFinder).data, contains('ataque seco'));
        expect(find.text('Consejo para Zampoña'), findsOneWidget);
      },
    );
  });
}
