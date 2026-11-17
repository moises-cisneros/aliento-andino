import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/practice/hands/fingering_evaluator.dart';

/// Construye los 21 landmarks de MediaPipe Hands para las pruebas.
///
/// Por defecto sitúa cada yema **sobre** el orificio de la Quena que le
/// corresponde (agarre hermético). Cada tip puede reposicionarse para simular
/// un dedo desplazado.
List<HandLandmark> buildHand({
  ({double x, double y}) indexTip = (x: 0.50, y: 0.24), // orificio 1
  ({double x, double y}) middleTip = (x: 0.50, y: 0.40), // orificio 2
  ({double x, double y}) ringTip = (x: 0.50, y: 0.56), // orificio 3
  ({double x, double y}) thumbTip = (
    x: 0.40,
    y: 0.48,
  ), // orificio 4 (posterior)
  ({double x, double y}) pinkyTip = (x: 0.60, y: 0.30),
  int count = HandLandmarkIndex.handLandmarkCount,
}) {
  final list = List<HandLandmark>.filled(
    count,
    const HandLandmark(x: 0.5, y: 0.5, z: 0.0),
  );
  void place(int i, ({double x, double y}) p) {
    if (i < count) list[i] = HandLandmark(x: p.x, y: p.y, z: 0.0);
  }

  place(HandLandmarkIndex.thumbTip, thumbTip);
  place(HandLandmarkIndex.indexTip, indexTip);
  place(HandLandmarkIndex.middleTip, middleTip);
  place(HandLandmarkIndex.ringTip, ringTip);
  place(HandLandmarkIndex.pinkyTip, pinkyTip);
  return list;
}

void main() {
  const evaluator = FingeringEvaluator();

  group('FingeringEvaluator.evaluateHolesCoverage (Quena)', () {
    test('agarre hermético: todas las yemas sobre sus orificios', () {
      final result = evaluator.evaluateHolesCoverage(
        buildHand(),
        InstrumentType.quena,
        const FingeringTarget.allCovered(),
      );

      expect(result.confidence, HandTrackingConfidence.high);
      expect(result.isSealed, isTrue);
      expect(result.hasLeak, isFalse);
      expect(result.leakingHoles, isEmpty);
      expect(result.holes, hasLength(4));
    });

    test('dedo anular desplazado del orificio 3 → fuga de aire detectada', () {
      // El anular se aleja del orificio 3 (centro en 0.50, 0.56).
      final result = evaluator.evaluateHolesCoverage(
        buildHand(ringTip: (x: 0.50, y: 0.90)),
        InstrumentType.quena,
        const FingeringTarget.allCovered(),
      );

      expect(result.confidence, HandTrackingConfidence.high);
      expect(result.hasLeak, isTrue);
      expect(result.isSealed, isFalse);

      final hole3 = result.holes.firstWhere((h) => h.holeId == 3);
      expect(hole3.finger, Finger.ring);
      expect(hole3.covered, isFalse);
      expect(hole3.isLeak, isTrue);
      expect(hole3.distance, greaterThan(evaluator.coverageRadius));

      // Los demás orificios siguen sellados.
      expect(result.leakingHoles.map((h) => h.holeId), [3]);
      expect(
        result.feedback.any(
          (f) => f.contains('Orificio 3') && f.contains('anular'),
        ),
        isTrue,
      );
    });

    test(
      'target que no exige el orificio 3 no reporta fuga aunque esté abierto',
      () {
        final result = evaluator.evaluateHolesCoverage(
          buildHand(ringTip: (x: 0.50, y: 0.90)),
          InstrumentType.quena,
          const FingeringTarget({1, 2}),
        );

        final hole3 = result.holes.firstWhere((h) => h.holeId == 3);
        expect(hole3.required, isFalse);
        expect(hole3.isLeak, isFalse);
        expect(result.hasLeak, isFalse);
      },
    );

    test('menos de 21 landmarks → baja confianza sin inventar cobertura', () {
      final result = evaluator.evaluateHolesCoverage(
        buildHand(count: 10),
        InstrumentType.quena,
        const FingeringTarget.allCovered(),
      );

      expect(result.confidence, HandTrackingConfidence.low);
      expect(result.holes, isEmpty);
      expect(result.hasLeak, isFalse);
    });
  });

  group('FingeringEvaluator por instrumento', () {
    test('Zampoña evalúa alineación de tubos con dedos distintos', () {
      final holes = InstrumentHoleMap.of(InstrumentType.zampona);
      final fingers = holes.map((h) => h.finger).toSet();
      expect(fingers, hasLength(holes.length)); // sin dedos duplicados
    });

    test('cada instrumento asigna un dedo único por orificio alcanzable', () {
      for (final instrument in InstrumentType.values) {
        final holes = InstrumentHoleMap.of(instrument);
        final fingers = holes.map((h) => h.finger).toList();
        expect(
          fingers.toSet(),
          hasLength(fingers.length),
          reason: 'Dedos duplicados en $instrument',
        );
      }
    });
  });
}
