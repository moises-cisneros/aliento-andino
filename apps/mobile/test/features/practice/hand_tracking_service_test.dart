import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/practice/hands/fingering_evaluator.dart';
import 'package:mobile/features/practice/hands/hand_tracking_service.dart';

/// Lista válida de 21 landmarks de una mano para las pruebas.
List<HandLandmark> validHand() => List<HandLandmark>.filled(
  HandLandmarkIndex.handLandmarkCount,
  const HandLandmark(x: 0.5, y: 0.5, z: 0.0),
);

void main() {
  group('HandTrackingService — tolerancia a oclusión', () {
    late DateTime now;
    late HandTrackingService service;

    setUp(() {
      now = DateTime(2026, 1, 1, 12, 0, 0);
      service = HandTrackingService(
        graceWindow: const Duration(milliseconds: 500),
        clock: () => now,
      );
    });

    test('detección fresca → alta confianza, no obsoleta', () {
      final result = service.track(validHand());

      expect(result.confidence, HandTrackingConfidence.high);
      expect(result.isStale, isFalse);
      expect(result.isLost, isFalse);
      expect(result.landmarks, isNotNull);
      expect(service.hasValidPose, isTrue);
    });

    test(
      'mano perdida dentro de los 500 ms → retiene última postura (baja)',
      () {
        service.track(validHand());

        now = now.add(const Duration(milliseconds: 300));
        final result = service.track(null);

        expect(result.confidence, HandTrackingConfidence.low);
        expect(result.isStale, isTrue);
        expect(result.isLost, isFalse);
        expect(result.landmarks, isNotNull); // postura retenida
      },
    );

    test('justo en el límite de 500 ms aún retiene la postura', () {
      service.track(validHand());

      now = now.add(const Duration(milliseconds: 500));
      final result = service.track(null);

      expect(result.isLost, isFalse);
      expect(result.landmarks, isNotNull);
    });

    test('más allá de los 500 ms → seguimiento perdido, sin postura', () {
      service.track(validHand());

      now = now.add(const Duration(milliseconds: 501));
      final result = service.track(null);

      expect(result.isLost, isTrue);
      expect(result.landmarks, isNull);
      expect(service.hasValidPose, isFalse);
    });

    test('mano con menos de 21 puntos se trata como pérdida', () {
      final result = service.track(
        List<HandLandmark>.filled(
          10,
          const HandLandmark(x: 0.5, y: 0.5, z: 0.0),
        ),
      );

      expect(result.confidence, HandTrackingConfidence.low);
      expect(result.isLost, isTrue);
    });

    test('reset limpia la postura retenida', () {
      service.track(validHand());
      expect(service.hasValidPose, isTrue);

      service.reset();
      expect(service.hasValidPose, isFalse);
    });
  });

  group('Integración pipeline Hands: tracking + fingering', () {
    test(
      'oclusión transitoria: la postura retenida sigue alimentando al evaluador',
      () {
        var now = DateTime(2026, 1, 1, 12, 0, 0);
        final service = HandTrackingService(clock: () => now);
        const evaluator = FingeringEvaluator();

        // Frame 1: mano válida con agarre hermético.
        final tracked = service.track(validHand());
        expect(tracked.confidence, HandTrackingConfidence.high);

        // Frame 2: la otra mano la ocluye por 200 ms → se retiene la postura.
        now = now.add(const Duration(milliseconds: 200));
        final occluded = service.track(null);
        expect(occluded.isStale, isTrue);
        expect(occluded.landmarks, isNotNull);

        // El evaluador trabaja sobre la postura retenida sin inventar datos.
        final evaluation = evaluator.evaluateHolesCoverage(
          occluded.landmarks!,
          InstrumentType.quena,
          const FingeringTarget.allCovered(),
        );
        expect(evaluation.holes, hasLength(4));
      },
    );
  });
}
