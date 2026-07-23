import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

/// Corre **MediaPipe Hand Landmarker** sobre el stream de la cámara y expone las
/// manos detectadas (21 puntos cada una) para dibujar el esqueleto como coaching
/// de **postura/digitación**. NO juzga la nota — eso lo hacen mic/MIDI.
///
/// El ML on-device se había quitado antes por OOM en celulares de poca RAM, así
/// que acá hay mitigaciones explícitas:
/// - **throttle** a ~7 fps (no procesa cada frame),
/// - máximo **2 manos**,
/// - delegate **GPU** (más rápido y menos CPU); si falla, cae a **CPU**,
/// - libera el plugin y corta el stream en [dispose].
///
/// Solo Android (el plugin usa JNI/MediaPipe nativo). En iOS no se instancia.
class HandLandmarkerService {
  HandLandmarkerPlugin? _plugin;
  CameraController? _controller;
  bool _streaming = false;
  bool _disposed = false;
  bool _busy = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minInterval = Duration(milliseconds: 130); // ~7-8 fps

  /// Manos detectadas en el último frame procesado (vacío = ninguna).
  final ValueNotifier<List<Hand>> hands = ValueNotifier<List<Hand>>([]);

  /// Crea el detector y empieza a consumir frames del [controller].
  Future<void> start(CameraController controller) async {
    if (_disposed) return;
    _controller = controller;
    _plugin ??= _createPlugin();
    if (_plugin == null) return;

    if (_streaming) return;
    try {
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } catch (e) {
      debugPrint('HandLandmarker: no se pudo iniciar el stream: $e');
    }
  }

  HandLandmarkerPlugin? _createPlugin() {
    try {
      return HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.5,
      );
    } catch (_) {
      // GPU puede no estar disponible en algunos dispositivos → CPU.
      try {
        return HandLandmarkerPlugin.create(
          numHands: 2,
          minHandDetectionConfidence: 0.5,
        );
      } catch (e) {
        debugPrint('HandLandmarker: no se pudo crear el detector: $e');
        return null;
      }
    }
  }

  void _onFrame(CameraImage image) {
    if (_disposed || _busy) return;
    final now = DateTime.now();
    if (now.difference(_lastRun) < _minInterval) return;
    _lastRun = now;

    final plugin = _plugin;
    final controller = _controller;
    if (plugin == null || controller == null) return;

    _busy = true;
    try {
      final orientation = controller.description.sensorOrientation;
      hands.value = plugin.detect(image, orientation);
    } catch (_) {
      // Formato YUV inesperado u otro error puntual: ignorar este frame.
    } finally {
      _busy = false;
    }
  }

  /// Corta el stream sin liberar el detector (para pausar y reanudar).
  Future<void> stop() async {
    final controller = _controller;
    if (_streaming && controller != null) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    _streaming = false;
    if (!_disposed) hands.value = [];
  }

  void dispose() {
    // Orden importante: marcar disposed primero para que _onFrame (que corre en
    // el mismo isolate) salga temprano y no toque el plugin liberado.
    _disposed = true;
    final controller = _controller;
    if (_streaming && controller != null) {
      controller.stopImageStream().catchError((_) {});
      _streaming = false;
    }
    final plugin = _plugin;
    _plugin = null;
    plugin?.dispose();
    hands.dispose();
  }
}
