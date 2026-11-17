import 'dart:math' as math;

import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

/// Dibuja el esqueleto de las manos detectadas (21 puntos + conexiones) sobre
/// el preview de cámara.
///
/// Los landmarks de MediaPipe vienen normalizados (0..1) en el **espacio del
/// sensor** (sin rotar), por eso el canvas se centra y se rota por
/// `sensorOrientation` (y se espeja para cámara frontal), igual que el ejemplo
/// oficial del paquete. Pensado para pintarse DENTRO del mismo SizedBox que el
/// `CameraPreview`, para que el `FittedBox`/`AspectRatio` los escale juntos.
class HandLandmarksPainter extends CustomPainter {
  final List<Hand> hands;

  /// Tamaño del sensor (orientación nativa, normalmente landscape).
  final Size previewSize;
  final int sensorOrientation;
  final CameraLensDirection lensDirection;
  final Color color;

  HandLandmarksPainter({
    required this.hands,
    required this.previewSize,
    required this.sensorOrientation,
    required this.lensDirection,
    required this.color,
  });

  // Conexiones estándar de MediaPipe entre los 21 landmarks de la mano.
  static const List<List<int>> _connections = [
    [0, 1], [1, 2], [2, 3], [3, 4], // pulgar
    [0, 5], [5, 6], [6, 7], [7, 8], // índice
    [5, 9], [9, 10], [10, 11], [11, 12], // medio
    [9, 13], [13, 14], [14, 15], [15, 16], // anular
    [13, 17], [17, 18], [18, 19], [19, 20], // meñique
    [0, 17], // base de la palma
  ];

  // Yemas de los dedos (pulgar, índice, medio, anular, meñique).
  static const List<int> _fingertips = [4, 8, 12, 16, 20];

  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty || previewSize.height == 0) return;

    final scale = size.width / previewSize.height;
    // Esqueleto fino (menos saturado y más liviano que la versión de 21 puntos).
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2.5 / scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final tipPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final tipBorder = Paint()
      ..color = color
      ..strokeWidth = 1.5 / scale
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(sensorOrientation * math.pi / 180);
    if (lensDirection == CameraLensDirection.front) {
      canvas.scale(-1, 1);
      canvas.rotate(math.pi);
    }
    canvas.scale(scale);

    final w = previewSize.width;
    final h = previewSize.height;

    for (final hand in hands) {
      if (hand.landmarks.length < 21) continue;
      Offset p(int i) => Offset(
        (hand.landmarks[i].x - 0.5) * w,
        (hand.landmarks[i].y - 0.5) * h,
      );
      for (final c in _connections) {
        canvas.drawLine(p(c[0]), p(c[1]), linePaint);
      }
      // Solo las YEMAS de los dedos (pulgar..meñique): es lo que importa para
      // tocar, y evita la nube de 21 puntos que cargaba la imagen.
      for (final i in _fingertips) {
        canvas.drawCircle(p(i), 5 / scale, tipPaint);
        canvas.drawCircle(p(i), 5 / scale, tipBorder);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HandLandmarksPainter old) =>
      old.hands != hands ||
      old.previewSize != previewSize ||
      old.sensorOrientation != sensorOrientation ||
      old.lensDirection != lensDirection ||
      old.color != color;
}
