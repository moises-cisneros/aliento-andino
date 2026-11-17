import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/posture/posture_analyzer.dart';
import 'package:mobile/features/practice/posture/posture_scorer.dart';

/// Construye 33 landmarks de MediaPipe Pose para las pruebas.
List<PoseLandmark> buildLandmarks({
  double leftShoulderY = 0.40,
  double rightShoulderY = 0.40,
  double noseX = 0.50,
  double visibility = 0.95,
}) {
  final list = List<PoseLandmark>.filled(
    33,
    NormalizedLandmark(x: 0.5, y: 0.5, z: 0.0, visibility: visibility),
  );
  list[0] = NormalizedLandmark(
    x: noseX,
    y: 0.25,
    z: 0.0,
    visibility: visibility,
  );
  list[11] = NormalizedLandmark(
    x: 0.35,
    y: leftShoulderY,
    z: 0.0,
    visibility: visibility,
  );
  list[12] = NormalizedLandmark(
    x: 0.65,
    y: rightShoulderY,
    z: 0.0,
    visibility: visibility,
  );
  list[13] = NormalizedLandmark(
    x: 0.35,
    y: 0.55,
    z: 0.0,
    visibility: visibility,
  );
  list[14] = NormalizedLandmark(
    x: 0.65,
    y: 0.55,
    z: 0.0,
    visibility: visibility,
  );
  list[15] = NormalizedLandmark(
    x: 0.48,
    y: 0.55,
    z: 0.0,
    visibility: visibility,
  );
  list[16] = NormalizedLandmark(
    x: 0.52,
    y: 0.55,
    z: 0.0,
    visibility: visibility,
  );
  return list;
}

void main() {
  group('PostureAnalyzer [SUB-06-A]', () {
    const analyzer = PostureAnalyzer();

    test('postura nivelada: sin error de hombros y cabeza alineada', () {
      final metrics = analyzer.analyzeKeypoints(buildLandmarks());

      expect(metrics.warning, PostureWarning.none);
      expect(metrics.shoulderTiltDegrees, lessThan(1.0));
      expect(metrics.headAligned, isTrue);
      expect(analyzer.isShoulderTiltError(metrics), isFalse);
    });

    test('hombros desnivelados > 15°: detecta error postural de hombros', () {
      // dx = 0.30, dy = 0.15 → atan(0.5) ≈ 26.57° > 15°.
      final metrics = analyzer.analyzeKeypoints(
        buildLandmarks(leftShoulderY: 0.30, rightShoulderY: 0.45),
      );

      expect(metrics.warning, PostureWarning.none);
      expect(metrics.shoulderTiltDegrees, greaterThan(15.0));
      expect(analyzer.isShoulderTiltError(metrics), isTrue);
    });

    test('cabeza inclinada lateralmente: headAligned es false', () {
      // Nariz desplazada del centro de hombros → neckTilt alto.
      final metrics = analyzer.analyzeKeypoints(buildLandmarks(noseX: 0.70));

      expect(metrics.warning, PostureWarning.none);
      expect(metrics.headAligned, isFalse);
    });

    test(
      'baja visibilidad: PostureWarning.userOutOfFrame sin bloquear la sesión',
      () {
        final metrics = analyzer.analyzeKeypoints(
          buildLandmarks(visibility: 0.2),
        );

        expect(metrics.warning, PostureWarning.userOutOfFrame);
        expect(metrics.isUserOutOfFrame, isTrue);
        expect(analyzer.isShoulderTiltError(metrics), isFalse);
      },
    );

    test('landmarks insuficientes: userOutOfFrame sin excepción', () {
      final metrics = analyzer.analyzeKeypoints(const <PoseLandmark>[]);

      expect(metrics.warning, PostureWarning.userOutOfFrame);
      expect(metrics.shoulderTiltDegrees, 0.0);
      expect(metrics.headAligned, isFalse);
    });
  });
}
