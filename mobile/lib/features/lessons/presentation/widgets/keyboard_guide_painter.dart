import 'package:flutter/material.dart';

/// Guía de encuadre del teclado: dibuja esquinas tipo "visor" sobre la zona
/// inferior-central del preview (donde deberían quedar el teclado y las manos)
/// + un texto de ayuda. Es ESTÁTICO (no depende de los frames de la cámara ni
/// de las manos), así que no agrega costo por frame.
class KeyboardGuidePainter extends CustomPainter {
  final Color color;
  const KeyboardGuidePainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // Zona sugerida: ancho casi completo, mitad inferior (el teclado va al
    // frente y las manos encima).
    final rect = Rect.fromLTRB(
      size.width * 0.06,
      size.height * 0.32,
      size.width * 0.94,
      size.height * 0.92,
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
        text: 'Encuadrá el teclado y tus manos aquí',
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
