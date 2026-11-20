import 'package:flutter/material.dart';

/// Guía de encuadre para práctica de aerófonos andinos: dibuja esquinas tipo "visor"
/// sobre la zona del preview para encuadrar rostro (embocadura) y manos
/// sosteniendo el instrumento andino + un texto de ayuda estático.
class KeyboardGuidePainter extends CustomPainter {
  final Color color;
  const KeyboardGuidePainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // Zona sugerida: encuadre para embocadura, postura y digitación con ambas manos.
    final rect = Rect.fromLTRB(
      size.width * 0.08,
      size.height * 0.15,
      size.width * 0.92,
      size.height * 0.88,
    );

    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Largo de cada "L" de esquina.
    final len = (size.width * 0.07).clamp(14.0, 48.0);

    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o + Offset(dx, 0), paint);
      canvas.drawLine(o, o + Offset(0, dy), paint);
    }

    corner(rect.topLeft, len, len);
    corner(rect.topRight, -len, len);
    corner(rect.bottomLeft, len, -len);
    corner(rect.bottomRight, -len, -len);

    // Etiqueta centrada arriba de la zona.
    final tp = TextPainter(
      text: TextSpan(
        text: 'Encuadrá embocadura y manos aquí',
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: rect.width);
    tp.paint(
      canvas,
      Offset(rect.left + (rect.width - tp.width) / 2, rect.top - tp.height - 6),
    );
  }

  @override
  bool shouldRepaint(covariant KeyboardGuidePainter old) => old.color != color;
}
