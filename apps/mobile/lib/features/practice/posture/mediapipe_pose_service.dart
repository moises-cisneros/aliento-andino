import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:mobile/features/practice/posture/pose_frame_source.dart';
import 'package:mobile/features/practice/posture/pose_landmark_mapper.dart';

/// [SUB-06-A] Front camera + on-device BlazePose (MediaPipe lineage) service.
///
/// Opens the front camera, streams every frame into the ML Kit pose detector
/// (33 landmarks, bundled model, no network) and emits one [PoseFrame] per
/// inferred frame. Frames that arrive while a previous one is still being
/// processed are dropped, so the UI thread is never starved and latency stays
/// bounded. Nothing leaves the device: no frame is stored or uploaded.
///
/// Hands are tracked by the separate `HandLandmarkerService` (Android only);
/// this source emits pose landmarks only.
class MediaPipePoseService implements PoseFrameSource {
  static const Map<DeviceOrientation, int> _deviceDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final StreamController<PoseFrame> _controller =
      StreamController<PoseFrame>.broadcast();
  final PoseDetector Function() _detectorFactory;

  CameraController? _camera;
  PoseDetector? _detector;
  CameraDescription? _description;
  bool _running = false;
  bool _busy = false;

  MediaPipePoseService({PoseDetector Function()? detectorFactory})
    : _detectorFactory = detectorFactory ?? _defaultDetector;

  static PoseDetector _defaultDetector() => PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  /// `true` while the camera and the detector are active.
  bool get isRunning => _running;

  @override
  Stream<PoseFrame> get poseFrameStream => _controller.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const PoseTrackingException(
          'No se encontró ninguna cámara en este dispositivo.',
        );
      }
      final description = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _camera = camera;
      _description = description;
      await camera.initialize();

      _detector = _detectorFactory();
      _running = true;
      await camera.startImageStream(_onImage);
    } on CameraException catch (e) {
      await _release();
      if (e.code.startsWith('CameraAccess')) {
        throw CameraPermissionDeniedException(
          e.description ?? 'Permiso de cámara denegado',
        );
      }
      throw PoseTrackingException(
        'No se pudo abrir la cámara: ${e.description ?? e.code}',
      );
    } on PoseTrackingException {
      await _release();
      rethrow;
    } catch (e) {
      await _release();
      throw PoseTrackingException(
        'No se pudo iniciar la detección de pose: $e',
      );
    }
  }

  Future<void> _onImage(CameraImage image) async {
    if (!_running || _busy) return;
    final detector = _detector;
    final input = _toInputImage(image);
    if (detector == null || input == null) return;

    _busy = true;
    try {
      final poses = await detector.processImage(input);
      if (!_running || poses.isEmpty || _controller.isClosed) return;
      final metadata = input.metadata!;
      final swap = rotationSwapsAxes(metadata.rotation.rawValue);
      final frame = poseFrameFromMlKit(
        poses.first,
        uprightWidth: swap ? metadata.size.height : metadata.size.width,
        uprightHeight: swap ? metadata.size.width : metadata.size.height,
      );
      if (frame != null) _controller.add(frame);
    } catch (e, st) {
      debugPrint('MediaPipePoseService: frame descartado: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final description = _description;
    if (camera == null || description == null) return null;

    final degrees = inputRotationDegrees(
      sensorOrientation: description.sensorOrientation,
      deviceOrientationDegrees:
          _deviceDegrees[camera.value.deviceOrientation] ?? 0,
      isFrontCamera: description.lensDirection == CameraLensDirection.front,
      isAndroid: Platform.isAndroid,
    );
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    // ML Kit only accepts single-plane NV21 (Android) / BGRA8888 (iOS).
    if (image.planes.length != 1) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _release() async {
    _running = false;
    final camera = _camera;
    final detector = _detector;
    _camera = null;
    _detector = null;
    try {
      if (camera != null && camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
    } catch (_) {}
    try {
      await camera?.dispose();
    } catch (_) {}
    try {
      await detector?.close();
    } catch (_) {}
  }

  @override
  Future<void> stop() => _release();

  @override
  Future<void> dispose() async {
    await _release();
    if (!_controller.isClosed) await _controller.close();
  }
}
