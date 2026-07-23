import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Widget de racha con ícono de fuego animado.
class StreakFlameWidget extends StatelessWidget {
  final int streakDays;
  final bool compact;

  const StreakFlameWidget({
    super.key,
    required this.streakDays,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = streakDays > 0;
    final color = isActive ? AppTheme.orange : Theme.of(context).dividerColor;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            '$streakDays',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [
                  AppTheme.orange.withValues(alpha: 0.15),
                  Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
                ],
              )
            : null,
        color: isActive ? null : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: AppTheme.orange.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: color, size: 28),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$streakDays días',
                style: TextStyle(
                  color: isActive ? AppTheme.orange : AppTheme.muted,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                isActive ? 'Racha activa' : 'Sin racha',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
