import 'package:flutter/material.dart';

import '../../data/models/progress_stats_model.dart';

/// Gráfico de barras simple para progreso semanal.
class WeeklyChart extends StatelessWidget {
  final List<WeeklyDataPoint> data;

  const WeeklyChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Sin datos esta semana',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final maxSessions = data
        .map((d) => d.sessionsCount)
        .reduce((a, b) => a > b ? a : b);
    final maxValue = maxSessions > 0 ? maxSessions.toDouble() : 1.0;

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((point) {
          final barHeight = maxValue > 0
              ? (point.sessionsCount / maxValue) * 120.0
              : 0.0;
          // Obtener día de la semana
          final date = DateTime.tryParse(point.date);
          final dayLabel = date != null
              ? ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sa', 'Do'][date.weekday - 1]
              : '';

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Score promedio
                  if (point.sessionsCount > 0)
                    Text(
                      '${point.averageScore.toInt()}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Barra
                  Container(
                    height: barHeight.clamp(4.0, 120.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          Theme.of(context).colorScheme.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Día
                  Text(
                    dayLabel,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
