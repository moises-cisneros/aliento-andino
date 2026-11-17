import 'dart:async';

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

/// Punto de integración (seam) con el motor nativo MediaPipe Pose.
///
/// La inferencia postural de 33 landmarks de MediaPipe Pose requiere un binding
/// nativo (TFLite/GPU vía plataforma) que no se compila ni ejecuta en el entorno
/// de CI/escritorio actual —en `pubspec.yaml` sólo está enlazado
/// `hand_landmarker` (MediaPipe Hands, 21 landmarks, sólo Android)—. Toda la
/// lógica de evaluación (ángulos, alineación y puntuación 0–100) es pura y vive
/// detrás de esta interfaz en [MediaPipePosturePipeline], por lo que está
/// cubierta por pruebas sin necesidad del binding.
///
/// Cuando se incorpore el detector de pose nativo, alimentar [_controller] con
/// cada [PoseFrame] inferido dentro de [start]; hasta entonces la activación
/// informa explícitamente que el motor de pose aún no está disponible en lugar
/// de simular un seguimiento inexistente.
class MediaPipePoseFrameSource implements PoseFrameSource {
  final StreamController<PoseFrame> _controller =
      StreamController<PoseFrame>.broadcast();

  @override
  Stream<PoseFrame> get poseFrameStream => _controller.stream;

  @override
  Future<void> start() async {
    // TODO(aliento-andino): enlazar MediaPipe Pose (33 landmarks) vía canal
    // nativo y reenviar cada fotograma inferido a `_controller.add(...)`.
    throw const PoseTrackingException(
      'El motor de pose MediaPipe (33 landmarks) aún no está enlazado en este '
      'build. La evaluación postural (ángulos/alineación/score) está lista y '
      'probada tras PoseFrameSource; falta conectar el detector nativo.',
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
