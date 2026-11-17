import 'dart:math' as math;

/// Estado del seguimiento postural on-device.
enum PostureTrackingStatus { tracking, lost, calibrating }

/// Landmark tridimensional normalizado proveniente de MediaPipe Pose / Hands.
class NormalizedLandmark {
  final double x;
  final double y;
  final double z;
  final double visibility;

  const NormalizedLandmark({
    required this.x,
    required this.y,
    required this.z,
    this.visibility = 1.0,
  });

  @override
  String toString() =>
      'NormalizedLandmark(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, z: ${z.toStringAsFixed(3)}, vis: ${visibility.toStringAsFixed(2)})';
}

/// Evaluación integral del desempeño postural y ergonómico del músico.
class PostureEvaluation {
  /// Puntaje general de 0 a 100.
  final double overallScore;

  /// Indica si la postura actual se encuentra dentro de los márgenes ergonómicos permitidos.
  final bool isErgonomic;

  /// Estado del tracking de visión por computadora.
  final PostureTrackingStatus status;

  /// Ángulo de inclinación de hombros en grados (0° = perfectamente horizontal).
  final double shoulderTiltDegrees;

  /// Ángulo de inclinación del cuello en grados (0° = alineado con la columna).
  final double neckTiltDegrees;

  /// Ángulo de apertura del codo izquierdo en grados.
  final double leftElbowDegrees;

  /// Ángulo de apertura del codo derecho en grados.
  final double rightElbowDegrees;

  /// Distancia estimada relativa entre la embocadura y las manos.
  final double embouchureDistance;

  /// Lista de recomendaciones ergonómicas en tiempo real.
  final List<String> feedback;

  const PostureEvaluation({
    required this.overallScore,
    required this.isErgonomic,
    required this.status,
    required this.shoulderTiltDegrees,
    required this.neckTiltDegrees,
    required this.leftElbowDegrees,
    required this.rightElbowDegrees,
    required this.embouchureDistance,
    required this.feedback,
  });

  factory PostureEvaluation.lost() => const PostureEvaluation(
    overallScore: 0.0,
    isErgonomic: false,
    status: PostureTrackingStatus.lost,
    shoulderTiltDegrees: 0.0,
    neckTiltDegrees: 0.0,
    leftElbowDegrees: 0.0,
    rightElbowDegrees: 0.0,
    embouchureDistance: 0.0,
    feedback: [
      'Alineá tu rostro y torso con la cámara para evaluar tu postura.',
    ],
  );

  @override
  String toString() =>
      'PostureEvaluation(score: ${overallScore.toStringAsFixed(1)}, status: $status, feedback: $feedback)';
}

/// Evaluador de ángulos y ergonomía anatómica para músicos de viento andino.
class PostureScorer {
  /// Calcula el ángulo 3D en grados formado por tres puntos (A - B - C) donde B es el vértice.
  static double calculateAngle3D(
    NormalizedLandmark a,
    NormalizedLandmark b,
    NormalizedLandmark c,
  ) {
    final v1x = a.x - b.x;
    final v1y = a.y - b.y;
    final v1z = a.z - b.z;

    final v2x = c.x - b.x;
    final v2y = c.y - b.y;
    final v2z = c.z - b.z;

    final dot = v1x * v2x + v1y * v2y + v1z * v2z;
    final mag1 = math.sqrt(v1x * v1x + v1y * v1y + v1z * v1z);
    final mag2 = math.sqrt(v2x * v2x + v2y * v2y + v2z * v2z);

    if (mag1 == 0 || mag2 == 0) return 0.0;

    double cosTheta = dot / (mag1 * mag2);
    // Clamping para evitar problemas de redondeo numérico en acos
    cosTheta = cosTheta.clamp(-1.0, 1.0);

    return math.acos(cosTheta) * (180.0 / math.pi);
  }

  /// Calcula la inclinación de hombros en grados con respecto al horizonte visual.
  static double calculateShoulderTilt(
    NormalizedLandmark leftShoulder,
    NormalizedLandmark rightShoulder,
  ) {
    final dx = (leftShoulder.x - rightShoulder.x).abs();
    final dy = (leftShoulder.y - rightShoulder.y).abs();
    if (dx == 0) return 90.0;
    return math.atan(dy / dx) * (180.0 / math.pi);
  }

  /// Calcula la inclinación del cuello / cabeza respecto al centro de los hombros.
  static double calculateNeckTilt(
    NormalizedLandmark nose,
    NormalizedLandmark leftShoulder,
    NormalizedLandmark rightShoulder,
  ) {
    final midShoulderX = (leftShoulder.x + rightShoulder.x) / 2.0;
    final dx = (nose.x - midShoulderX).abs();
    final dy = (leftShoulder.y - nose.y).abs();
    if (dy == 0) return 90.0;
    return math.atan(dx / dy) * (180.0 / math.pi);
  }

  /// Distancia euclidiana entre dos landmarks.
  static double distance(NormalizedLandmark a, NormalizedLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dz = a.z - b.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}
