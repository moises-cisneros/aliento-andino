import 'dart:math' as math;

import 'package:hand_landmarker/hand_landmarker.dart';

/// Análisis de postura de la mano a partir de los 21 landmarks (x,y,z) de
/// MediaPipe. Pensado para dar una GUÍA aproximada (no un juicio profesional):
/// una sola cámara desde un ángulo no alcanza para técnica fina.
///
/// Métrica principal (la más importante para principiantes y la más robusta
/// al ángulo, usando 3D): la CURVATURA de los dedos. Dedos curvados (forma de
/// cúpula) = bien; dedos planos/estirados = a corregir.
class PostureAnalyzer {
  // Índice, medio, anular y meñique: [MCP(nudillo), PIP, DIP, TIP(yema)].
  static const List<List<int>> _fingers = [
    [5, 6, 7, 8],
    [9, 10, 11, 12],
    [13, 14, 15, 16],
    [17, 18, 19, 20],
  ];

  /// Por encima de este "straightness" (0..1) los dedos se consideran planos.
  /// Conservador a propósito: solo marca dedos claramente estirados.
  static const double flatThreshold = 0.96;

  /// "Straightness" promedio de los 4 dedos: 1.0 = totalmente estirado (yema lo
  /// más lejos posible del nudillo); valores menores = más curvado. Devuelve
  /// null si los landmarks no alcanzan o son degenerados.
  static double? fingerStraightness(List<Landmark> lm) {
    if (lm.length < 21) return null;
    var sum = 0.0;
    var n = 0;
    for (final f in _fingers) {
      final chain = _d(lm[f[0]], lm[f[1]]) +
          _d(lm[f[1]], lm[f[2]]) +
          _d(lm[f[2]], lm[f[3]]);
      if (chain <= 1e-6) continue;
      final ratio = (_d(lm[f[0]], lm[f[3]]) / chain).clamp(0.0, 1.0);
      sum += ratio;
      n++;
    }
    if (n == 0) return null;
    return sum / n;
  }

  static double _d(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dz = a.z - b.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}
