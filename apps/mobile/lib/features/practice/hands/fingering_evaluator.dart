import 'package:equatable/equatable.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/practice/posture/posture_scorer.dart';

/// Landmark normalizado de MediaPipe Hands.
///
/// MediaPipe Hands entrega 21 puntos por mano en coordenadas normalizadas
/// `[0..1]`. Se reutiliza el modelo compartido [NormalizedLandmark] (ya usado
/// por el pipeline postural para las manos en [PoseFrame]) para honrar la
/// continuidad de nomenclatura y la distancia euclidiana de [PostureScorer].
typedef HandLandmark = NormalizedLandmark;

/// Índices canónicos de las yemas (fingertips) en el modelo MediaPipe Hands.
///
/// El orden de los 21 landmarks es fijo en MediaPipe: muñeca (0) y, por cada
/// dedo, la punta (tip) en los índices listados aquí.
abstract final class HandLandmarkIndex {
  static const int wrist = 0;
  static const int thumbTip = 4;
  static const int indexTip = 8;
  static const int middleTip = 12;
  static const int ringTip = 16;
  static const int pinkyTip = 20;

  /// Cantidad de landmarks que MediaPipe Hands emite por mano detectada.
  static const int handLandmarkCount = 21;
}

/// Confianza del seguimiento de manos on-device.
///
/// [low] se emite cuando una mano se pierde/ocluye y se trabaja con la última
/// postura válida retenida (ventana de gracia de 500 ms) — nunca se simula un
/// agarre inexistente.
enum HandTrackingConfidence { high, medium, low }

/// Dedo asignado a cubrir un orificio o alinear un tubo.
enum Finger { thumb, indexFinger, middle, ring, pinky }

/// Orificio/tubo teórico del instrumento en coordenadas normalizadas de cámara.
///
/// Las posiciones son una **plantilla geométrica aproximada** del instrumento
/// (no una calibración por dispositivo); representan la ubicación esperada de
/// cada orificio sobre el eje del instrumento para contrastar contra las yemas.
class InstrumentHole extends Equatable {
  /// Número de orificio del instrumento (p. ej. el orificio 3 de la Quena).
  final int id;

  /// Posición horizontal normalizada `[0..1]` del orificio en cámara.
  final double x;

  /// Posición vertical normalizada `[0..1]` del orificio en cámara.
  final double y;

  /// Dedo que debería cubrir este orificio según la digitación andina.
  final Finger finger;

  const InstrumentHole({
    required this.id,
    required this.x,
    required this.y,
    required this.finger,
  });

  @override
  List<Object?> get props => [id, x, y, finger];
}

/// Digitación objetivo de una nota: qué orificios deben quedar cubiertos.
///
/// Un orificio presente en [coveredHoleIds] exige oclusión hermética; su
/// ausencia indica que debe permanecer abierto (no se penaliza si no se cubre).
class FingeringTarget extends Equatable {
  /// Ids de los orificios que la nota exige cubrir herméticamente.
  final Set<int> coveredHoleIds;

  const FingeringTarget(this.coveredHoleIds);

  /// Digitación en la que todos los orificios del instrumento están cubiertos
  /// (nota más grave): útil como objetivo por defecto y en pruebas.
  const FingeringTarget.allCovered() : coveredHoleIds = const {};

  /// `true` si la nota exige cubrir el orificio [holeId].
  ///
  /// Para [FingeringTarget.allCovered] (conjunto vacío) todos los orificios se
  /// consideran requeridos.
  bool requiresHole(int holeId) =>
      coveredHoleIds.isEmpty || coveredHoleIds.contains(holeId);

  @override
  List<Object?> get props => [coveredHoleIds];
}

/// Resultado de oclusión de un orificio individual.
class HoleCoverage extends Equatable {
  /// Id del orificio evaluado.
  final int holeId;

  /// Dedo asignado al orificio.
  final Finger finger;

  /// `true` si la nota exige cubrir este orificio.
  final bool required;

  /// Distancia euclidiana (normalizada, en plano de cámara) de la yema más
  /// cercana al centro teórico del orificio.
  final double distance;

  /// `true` si la yema asignada cubre el orificio dentro del radio hermético.
  final bool covered;

  const HoleCoverage({
    required this.holeId,
    required this.finger,
    required this.required,
    required this.distance,
    required this.covered,
  });

  /// `true` cuando un orificio requerido no está cubierto: fuga de aire.
  bool get isLeak => required && !covered;

  @override
  List<Object?> get props => [holeId, finger, required, distance, covered];
}

/// Evaluación integral del agarre de una mano sobre el instrumento.
class HandCoverageEvaluation extends Equatable {
  /// Cobertura por orificio (en el orden del mapa geométrico del instrumento).
  final List<HoleCoverage> holes;

  /// Confianza del seguimiento que respalda esta evaluación.
  final HandTrackingConfidence confidence;

  /// Mensajes de retroalimentación de sujeción en español.
  final List<String> feedback;

  const HandCoverageEvaluation({
    required this.holes,
    required this.confidence,
    required this.feedback,
  });

  /// Evaluación degradada cuando no hay landmarks suficientes para medir.
  ///
  /// No inventa cobertura: informa de forma honesta que no se puede evaluar el
  /// agarre (mano fuera de encuadre u ocluida más allá de la ventana de gracia).
  factory HandCoverageEvaluation.lowConfidence() => const HandCoverageEvaluation(
    holes: [],
    confidence: HandTrackingConfidence.low,
    feedback: [
      'No se detecta la mano con claridad: encuadrá los dedos sobre el instrumento.',
    ],
  );

  /// `true` si algún orificio requerido no está cubierto (fuga de aire).
  bool get hasLeak => holes.any((h) => h.isLeak);

  /// `true` si todos los orificios requeridos están cubiertos herméticamente.
  bool get isSealed => holes.where((h) => h.required).every((h) => h.covered);

  /// Orificios requeridos que presentan fuga de aire.
  List<HoleCoverage> get leakingHoles =>
      holes.where((h) => h.isLeak).toList(growable: false);

  @override
  List<Object?> get props => [holes, confidence, feedback];
}

/// Mapa geométrico teórico de orificios por instrumento andino.
///
/// Las coordenadas son una plantilla normalizada aproximada del eje del
/// instrumento (la yema desciende sobre la columna de orificios). Sirven como
/// referencia determinista para contrastar las yemas detectadas; una
/// calibración fina por dispositivo queda fuera del alcance de SUB-07-A.
abstract final class InstrumentHoleMap {
  /// Quena: orificios alcanzables por **una** mano sobre el eje central del
  /// tubo (3 frontales descendentes + el orificio posterior del pulgar).
  ///
  /// Cada orificio se asigna a un dedo **distinto**, coherente con que
  /// [FingeringEvaluator.evaluateHolesCoverage] evalúa una mano por llamada. El
  /// orificio 3 lo cubre el **anular** (clave para la prueba de SUB-07-A). El
  /// mapeo de la segunda mano (orificios inferiores) y la calibración fina por
  /// dispositivo quedan fuera del alcance de SUB-07-A.
  static const List<InstrumentHole> _quena = [
    InstrumentHole(id: 1, x: 0.50, y: 0.24, finger: Finger.indexFinger),
    InstrumentHole(id: 2, x: 0.50, y: 0.40, finger: Finger.middle),
    InstrumentHole(id: 3, x: 0.50, y: 0.56, finger: Finger.ring),
    InstrumentHole(id: 4, x: 0.40, y: 0.48, finger: Finger.thumb),
  ];

  /// Tarka: aerófono de madera; orificios superiores alcanzables por una mano
  /// (índice, medio, anular) sobre un eje ligeramente desplazado del centro.
  static const List<InstrumentHole> _tarka = [
    InstrumentHole(id: 1, x: 0.48, y: 0.26, finger: Finger.indexFinger),
    InstrumentHole(id: 2, x: 0.48, y: 0.42, finger: Finger.middle),
    InstrumentHole(id: 3, x: 0.48, y: 0.58, finger: Finger.ring),
  ];

  /// Zampoña: la digitación valida alineación de yemas con las bocas de los
  /// tubos; se modelan los tubos superiores como anclas sobre la fila.
  static const List<InstrumentHole> _zampona = [
    InstrumentHole(id: 1, x: 0.30, y: 0.30, finger: Finger.indexFinger),
    InstrumentHole(id: 2, x: 0.42, y: 0.30, finger: Finger.middle),
    InstrumentHole(id: 3, x: 0.54, y: 0.30, finger: Finger.ring),
    InstrumentHole(id: 4, x: 0.66, y: 0.30, finger: Finger.pinky),
  ];

  /// Orificios/tubos teóricos del [instrument].
  static List<InstrumentHole> of(InstrumentType instrument) =>
      switch (instrument) {
        InstrumentType.quena => _quena,
        InstrumentType.tarka => _tarka,
        InstrumentType.zampona => _zampona,
      };
}

/// [SUB-07-A] Evaluador de distancia de falanges a orificios/tubos.
///
/// Cruza las coordenadas cartesianas de las yemas (índice, medio, anular, etc.)
/// con el mapa geométrico del instrumento físico y determina, por orificio, si
/// la yema asignada lo cubre herméticamente (distancia ≤ [coverageRadius]) o si
/// hay fuga de aire. Es **pura y determinista**: no toca cámara ni hardware, por
/// lo que es 100% comprobable sin dependencias nativas. Inferencia 100%
/// on-device: ningún landmark sale del dispositivo.
class FingeringEvaluator {
  /// Radio normalizado dentro del cual una yema se considera cubriendo el
  /// orificio de forma hermética (en plano de cámara `[0..1]`).
  final double coverageRadius;

  const FingeringEvaluator({this.coverageRadius = 0.06});

  /// Evalúa la cobertura de los orificios del [instrument] para la mano dada.
  ///
  /// [handLandmarks] son los 21 puntos de MediaPipe Hands de una mano. Si no
  /// hay suficientes landmarks (mano fuera de encuadre u ocluida) retorna
  /// [HandCoverageEvaluation.lowConfidence] sin inventar cobertura. [target]
  /// define qué orificios exige cubrir la nota en curso.
  HandCoverageEvaluation evaluateHolesCoverage(
    List<HandLandmark> handLandmarks,
    InstrumentType instrument,
    FingeringTarget target,
  ) {
    if (handLandmarks.length < HandLandmarkIndex.handLandmarkCount) {
      return HandCoverageEvaluation.lowConfidence();
    }

    final holes = InstrumentHoleMap.of(instrument);
    final coverages = <HoleCoverage>[];
    final feedback = <String>[];

    for (final hole in holes) {
      final tip = handLandmarks[_tipIndexFor(hole.finger)];
      // Distancia en el plano de cámara (x, y): la cobertura del orificio es un
      // fenómeno 2D en pantalla; se neutraliza z para no sesgar por profundidad.
      final distance = PostureScorer.distance(
        NormalizedLandmark(x: tip.x, y: tip.y, z: 0.0),
        NormalizedLandmark(x: hole.x, y: hole.y, z: 0.0),
      );
      final required = target.requiresHole(hole.id);
      final covered = distance <= coverageRadius;

      coverages.add(
        HoleCoverage(
          holeId: hole.id,
          finger: hole.finger,
          required: required,
          distance: distance,
          covered: covered,
        ),
      );

      if (required && !covered) {
        feedback.add(
          'Orificio ${hole.id}: cubrí mejor con el dedo ${_fingerLabel(hole.finger)} para sellar la fuga de aire.',
        );
      }
    }

    if (feedback.isEmpty) {
      feedback.add(
        '¡Agarre hermético! Los dedos sellan los orificios requeridos.',
      );
    }

    return HandCoverageEvaluation(
      holes: coverages,
      confidence: HandTrackingConfidence.high,
      feedback: feedback,
    );
  }

  int _tipIndexFor(Finger finger) => switch (finger) {
    Finger.thumb => HandLandmarkIndex.thumbTip,
    Finger.indexFinger => HandLandmarkIndex.indexTip,
    Finger.middle => HandLandmarkIndex.middleTip,
    Finger.ring => HandLandmarkIndex.ringTip,
    Finger.pinky => HandLandmarkIndex.pinkyTip,
  };

  String _fingerLabel(Finger finger) => switch (finger) {
    Finger.thumb => 'pulgar',
    Finger.indexFinger => 'índice',
    Finger.middle => 'medio',
    Finger.ring => 'anular',
    Finger.pinky => 'meñique',
  };
}
