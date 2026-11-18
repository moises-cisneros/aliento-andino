import 'dart:async';
import 'dart:developer' as developer;

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// Log que aparece tanto en debug como en release (a diferencia de debugPrint
/// que es stripped en release).
void _log(String msg) {
  developer.log(msg, name: 'HandTracker');
  // ignore: avoid_print
  print('[HandTracker] $msg');
}

/// Etapas del startup de cámara. El widget consumidor usa esto para mostrar
/// progress UI específico en cada paso.
enum CameraStage { idle, permission, enumerating, initializing, ready, failed }

/// Wrapper sobre `camera` plugin con UX optimizada para práctica de instrumentos andinos.
///
/// **Responsabilidades únicas**:
/// 1. Pedir permission de cámara
/// 2. Enumerar y elegir cámara para enfocar rostro (embocadura) y manos
/// 3. Inicializar el `CameraController` con resolución óptima
/// 4. Exponer el controller para que el widget renderee el preview
/// 5. Auto-fallback de HD a resolución media si el dispositivo falla
///
/// **NO hace**:
/// - Inferencia ML (se removió por OOM en dispositivos low-RAM)
/// - Captura de frames (no se usa)
/// - Procesamiento de imagen
class HandTracker {
  CameraController? _controller;
  final _stageController = StreamController<CameraStage>.broadcast();

  CameraStage _stage = CameraStage.idle;
  bool _lastPermissionPermanentlyDenied = false;
  Future<String?>? _startInProgress;
  int _generation = 0;
  bool _disposed = false;

  static const _permissionTimeout = Duration(seconds: 15);
  static const _cameraListTimeout = Duration(seconds: 40);
  static const _initializationTimeout = Duration(seconds: 40);
  static const _disposeTimeout = Duration(seconds: 3);

  /// Stream de cambios de etapa para actualizar carga, error o preview.
  Stream<CameraStage> get stageStream => _stageController.stream;

  /// Etapa actual (sin esperar al stream).
  CameraStage get stage => _stage;

  /// El `CameraController` listo para pasar a `CameraPreview` widget.
  /// Null si no está inicializado.
  CameraController? get controller => _controller;

  /// True si el último `start()` falló porque el usuario denegó la permission
  /// permanentemente. La UI muestra botón "Abrir ajustes".
  bool get permissionPermanentlyDenied => _lastPermissionPermanentlyDenied;

  void _setStage(CameraStage s) {
    if (_disposed) return;
    _stage = s;
    _stageController.add(s);
    _log('stage → $s');
  }

  bool _isStale(int generation) => _disposed || generation != _generation;

  /// Inicia el preview de cámara. Si la permission no está granted, pide
  /// el dialog. Retorna `null` si OK, o un mensaje de error user-facing.
  Future<String?> start() => _beginStart();

  Future<String?> _beginStart() {
    final activeStart = _startInProgress;
    if (activeStart != null) return activeStart;

    final generation = ++_generation;
    final operation = _startInternal(generation);
    _startInProgress = operation;
    operation.whenComplete(() {
      if (identical(_startInProgress, operation)) {
        _startInProgress = null;
      }
    });
    return operation;
  }

  Future<String?> _startInternal(int generation) async {
    final PermissionStatus initialStatus;
    try {
      initialStatus = await Permission.camera.status;
    } catch (e) {
      _log('Permission.status excepción: $e');
      if (!_isStale(generation)) _setStage(CameraStage.failed);
      return 'No se pudo comprobar el permiso de cámara: $e';
    }
    if (_isStale(generation)) return null;

    var status = initialStatus;
    var requestedPermission = false;
    if (!status.isGranted) {
      requestedPermission = true;
      _setStage(CameraStage.permission);
      // Timeout defensivo: algunos firmwares dejan la request pendiente si
      // cierran el dialog sin devolver resultado.
      try {
        status = await Permission.camera.request().timeout(
          _permissionTimeout,
          onTimeout: () async {
            _log('Permission.request() timeout — reconsultando estado');
            return Permission.camera.status;
          },
        );
      } catch (e) {
        _log('Permission.request() excepción: $e');
        if (!_isStale(generation)) _setStage(CameraStage.failed);
        return 'Error pidiendo permiso de cámara: $e';
      }
    }

    if (_isStale(generation)) return null;
    _log('permission status: $status');
    if (status.isPermanentlyDenied) {
      _lastPermissionPermanentlyDenied = true;
      _setStage(CameraStage.failed);
      return 'Permiso de cámara denegado. Abrí ajustes para habilitarlo.';
    }
    if (!status.isGranted) {
      _setStage(CameraStage.failed);
      return 'Permiso de cámara denegado. Tocá "Reintentar" para volver a pedirlo.';
    }
    _lastPermissionPermanentlyDenied = false;

    if (requestedPermission) {
      // Tras el dialog, MIUI tarda brevemente en devolver el recurso.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (_isStale(generation)) return null;
    }
    return _runStartFlow(generation);
  }

  /// Lógica post-permission: enumerar cámaras + initialize controller.
  Future<String?> _runStartFlow(int generation) async {
    if (_isStale(generation)) return null;
    _setStage(CameraStage.enumerating);
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras().timeout(_cameraListTimeout);
    } on TimeoutException {
      _log('availableCameras() timeout');
      if (!_isStale(generation)) _setStage(CameraStage.failed);
      return 'La cámara tardó demasiado en responder. Tocá "Reintentar".';
    } catch (e) {
      _log('availableCameras() falló: $e');
      if (!_isStale(generation)) _setStage(CameraStage.failed);
      return 'No se pudo acceder a las cámaras: $e';
    }
    if (_isStale(generation)) return null;
    _log('cámaras detectadas: ${cameras.length}');
    if (cameras.isEmpty) {
      _setStage(CameraStage.failed);
      return 'Este dispositivo no tiene cámara disponible';
    }

    // Cámara para enfocar rostro (embocadura) y manos sosteniendo el instrumento andino.
    // Preferir frontal para verse en espejo o trasera si el dispositivo se coloca al frente.
    final selectedCam =
        cameras
            .where((c) => c.lensDirection == CameraLensDirection.front)
            .firstOrNull ??
        cameras
            .where((c) => c.lensDirection == CameraLensDirection.back)
            .firstOrNull ??
        cameras.first;

    _setStage(CameraStage.initializing);
    // Resolución más baja = mucho menos costo por frame (la conversión YUV para
    // MediaPipe es lo caro; el modelo igual reescala internamente a ~256px).
    // medium (480p) alcanza de sobra para detectar manos y va más fluido; high
    // (720p) y low quedan de respaldo si medium no negocia en algún equipo.
    const presetsToTry = <ResolutionPreset>[
      ResolutionPreset.medium,
      ResolutionPreset.high,
      ResolutionPreset.low,
    ];

    String? lastError;
    for (final preset in presetsToTry) {
      if (_isStale(generation)) return null;
      _log('intentando ${selectedCam.name} con $preset...');
      final controller = CameraController(
        selectedCam,
        preset,
        enableAudio: false,
      );
      _controller = controller;
      final initialization = controller.initialize();
      try {
        await initialization.timeout(_initializationTimeout);
        if (_isStale(generation)) {
          await _disposeControllerSafe(controller);
          return null;
        }

        final ps = controller.value.previewSize;
        if (ps == null || ps.width == 0 || ps.height == 0) {
          _log('previewSize inválido con $preset, probando siguiente');
          await _disposeControllerSafe(controller);
          lastError = 'previewSize inválido';
          continue;
        }

        _setStage(CameraStage.ready);
        _log('lista a $preset (${ps.width.toInt()}x${ps.height.toInt()})');
        return null;
      } on TimeoutException {
        _log('$preset timeout al inicializar');
        lastError = 'timeout al inicializar';
        unawaited(
          initialization.then<void>(
            (_) => _disposeControllerSafe(controller),
            onError: (_) => _disposeControllerSafe(controller),
          ),
        );
        await _disposeControllerSafe(controller);
        break;
      } catch (e) {
        _log('$preset falló: $e');
        lastError = '$e';
        await _disposeControllerSafe(controller);
      }
    }

    if (!_isStale(generation)) _setStage(CameraStage.failed);
    return 'No se pudo iniciar la cámara: $lastError';
  }

  Future<void> _disposeControllerSafe([CameraController? target]) async {
    final controller = target ?? _controller;
    try {
      await controller?.dispose().timeout(_disposeTimeout);
    } catch (_) {}
    if (identical(_controller, controller)) _controller = null;
  }

  Future<void> stop() async {
    _log('stop()');
    _generation++;
    _startInProgress = null;
    await _disposeControllerSafe();
    _setStage(CameraStage.idle);
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    _startInProgress = null;
    await _disposeControllerSafe();
    await _stageController.close();
  }
}
