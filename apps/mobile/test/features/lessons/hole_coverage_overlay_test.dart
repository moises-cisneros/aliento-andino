import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/lessons/presentation/widgets/hole_coverage_overlay.dart';
import 'package:mobile/features/practice/hands/fingering_evaluator.dart';

HoleCoverage _hole({
  int id = 1,
  Finger finger = Finger.indexFinger,
  bool required = true,
  bool covered = true,
}) => HoleCoverage(
  holeId: id,
  finger: finger,
  required: required,
  distance: covered ? 0.0 : 0.3,
  covered: covered,
);

HandCoverageEvaluation _evaluation({
  required List<HoleCoverage> holes,
  HandTrackingConfidence confidence = HandTrackingConfidence.high,
}) => HandCoverageEvaluation(
  holes: holes,
  confidence: confidence,
  feedback: const ['x'],
);

void main() {
  group('HoleCoverageOverlay.colorForHole (tokens de DESIGN.md)', () {
    test('orificio requerido y cubierto → verde #10B981 (success)', () {
      expect(
        HoleCoverageOverlay.colorForHole(_hole(required: true, covered: true)),
        AppTheme.success,
      );
    });

    test('orificio requerido con fuga → rojo #EF4444 (error)', () {
      expect(
        HoleCoverageOverlay.colorForHole(_hole(required: true, covered: false)),
        AppTheme.error,
      );
    });

    test('orificio no requerido (abierto) → neutro (muted)', () {
      expect(
        HoleCoverageOverlay.colorForHole(
          _hole(required: false, covered: false),
        ),
        AppTheme.muted,
      );
    });
  });

  group('HoleCoverageOverlay.shouldFallbackToStatic', () {
    test('evaluación nula → fallback estático', () {
      expect(HoleCoverageOverlay.shouldFallbackToStatic(null), isTrue);
    });

    test('baja confianza → fallback estático', () {
      expect(
        HoleCoverageOverlay.shouldFallbackToStatic(
          _evaluation(holes: const [], confidence: HandTrackingConfidence.low),
        ),
        isTrue,
      );
    });

    test('evaluación confiable con orificios → sin fallback', () {
      expect(
        HoleCoverageOverlay.shouldFallbackToStatic(
          _evaluation(holes: [_hole()]),
        ),
        isFalse,
      );
    });
  });

  group('HoleCoverageOverlay (widget reactivo)', () {
    testWidgets('renderiza el overlay ante una evaluación confiable', (
      tester,
    ) async {
      final evaluation = _evaluation(
        holes: [
          _hole(id: 1, covered: true),
          _hole(id: 3, finger: Finger.ring, covered: false),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 500,
              child: HoleCoverageOverlay(
                instrument: InstrumentType.quena,
                evaluationStream: Stream<HandCoverageEvaluation>.value(
                  evaluation,
                ),
                initial: evaluation,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('hole-coverage-overlay')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Fuga de aire detectada en los orificios'),
        findsOneWidget,
      );
    });

    testWidgets('hace fallback a digitación de referencia sin lectura', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 500,
              child: HoleCoverageOverlay(
                instrument: InstrumentType.quena,
                evaluationStream: const Stream<HandCoverageEvaluation>.empty(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('hole-coverage-overlay')), findsOneWidget);
      expect(find.bySemanticsLabel('Digitación de referencia'), findsOneWidget);
    });
  });
}
