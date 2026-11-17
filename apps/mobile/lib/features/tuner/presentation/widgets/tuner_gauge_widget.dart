import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget visual del dial de afinación con aguja reactiva, estados Calado/Afinado/Alto y cents.
class TunerGaugeWidget extends StatefulWidget {
  final double cents; // Rango: -50.0 a +50.0
  final double frequencyHz;
  final String noteName;
  final bool isTuned;
  final bool isSilent;
  final double toleranceCents;

  const TunerGaugeWidget({
    super.key,
    required this.cents,
    required this.frequencyHz,
    required this.noteName,
    required this.isTuned,
    this.isSilent = false,
    this.toleranceCents = 15.0,
  });

  @override
  State<TunerGaugeWidget> createState() => _TunerGaugeWidgetState();
}

class _TunerGaugeWidgetState extends State<TunerGaugeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _displayedCents = 0.0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 100),
        )..addListener(() {
          setState(() {});
        });
  }

  @override
  void didUpdateWidget(covariant TunerGaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.isSilent ? 0.0 : widget.cents.clamp(-50.0, 50.0);
    // Interpolación suave (lerp) para evitar saltos bruscos
    _displayedCents = _displayedCents + (target - _displayedCents) * 0.45;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    if (widget.isSilent) return Colors.grey.shade400;
    if (widget.isTuned) return const Color(0xFF10B981); // Verde afinado
    if (widget.cents.abs() <= widget.toleranceCents * 1.8) {
      return const Color(0xFFF97316); // Naranja leve desviación
    }
    return const Color(0xFFEF4444); // Rojo calado o alto
  }

  String _getStatusLabel() {
    if (widget.isSilent) return 'ESCUCHANDO...';
    if (widget.isTuned) return 'AFINADO';
    if (widget.cents < -widget.toleranceCents) return 'CALADO (GRAVE)';
    return 'ALTO (AGUDO)';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusLabel = _getStatusLabel();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicador de Nota y Frecuencia
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor, width: 2),
          ),
          child: Column(
            children: [
              Text(
                widget.isSilent ? '--' : widget.noteName,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isSilent
                    ? 'Toca una nota en tu instrumento'
                    : '${widget.frequencyHz.toStringAsFixed(1)} Hz (${widget.cents > 0 ? "+" : ""}${widget.cents.toStringAsFixed(1)} cents)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Dial de Aguja con CustomPainter
        SizedBox(
          width: 320,
          height: 180,
          child: CustomPaint(
            painter: _GaugePainter(
              cents: _displayedCents,
              statusColor: statusColor,
              toleranceCents: widget.toleranceCents,
              isSilent: widget.isSilent,
            ),
          ),
        ),

        const SizedBox(height: 16),
        // Estado Calado / Afinado / Alto
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: statusColor,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double cents;
  final Color statusColor;
  final double toleranceCents;
  final bool isSilent;

  const _GaugePainter({
    required this.cents,
    required this.statusColor,
    required this.toleranceCents,
    required this.isSilent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 15);
    final radius = size.width * 0.45;

    // Arco de fondo
    final arcPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      arcPaint,
    );

    // Zona de afinado (centro +- tolerancia)
    final tunedAngleSpan = (toleranceCents / 50.0) * (math.pi / 2);
    final tunedArcPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      1.5 * math.pi - tunedAngleSpan,
      tunedAngleSpan * 2,
      false,
      tunedArcPaint,
    );

    // Marcas de escala (-50, -25, 0, +25, +50)
    final tickPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 2.0;

    for (int c = -50; c <= 50; c += 10) {
      final angle = 1.5 * math.pi + (c / 50.0) * (math.pi / 2.5);
      final isMajor = c % 25 == 0;
      final tickLen = isMajor ? 12.0 : 6.0;

      final p1 = Offset(
        center.dx + (radius - tickLen) * math.cos(angle),
        center.dy + (radius - tickLen) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Aguja indicadora
    final needleAngle = 1.5 * math.pi + (cents / 50.0) * (math.pi / 2.5);
    final needleLen = radius * 0.95;

    final needlePaint = Paint()
      ..color = isSilent ? statusColor.withValues(alpha: 0.4) : statusColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final needleTip = Offset(
      center.dx + needleLen * math.cos(needleAngle),
      center.dy + needleLen * math.sin(needleAngle),
    );

    canvas.drawLine(center, needleTip, needlePaint);

    // Pivote central
    final pivotPaint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, pivotPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.cents != cents ||
        oldDelegate.statusColor != statusColor ||
        oldDelegate.isSilent != isSilent;
  }
}
