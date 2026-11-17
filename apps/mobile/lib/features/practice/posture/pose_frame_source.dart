import 'package:equatable/equatable.dart';

import 'package:mobile/features/practice/posture/posture_scorer.dart';

/// Excepción lanzada cuando el usuario deniega el permiso de cámara frontal.
class CameraPermissionDeniedException implements Exception {
  final String message;
  const CameraPermissionDeniedException([
    this.message = 'Permiso de cámara denegado',
  ]);

  @override
  String toString() => 'CameraPermissionDeniedException: $message';
}

/// Excepción ante fallos de hardware, inicialización o del modelo de visión.
class PoseTrackingException implements Exception {
  final String message;
  const PoseTrackingException([
    this.message = 'Fallo al iniciar el seguimiento postural on-device',
  ]);

  @override
  String toString() => 'PoseTrackingException: $message';
}

/// Fotograma de inferencia de visión por computadora emitido por el pipeline
/// MediaPipe on-device: 33 landmarks de pose corporal y, opcionalmente, 21
/// landmarks por cada mano (MediaPipe Hands) para la digitación.
class PoseFrame extends Equatable {
  /// 33 landmarks normalizados de MediaPipe Pose.
  final List<NormalizedLandmark> poseLandmarks;

  /// 21 landmarks de la mano izquierda (null si no se detecta).
  final List<NormalizedLandmark>? leftHandLandmarks;

  /// 21 landmarks de la mano derecha (null si no se detecta).
  final List<NormalizedLandmark>? rightHandLandmarks;

  const PoseFrame({
    required this.poseLandmarks,
    this.leftHandLandmarks,
    this.rightHandLandmarks,
  });

  @override
  List<Object?> get props => [
    poseLandmarks,
    leftHandLandmarks,
    rightHandLandmarks,
  ];
}

/// Fuente desacoplada de fotogramas de pose.
///
/// Aísla la adquisición de cámara + inferencia nativa (MediaPipe Pose/Hands)
/// del resto de la aplicación, de modo que la lógica de evaluación postural
/// ([MediaPipePosturePipeline]) y el [Bloc] sean 100% comprobables sin
/// dependencias nativas. En pruebas se inyecta una implementación simulada que
/// emite fotogramas deterministas; en producción, [MediaPipePoseFrameSource]
/// enlaza con el canal nativo.
abstract class PoseFrameSource {
  /// Stream reactivo de fotogramas de pose inferidos on-device (objetivo ≥24 FPS).
  Stream<PoseFrame> get poseFrameStream;

  /// Abre la cámara frontal e inicia la inferencia de pose on-device.
  ///
  /// Lanza [CameraPermissionDeniedException] si falta el permiso de cámara y
  /// [PoseTrackingException] ante cualquier otro fallo de inicialización.
  Future<void> start();

  /// Detiene la inferencia y libera la cámara.
  Future<void> stop();

  /// Libera todos los recursos y cierra el stream.
  Future<void> dispose();
}
