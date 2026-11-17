import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/tutor/tutor_prompt_builder.dart';
import 'package:mobile/features/lessons/data/models/practice_session_model.dart';

void main() {
  group('TutorPromptBuilder - Pruebas Unitarias', () {
    const builder = TutorPromptBuilder();

    test('Construye prompt estructurado completo para Quena', () {
      const summary = PracticeSummary(
        score: 88.5,
        correctNotes: 18,
        totalNotes: 20,
        wrongNotes: 2,
        missedNotes: 0,
        averageTempo: 62.0,
        expectedTempo: 60,
        averageCentsDeviation: -12.4,
        postureStabilityScore: 0.94,
        flaggedErrors: ['Fuga de aire en orificio 3', 'Soplo inestable'],
      );

      final prompt = builder.buildPrompt(summary, InstrumentType.quena);

      expect(prompt, contains('--- TELEMETRÍA DE PRÁCTICA ---'));
      expect(prompt, contains('Instrumento: Quena'));
      expect(prompt, contains('Puntaje: 88.5 / 100'));
      expect(prompt, contains('Notas acertadas: 18 de 20 (90.0%)'));
      expect(prompt, contains('Notas falladas: 2, notas omitidas: 0'));
      expect(prompt, contains('Desviación de afinación: -12.4 cents'));
      expect(prompt, contains('Estabilidad postural: 94.0%'));
      expect(prompt, contains('Tempo promedio: 62.0 BPM (Esperado: 60 BPM)'));
      expect(prompt, contains('Fuga de aire en orificio 3, Soplo inestable'));
      expect(prompt, contains('--- INSTRUCCIÓN PEDAGÓGICA ---'));
      expect(prompt, contains('técnica de Quena'));
    });

    test(
      'Construye prompt estructurado para Zampoña sin errores específicos',
      () {
        const summary = PracticeSummary(
          score: 95.0,
          correctNotes: 30,
          totalNotes: 30,
          wrongNotes: 0,
          missedNotes: 0,
          averageTempo: 70.0,
          expectedTempo: 70,
          averageCentsDeviation: 4.2,
          postureStabilityScore: 0.98,
        );

        final prompt = builder.buildPrompt(summary, InstrumentType.zampona);

        expect(prompt, contains('Instrumento: Zampoña'));
        expect(prompt, contains('Notas acertadas: 30 de 30 (100.0%)'));
        expect(prompt, contains('Desviación de afinación: 4.2 cents'));
        expect(prompt, isNot(contains('Detalle de errores detectados')));
        expect(prompt, contains('técnica de Zampoña'));
      },
    );

    test('Construye prompt estructurado para Tarka', () {
      const summary = PracticeSummary(
        score: 74.0,
        correctNotes: 14,
        totalNotes: 20,
        wrongNotes: 4,
        missedNotes: 2,
        averageTempo: 55.0,
        expectedTempo: 60,
        averageCentsDeviation: 18.0,
        postureStabilityScore: 0.82,
        flaggedErrors: ['Presión de aire excesiva en octava alta'],
      );

      final prompt = builder.buildPrompt(summary, InstrumentType.tarka);

      expect(prompt, contains('Instrumento: Tarka'));
      expect(prompt, contains('Presión de aire excesiva en octava alta'));
      expect(prompt, contains('técnica de Tarka'));
    });

    test(
      'Verifica el consejo pedagógico predeterminado ante fallas o timeouts',
      () {
        expect(
          TutorPromptBuilder.defaultPedagogicalAdvice,
          equals(
            '¡Buen esfuerzo! Recuerda mantener el flujo de aire constante y los hombros relajados.',
          ),
        );
      },
    );

    test(
      'PracticeSummary.fromSession extrae correctamente métricas del PracticeSessionModel',
      () {
        final session = PracticeSessionModel(
          id: 'sess-123',
          userId: 'usr-456',
          lessonId: 'les-789',
          score: 85.0,
          correctNotes: 17,
          totalNotes: 20,
          wrongNotes: 2,
          missedNotes: 1,
          averageTempo: 60.5,
          expectedTempo: 60,
          tempoAccuracy: 0.95,
          totalTimeSeconds: 45.0,
          errorsDetail: [
            {'error': 'Afinación calada en nota G4'},
            {'type': 'Desviación postural'},
          ],
        );

        final summary = PracticeSummary.fromSession(
          session,
          postureStabilityScore: 0.91,
          averageCentsDeviation: -8.5,
        );

        expect(summary.score, equals(85.0));
        expect(summary.correctNotes, equals(17));
        expect(summary.totalNotes, equals(20));
        expect(summary.wrongNotes, equals(2));
        expect(summary.missedNotes, equals(1));
        expect(summary.postureStabilityScore, equals(0.91));
        expect(summary.averageCentsDeviation, equals(-8.5));
        expect(summary.flaggedErrors, contains('Afinación calada en nota G4'));
        expect(summary.flaggedErrors, contains('Desviación postural'));
      },
    );
  });
}
