import 'package:equatable/equatable.dart';

import 'package:mobile/features/practice/posture/posture_scorer.dart';

/// Landmark corporal normalizado de MediaPipe Pose.
///
/// Alias de [NormalizedLandmark] para honrar el contrato técnico de SUB-06-A
/// (`List<PoseLandmark>`) sin duplicar el modelo ya existente en el repo.
typedef PoseLandmark = NormalizedLandmark;

/// Advertencias no bloqueantes del análisis postural.
///
/// Nunca interrumpen la sesión de audio (regla: inferencia postural y acústica
/// son independientes): sólo informan que no se puede evaluar la postura.
enum PostureWarning {
  /// Postura evaluable con normalidad.
  none,

  /// Rostro u hombros fuera de encuadre / baja confianza de detección.
  userOutOfFrame,
}

/// Métricas anatómicas derivadas de los landmarks de MediaPipe Pose.
///
/// Contrato técnico de SUB-06-A (#25):
/// `PostureMetrics(double shoulderTiltDegrees, double elbowAngleDegrees, bool headAligned)`.
class PostureMetrics extends Equatable {
  /// Desnivel de hombros en grados (0° = perfectamente horizontal).
  final double shoulderTiltDegrees;

  /// Apertura media de codos en grados (vértice en el codo).
  final double elbowAngleDegrees;

  /// `true` si la cabeza está verticalmente alineada con la columna.
  final bool headAligned;

  /// Advertencia asociada; [PostureWarning.none] cuando la medición es válida.
  final PostureWarning warning;

  const PostureMetrics({
    required this.shoulderTiltDegrees,
    required this.elbowAngleDegrees,
    required this.headAligned,
    this.warning = PostureWarning.none,
  });

  /// Métrica degradada cuando el usuario no es visible en el encuadre.
  factory PostureMetrics.outOfFrame() => const PostureMetrics(
    shoulderTiltDegrees: 0.0,
    elbowAngleDegrees: 0.0,
    headAligned: false,
    warning: PostureWarning.userOutOfFrame,
  );

  /// `true` cuando no se pudo evaluar la postura por falta de visibilidad.
  bool get isUserOutOfFrame => warning == PostureWarning.userOutOfFrame;

  @override
  List<Object?> get props => [
    shoulderTiltDegrees,
    elbowAngleDegrees,
    headAligned,
    warning,
  ];

  @override
  String toString() =>
      'PostureMetrics(shoulderTilt: ${shoulderTiltDegrees.toStringAsFixed(1)}°, '
      'elbowAngle: ${elbowAngleDegrees.toStringAsFixed(1)}°, '
      'headAligned: $headAligned, warning: $warning)';
}

/// [SUB-06-A] Estimador de ángulos anatómicos a partir de landmarks de pose.
///
/// Procesa los landmarks de hombros (11, 12), codos (13, 14), muñecas (15, 16)
/// y nariz (0) para calcular la desviación frente a la postura ergonómica del
/// intérprete de viento andino. Es pura y determinista: no toca cámara ni
/// hardware, por lo que es 100% comprobable sin dependencias nativas.
class PostureAnalyzer {
  /// Umbral de confianza media por debajo del cual se considera que el usuario
  /// está fuera de encuadre.
  final double minVisibility;

  /// Desnivel de hombros (grados) tolerado antes de marcar error postural.
  final double maxShoulderTiltDegrees;

  /// Inclinación de cuello (grados) tolerada para considerar la cabeza alineada.
  final double maxNeckTiltDegrees;

  const PostureAnalyzer({
    this.minVisibility = 0.5,
    this.maxShoulderTiltDegrees = 15.0,
    this.maxNeckTiltDegrees = 12.0,
  });

  // Índices canónicos de MediaPipe Pose.
  static const int _nose = 0;
  static const int _leftShoulder = 11;
  static const int _rightShoulder = 12;
  static const int _leftElbow = 13;
  static const int _rightElbow = 14;
  static const int _leftWrist = 15;
  static const int _rightWrist = 16;

  /// Calcula las métricas posturales a partir de [landmarks].
  ///
  /// Si el rostro o los hombros no son visibles, retorna
  /// [PostureMetrics.outOfFrame] ([PostureWarning.userOutOfFrame]) sin lanzar
  /// excepción, de modo que la sesión de audio continúe sin bloquearse.
  PostureMetrics analyzeKeypoints(List<PoseLandmark> landmarks) {
    if (landmarks.length <= _rightWrist) {
      return PostureMetrics.outOfFrame();
    }

    final nose = landmarks[_nose];
    final leftShoulder = landmarks[_leftShoulder];
    final rightShoulder = landmarks[_rightShoulder];
    final leftElbow = landmarks[_leftElbow];
    final rightElbow = landmarks[_rightElbow];
    final leftWrist = landmarks[_leftWrist];
    final rightWrist = landmarks[_rightWrist];

    final critical = [nose, leftShoulder, rightShoulder];
    final avgVisibility =
        critical.map((l) => l.visibility).reduce((a, b) => a + b) /
        critical.length;
    if (avgVisibility < minVisibility) {
      return PostureMetrics.outOfFrame();
    }

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
    final elbowAngle = (leftElbowAngle + rightElbowAngle) / 2.0;

    return PostureMetrics(
      shoulderTiltDegrees: shoulderTilt,
      elbowAngleDegrees: elbowAngle,
      headAligned: neckTilt <= maxNeckTiltDegrees,
      warning: PostureWarning.none,
    );
  }

  /// `true` si el desnivel de hombros supera el umbral ergonómico.
  bool isShoulderTiltError(PostureMetrics metrics) =>
      metrics.warning == PostureWarning.none &&
      metrics.shoulderTiltDegrees > maxShoulderTiltDegrees;
}
