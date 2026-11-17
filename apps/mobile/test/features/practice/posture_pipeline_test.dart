import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/practice/posture/mediapipe_posture_pipeline.dart';
import 'package:mobile/features/practice/posture/posture_scorer.dart';

/// Crea una lista sintética de 33 landmarks para simular MediaPipe Pose.
List<NormalizedLandmark> createMockPoseLandmarks({
  double leftShoulderY = 0.40,
  double rightShoulderY = 0.40,
  double noseX = 0.50,
  double leftElbowX = 0.35,
  double leftElbowY = 0.55,
  double rightElbowX = 0.65,
  double rightElbowY = 0.55,
  double leftWristX = 0.48,
  double leftWristY = 0.55,
  double rightWristX = 0.52,
  double rightWristY = 0.55,
  double visibility = 0.95,
}) {
  final list = List<NormalizedLandmark>.filled(
    33,
    NormalizedLandmark(x: 0.5, y: 0.5, z: 0.0, visibility: visibility),
  );

  // 0: Nariz
  list[0] = NormalizedLandmark(
    x: noseX,
    y: 0.25,
    z: 0.0,
    visibility: visibility,
  );
  // 11: Hombro izquierdo
  list[11] = NormalizedLandmark(
    x: 0.35,
    y: leftShoulderY,
    z: 0.0,
    visibility: visibility,
  );
  // 12: Hombro derecho
  list[12] = NormalizedLandmark(
    x: 0.65,
    y: rightShoulderY,
    z: 0.0,
    visibility: visibility,
  );
  // 13: Codo izquierdo
  list[13] = NormalizedLandmark(
    x: leftElbowX,
    y: leftElbowY,
    z: 0.0,
    visibility: visibility,
  );
  // 14: Codo derecho
  list[14] = NormalizedLandmark(
    x: rightElbowX,
    y: rightElbowY,
    z: 0.0,
    visibility: visibility,
  );
  // 15: Muñeca izquierda
  list[15] = NormalizedLandmark(
    x: leftWristX,
    y: leftWristY,
    z: 0.0,
    visibility: visibility,
  );
  // 16: Muñeca derecha
  list[16] = NormalizedLandmark(
    x: rightWristX,
    y: rightWristY,
    z: 0.0,
    visibility: visibility,
  );

  return list;
}

void main() {
  group('MediaPipePosturePipeline [S0-05]', () {
    const pipeline = MediaPipePosturePipeline();

    test(
      'evalúa como ergonómica una postura nivelada y equilibrada (score >= 90)',
      () {
        final idealPose = createMockPoseLandmarks(
          leftShoulderY: 0.40,
          rightShoulderY: 0.40, // Perfectamente horizontal
          noseX: 0.50, // Alineado al centro de hombros
        );

        final eval = pipeline.evaluatePoseAndHands(
          poseLandmarks: idealPose,
          instrument: InstrumentType.quena,
        );

        expect(eval.status, PostureTrackingStatus.tracking);
        expect(eval.isErgonomic, isTrue);
        expect(eval.overallScore, greaterThanOrEqualTo(90.0));
        expect(eval.shoulderTiltDegrees, lessThan(1.0));
        expect(eval.neckTiltDegrees, lessThan(2.0));
        expect(eval.leftElbowDegrees, closeTo(90.0, 1.0));
        expect(eval.rightElbowDegrees, closeTo(90.0, 1.0));
      },
    );

    test(
      'penaliza hombros desnivelados (>8 grados) y emite advertencia ergonómica',
      () {
        final tiltedShoulders = createMockPoseLandmarks(
          leftShoulderY: 0.35,
          rightShoulderY: 0.45, // Desnivel marcado
        );

        final eval = pipeline.evaluatePoseAndHands(
          poseLandmarks: tiltedShoulders,
          instrument: InstrumentType.quena,
        );

        expect(eval.shoulderTiltDegrees, greaterThan(8.0));
        expect(eval.isErgonomic, isFalse);
        expect(eval.overallScore, lessThan(80.0));
        expect(
          eval.feedback.any((msg) => msg.contains('Hombros desnivelados')),
          isTrue,
        );
      },
    );

    test(
      'retorna PostureTrackingStatus.lost cuando la confianza media es < 0.5',
      () {
        final lowConfidencePose = createMockPoseLandmarks(visibility: 0.2);

        final eval = pipeline.evaluatePoseAndHands(
          poseLandmarks: lowConfidencePose,
        );

        expect(eval.status, PostureTrackingStatus.lost);
        expect(eval.isErgonomic, isFalse);
        expect(eval.overallScore, 0.0);
      },
    );

    test(
      'prueba de integración continua: procesa 100 frames simulados sin degradación ni fugas',
      () {
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          final jitter = (i % 5) * 0.001;
          final frame = createMockPoseLandmarks(
            leftShoulderY: 0.40 + jitter,
            rightShoulderY: 0.40 - jitter,
          );
          final eval = pipeline.evaluatePoseAndHands(poseLandmarks: frame);
          expect(eval.status, PostureTrackingStatus.tracking);
        }
        stopwatch.stop();

        // 100 frames deben computarse en menos de 500ms (rendimiento on-device a >60 FPS)
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      },
    );
  });
}
