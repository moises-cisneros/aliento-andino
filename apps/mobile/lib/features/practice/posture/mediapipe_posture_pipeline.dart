import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/practice/posture/posture_scorer.dart';

/// Pipeline de inferencia y evaluación postural MediaPipe On-Device.
///
/// Procesa los 33 landmarks corporales (MediaPipe Pose) y 21 landmarks de mano
/// (MediaPipe Hands) para instrumentos de viento andinos sin enviar telemetría a servidores.
class MediaPipePosturePipeline {
  final double minConfidenceThreshold;

  const MediaPipePosturePipeline({this.minConfidenceThreshold = 0.5});

  /// Evalúa la postura del músico a partir de los landmarks detectados por MediaPipe.
  ///
  /// Los índices canónicos de MediaPipe Pose:
  /// - 0: Nariz
  /// - 11: Hombro izquierdo
  /// - 12: Hombro derecho
  /// - 13: Codo izquierdo
  /// - 14: Codo derecho
  /// - 15: Muñeca izquierda
  /// - 16: Muñeca derecha
  PostureEvaluation evaluatePoseAndHands({
    required List<NormalizedLandmark> poseLandmarks,
    List<NormalizedLandmark>? leftHandLandmarks,
    List<NormalizedLandmark>? rightHandLandmarks,
    InstrumentType instrument = InstrumentType.quena,
  }) {
    // Si no hay suficientes landmarks de pose (se requieren al menos hombros, codos y nariz)
    if (poseLandmarks.length < 17) {
      return PostureEvaluation.lost();
    }

    final nose = poseLandmarks[0];
    final leftShoulder = poseLandmarks[11];
    final rightShoulder = poseLandmarks[12];
    final leftElbow = poseLandmarks[13];
    final rightElbow = poseLandmarks[14];
    final leftWrist = poseLandmarks[15];
    final rightWrist = poseLandmarks[16];

    // Verificar confianza media de detección
    final criticalLandmarks = [
      nose,
      leftShoulder,
      rightShoulder,
      leftElbow,
      rightElbow,
    ];
    final avgConfidence =
        criticalLandmarks.map((l) => l.visibility).reduce((a, b) => a + b) /
        criticalLandmarks.length;

    if (avgConfidence < minConfidenceThreshold) {
      return PostureEvaluation.lost();
    }

    // Cálculos biomecánicos
    final shoulderTilt = PostureScorer.calculateShoulderTilt(
      leftShoulder,
      rightShoulder,
    );
    final neckTilt = PostureScorer.calculateNeckTilt(
      nose,
      leftShoulder,
      rightShoulder,
    );
    final leftElbowAngle = PostureScorer.calculateAngle3D(
      leftShoulder,
      leftElbow,
      leftWrist,
    );
    final rightElbowAngle = PostureScorer.calculateAngle3D(
      rightShoulder,
      rightElbow,
      rightWrist,
    );

    // Distancia media de muñecas a la embocadura (nariz/boca)
    final distLeft = PostureScorer.distance(nose, leftWrist);
    final distRight = PostureScorer.distance(nose, rightWrist);
    final embouchureDist = (distLeft + distRight) / 2.0;

    double score = 100.0;
    final feedback = <String>[];

    // 1. Evaluación de inclinación de hombros
    if (shoulderTilt > 8.0) {
      score -= 25.0;
      feedback.add(
        'Hombros desnivelados: mantené ambos hombros a la misma altura.',
      );
    } else if (shoulderTilt > 4.0) {
      score -= 10.0;
      feedback.add(
        'Leve inclinación en hombros: relajá la parte superior del torso.',
      );
    }

    // 2. Evaluación de inclinación de cuello
    if (neckTilt > 12.0) {
      score -= 25.0;
      feedback.add(
        'Cuello inclinado: alineá la cabeza verticalmente para no comprimir la laringe.',
      );
    } else if (neckTilt > 6.0) {
      score -= 10.0;
    }

    // 3. Evaluación de apertura de codos para instrumento andino
    // En Quena y Tarka los codos deben mantenerse separados del tórax (~50° a ~110°)
    if (leftElbowAngle < 40.0 || rightElbowAngle < 40.0) {
      score -= 15.0;
      feedback.add(
        'Codos demasiado pegados al cuerpo: separalos para facilitar la respiración diafragmática.',
      );
    } else if (leftElbowAngle > 140.0 || rightElbowAngle > 140.0) {
      score -= 15.0;
      feedback.add(
        'Brazos excesivamente extendidos: acercá el instrumento a una postura cómoda.',
      );
    }

    if (feedback.isEmpty) {
      feedback.add(
        '¡Excelente alineación postural! Torso, hombros y cuello equilibrados.',
      );
    }

    final finalScore = score.clamp(0.0, 100.0);
    final isErgonomic =
        finalScore >= 75.0 && shoulderTilt <= 8.0 && neckTilt <= 12.0;

    return PostureEvaluation(
      overallScore: finalScore,
      isErgonomic: isErgonomic,
      status: PostureTrackingStatus.tracking,
      shoulderTiltDegrees: shoulderTilt,
      neckTiltDegrees: neckTilt,
      leftElbowDegrees: leftElbowAngle,
      rightElbowDegrees: rightElbowAngle,
      embouchureDistance: embouchureDist,
      feedback: feedback,
    );
  }
}
