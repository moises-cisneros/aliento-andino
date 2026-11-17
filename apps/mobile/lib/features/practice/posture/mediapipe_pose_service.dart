import 'dart:async';

import 'package:mobile/features/practice/posture/pose_frame_source.dart';

/// [SUB-06-A] Servicio de cámara + inferencia MediaPipe Pose on-device.
///
/// Implementa [PoseFrameSource]: abre la cámara frontal, ingiere cada
/// `CameraImage` y ejecuta la inferencia de los 33 landmarks de MediaPipe Pose
/// (más 21 por mano) en un **isolate** dedicado, de modo que el procesamiento
/// de visión no congele el hilo de UI y se sostenga el objetivo de ≥24 FPS.
/// Emite un [PoseFrame] por fotograma inferido. La inferencia es 100%
/// on-device: ningún fotograma crudo sale del dispositivo.
///
/// ## Punto de integración (seam) con el motor nativo
/// La inferencia de 33 landmarks de MediaPipe Pose requiere un binding nativo
/// (TFLite/GPU vía plataforma) que no se compila ni ejecuta en el entorno de
/// CI/escritorio actual —en `pubspec.yaml` sólo está enlazado `hand_landmarker`
/// (MediaPipe Hands, 21 landmarks, sólo Android)—. Toda la lógica de estimación
/// de ángulos y alineación es pura y vive en [PostureAnalyzer] detrás de este
/// servicio, por lo que está cubierta por pruebas sin el binding.
///
/// Cuando se incorpore el detector de pose nativo, la cadena
/// `CameraController` → `startImageStream` → isolate (MediaPipe) debe alimentar
/// [_controller] con cada [PoseFrame]; hasta entonces [start] informa de forma
/// honesta que el motor de pose aún no está disponible, sin simular tracking.
class MediaPipePoseService implements PoseFrameSource {
  final StreamController<PoseFrame> _controller =
      StreamController<PoseFrame>.broadcast();

  bool _running = false;

  /// `true` mientras la cámara y el isolate de inferencia están activos.
  bool get isRunning => _running;

  @override
  Stream<PoseFrame> get poseFrameStream => _controller.stream;

  @override
  Future<void> start() async {
    // TODO(aliento-andino): inicializar CameraController frontal, lanzar el
    // isolate de MediaPipe Pose/Hands y reenviar cada fotograma inferido con
    // `_controller.add(PoseFrame(...))`.
    throw const PoseTrackingException(
      'El motor de pose MediaPipe (33 landmarks) aún no está enlazado en este '
      'build. La estimación de ángulos/alineación está lista y probada tras '
      'PoseFrameSource/PostureAnalyzer; falta conectar el detector nativo.',
    );
  }

  @override
  Future<void> stop() async {
    _running = false;
  }

  @override
  Future<void> dispose() async {
    _running = false;
    await _controller.close();
  }
}
