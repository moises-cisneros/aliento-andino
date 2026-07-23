import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/hand_landmarker_service.dart';
import '../services/hand_tracker.dart';
import 'hand_landmarks_painter.dart';
import 'keyboard_guide_painter.dart';

/// Widget que renderiza el preview de cámara para piano practice.
class HandTrackerCamera extends StatefulWidget {
  /// Si true, llena la pantalla con BoxFit.cover.
  final bool fullScreen;
  final HandTracker? externalTracker;

  /// Callback en cada actualización de manos detectadas (para agregar stats que
  /// alimentan el feedback con IA). Se llama ~al ritmo del detector (~7fps).
  final void Function(List<Hand> hands)? onHands;

  const HandTrackerCamera({
    super.key,
    this.fullScreen = true,
    this.externalTracker,
    this.onHands,
  });

  @override
  State<HandTrackerCamera> createState() => _HandTrackerCameraState();
}

class _HandTrackerCameraState extends State<HandTrackerCamera>
    with WidgetsBindingObserver {
  late final HandTracker _tracker;
  late final bool _ownsTracker;
  StreamSubscription<CameraStage>? _stageSub;
  CameraStage _stage = CameraStage.idle;
  String? _error;
  bool _restartOnResume = false;

  /// Detector de manos (MediaPipe). Solo Android; null en otras plataformas.
  HandLandmarkerService? _landmarker;

  @override
  void initState() {
    super.initState();
    _tracker = widget.externalTracker ?? HandTracker();
    _ownsTracker = widget.externalTracker == null;
    _stage = _tracker.stage;
    WidgetsBinding.instance.addObserver(this);
    _stageSub = _tracker.stageStream.listen((s) {
      if (!mounted) return;
      setState(() => _stage = s);
      _syncLandmarker(s);
    });
    if (_stage == CameraStage.idle || _stage == CameraStage.failed) {
      _start();
    } else {
      _syncLandmarker(_stage);
    }
  }

  /// Arranca/pausa la detección de manos según la etapa de la cámara.
  void _syncLandmarker(CameraStage s) {
    if (!Platform.isAndroid) return; // el plugin es solo Android
    if (s == CameraStage.ready) {
      final controller = _tracker.controller;
      if (controller == null) return;
      var svc = _landmarker;
      if (svc == null) {
        svc = HandLandmarkerService();
        _landmarker = svc;
        if (widget.onHands != null) svc.hands.addListener(_emitHands);
      }
      svc.start(controller);
    } else {
      _landmarker?.stop();
    }
  }

  void _emitHands() {
    final svc = _landmarker;
    if (svc != null) widget.onHands?.call(svc.hands.value);
  }

  Future<void> _start() async {
    final err = await _tracker.start();
    if (!mounted) return;
    setState(() => _error = err);
  }

  Future<void> _retry() async {
    setState(() {
      _stage = CameraStage.idle;
      _error = null;
    });
    await _tracker.stop();
    await _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // El dialog de permiso provoca inactive; no cortamos esa solicitud.
      if (_stage == CameraStage.enumerating ||
          _stage == CameraStage.initializing ||
          _stage == CameraStage.ready) {
        _restartOnResume = true;
        _tracker.stop();
      }
      return;
    }

    if (state == AppLifecycleState.resumed && _restartOnResume) {
      _restartOnResume = false;
      setState(() => _error = null);
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stageSub?.cancel();
    _landmarker?.hands.removeListener(_emitHands);
    _landmarker?.dispose();
    _landmarker = null;
    if (_ownsTracker) {
      _tracker.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Keep startup feedback unobtrusive while Android opens the camera.
    if (_stage != CameraStage.ready && _error == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      );
    }

    if (_error != null) {
      final permPerm = _tracker.permissionPermanentlyDenied;
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 36),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (permPerm)
                  ElevatedButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Ajustes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final controller = _tracker.controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(color: Colors.black);
    }

    final preview = _previewWithOverlay(controller);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.fullScreen)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.previewSize?.height ?? 1,
              height: controller.value.previewSize?.width ?? 1,
              child: preview,
            ),
          )
        else
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: preview,
          ),

        // Badge: estado de la cámara + cuántas manos detecta.
        Positioned(top: 8, left: 8, child: _buildBadge()),
      ],
    );
  }

  /// Preview de cámara con el esqueleto de manos pintado encima, en el MISMO
  /// espacio de coordenadas (así el FittedBox/AspectRatio los escala juntos y el
  /// overlay queda alineado con la imagen).
  Widget _previewWithOverlay(CameraController controller) {
    final preview = CameraPreview(controller);
    final svc = _landmarker;
    final ps = controller.value.previewSize;
    if (svc == null || ps == null) return preview;
    return Stack(
      fit: StackFit.expand,
      children: [
        preview,
        // Guía de encuadre del teclado (estática: no repinta por frame).
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: KeyboardGuidePainter()),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<List<Hand>>(
              valueListenable: svc.hands,
              builder: (context, hands, _) {
                return CustomPaint(
                  painter: HandLandmarksPainter(
                    hands: hands,
                    previewSize: ps,
                    sensorOrientation: controller.description.sensorOrientation,
                    lensDirection: controller.description.lensDirection,
                    color: const Color(0xFF00E676),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge() {
    final svc = _landmarker;
    Container box(Widget child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
          ),
          child: child,
        );

    if (svc == null) {
      return box(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BlinkDot(),
            SizedBox(width: 6),
            Text(
              'cámara en vivo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<List<Hand>>(
      valueListenable: svc.hands,
      builder: (context, hands, _) {
        final n = hands.length;
        final detecting = n > 0;
        final label = n == 0
            ? 'buscando manos…'
            : (n == 1 ? '1 mano detectada' : '$n manos detectadas');
        return box(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                detecting ? Icons.back_hand : Icons.back_hand_outlined,
                color: detecting ? const Color(0xFF00E676) : Colors.white70,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pequeño punto rojo que parpadea para reforzar "live".
class _BlinkDot extends StatefulWidget {
  const _BlinkDot();

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_ctrl),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
