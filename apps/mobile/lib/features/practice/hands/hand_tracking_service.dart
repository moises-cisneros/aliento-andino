import 'package:equatable/equatable.dart';

import 'package:mobile/features/practice/hands/fingering_evaluator.dart';

/// Excepción ante la pérdida sostenida del seguimiento de manos.
///
/// Se emite sólo cuando una mano permanece ocluida/fuera de encuadre más allá
/// de la ventana de gracia: nunca se simula una postura inexistente.
class HandTrackingLostException implements Exception {
  final String message;
  const HandTrackingLostException([
    this.message =
        'Se perdió el seguimiento de la mano por más de la ventana de gracia.',
  ]);

  @override
  String toString() => 'HandTrackingLostException: $message';
}

/// Resultado de un paso de seguimiento de una mano.
class HandTrackingResult extends Equatable {
  /// Landmarks de la mano disponibles para evaluar; pueden ser la **última
  /// postura válida retenida** durante la ventana de gracia ([isStale] = true).
  /// `null` cuando la mano se perdió más allá de la gracia ([isLost] = true).
  final List<HandLandmark>? landmarks;

  /// Confianza del seguimiento en este paso.
  final HandTrackingConfidence confidence;

  /// `true` si [landmarks] corresponde a una postura retenida (no al frame
  /// actual) porque la mano está momentáneamente ocluida.
  final bool isStale;

  /// `true` si la mano se perdió más allá de la ventana de gracia.
  final bool isLost;

  const HandTrackingResult({
    required this.landmarks,
    required this.confidence,
    required this.isStale,
    required this.isLost,
  });

  @override
  List<Object?> get props => [landmarks, confidence, isStale, isLost];
}

/// [SUB-07-A] Máquina de estados de seguimiento de manos tolerante a oclusión.
///
/// Ingiere la detección de MediaPipe Hands frame a frame (los 21 landmarks de
/// la mano, o `null` cuando la mano se pierde porque la otra la ocluye) y aplica
/// la política de tolerancia: si una mano se pierde temporalmente se marca el
/// estado como [HandTrackingConfidence.low] y se **conserva la última postura
/// válida** durante [graceWindow] (500 ms por defecto) antes de declarar la
/// pérdida.
///
/// Es pura y determinista: el reloj se inyecta ([clock]) para ejercitar la
/// ventana de gracia en pruebas sin timers reales ni dependencias nativas.
class HandTrackingService {
  /// Ventana durante la cual se retiene la última postura válida tras perder la
  /// mano antes de declarar el seguimiento perdido.
  final Duration graceWindow;

  final DateTime Function() _clock;

  List<HandLandmark>? _lastValid;
  DateTime? _lastValidAt;

  HandTrackingService({
    this.graceWindow = const Duration(milliseconds: 500),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// `true` si hay una postura válida vigente (reciente o dentro de la gracia).
  bool get hasValidPose => _lastValid != null;

  /// Procesa la detección del frame actual.
  ///
  /// [detected] son los landmarks de la mano del frame (≥21 puntos) o `null` si
  /// la mano no fue detectada. Devuelve el [HandTrackingResult] resultante
  /// aplicando la ventana de gracia ante oclusiones transitorias.
  HandTrackingResult track(List<HandLandmark>? detected) {
    final now = _clock();

    final isFreshDetection =
        detected != null &&
        detected.length >= HandLandmarkIndex.handLandmarkCount;

    if (isFreshDetection) {
      _lastValid = detected;
      _lastValidAt = now;
      return HandTrackingResult(
        landmarks: detected,
        confidence: HandTrackingConfidence.high,
        isStale: false,
        isLost: false,
      );
    }

    // Mano no detectada (ocluida por la otra o fuera de encuadre).
    final lastAt = _lastValidAt;
    final withinGrace =
        _lastValid != null &&
        lastAt != null &&
        now.difference(lastAt) <= graceWindow;

    if (withinGrace) {
      // Se conserva la última postura válida: estado de baja confianza.
      return HandTrackingResult(
        landmarks: _lastValid,
        confidence: HandTrackingConfidence.low,
        isStale: true,
        isLost: false,
      );
    }

    // Se superó la ventana de gracia: seguimiento perdido, sin postura.
    _lastValid = null;
    _lastValidAt = null;
    return const HandTrackingResult(
      landmarks: null,
      confidence: HandTrackingConfidence.low,
      isStale: true,
      isLost: true,
    );
  }

  /// Reinicia el estado retenido (al pausar o cambiar de lección).
  void reset() {
    _lastValid = null;
    _lastValidAt = null;
  }
}
