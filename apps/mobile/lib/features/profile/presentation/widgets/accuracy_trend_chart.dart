import 'package:flutter/material.dart';

import '../../../lessons/data/models/practice_session_model.dart';

/// Promedio de acierto (0-100) de las prácticas de una semana.
class WeeklyAccuracy {
  /// Lunes (00:00) de la semana.
  final DateTime weekStart;
  final double average;
  final int sessions;

  const WeeklyAccuracy({
    required this.weekStart,
    required this.average,
    required this.sessions,
  });
}

/// Agrupa las sesiones por semana (lunes a domingo) y promedia su score.
///
/// Devuelve los puntos en orden cronológico. Las sesiones sin fecha válida se
/// ignoran: no se inventa una fecha para poder graficarlas.
List<WeeklyAccuracy> buildWeeklyAccuracy(List<PracticeSessionModel> sessions) {
  final byWeek = <DateTime, List<double>>{};
  for (final s in sessions) {
    final date = DateTime.tryParse(s.createdAt ?? '')?.toLocal();
    if (date == null) continue;
    final day = DateTime(date.year, date.month, date.day);
    final weekStart = day.subtract(Duration(days: day.weekday - 1));
    byWeek.putIfAbsent(weekStart, () => []).add(s.score);
  }
  final weeks = byWeek.keys.toList()..sort();
  return [
    for (final w in weeks)
      WeeklyAccuracy(
        weekStart: w,
        average: byWeek[w]!.reduce((a, b) => a + b) / byWeek[w]!.length,
        sessions: byWeek[w]!.length,
      ),
  ];
}

/// Gráfica de tendencia del porcentaje de acierto a lo largo de las semanas.
class AccuracyTrendChart extends StatelessWidget {
  final List<PracticeSessionModel> sessions;
  final double height;

  const AccuracyTrendChart({
    super.key,
    required this.sessions,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    final points = buildWeeklyAccuracy(sessions);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: points.isEmpty
          ? 'Gráfica de acierto semanal sin datos'
          : 'Gráfica de acierto semanal, ${points.length} semanas, último '
                'promedio ${points.last.average.round()} por ciento',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evolución de tu acierto',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Promedio semanal (%)',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (points.length < 2)
              SizedBox(
                height: height,
                child: Center(
                  child: Text(
                    points.isEmpty
                        ? 'Sin datos todavía'
                        : 'Practica otra semana para ver tu curva de '
                              'aprendizaje.',
                    key: const Key('accuracy_chart_placeholder'),
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: height,
                width: double.infinity,
                child: CustomPaint(
                  key: const Key('accuracy_chart_canvas'),
                  painter: _TrendPainter(
                    points: points,
                    lineColor: scheme.primary,
                    gridColor: scheme.outlineVariant,
                    labelStyle:
                        textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ) ??
                        const TextStyle(fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<WeeklyAccuracy> points;
  final Color lineColor;
  final Color gridColor;
  final TextStyle labelStyle;

  _TrendPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelStyle,
  });

  static const _leftPad = 30.0;
  static const _bottomPad = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _leftPad;
    final chartH = size.height - _bottomPad;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final v in const [0, 50, 100]) {
      final y = chartH - (v / 100) * chartH;
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width, y), grid);
      _text(canvas, '$v', Offset(0, y - 6));
    }

    final dx = chartW / (points.length - 1);
    final offsets = [
      for (var i = 0; i < points.length; i++)
        Offset(
          _leftPad + dx * i,
          chartH - (points[i].average.clamp(0, 100) / 100) * chartH,
        ),
    ];

    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = lineColor;
    for (final o in offsets) {
      canvas.drawCircle(o, 3.5, dot);
    }

    _text(canvas, _label(points.first.weekStart), Offset(_leftPad, chartH + 4));
    _text(
      canvas,
      _label(points.last.weekStart),
      Offset(size.width - 28, chartH + 4),
    );
  }

  String _label(DateTime d) => '${d.day}/${d.month}';

  void _text(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.lineColor != lineColor;
}
