import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Badge de dificultad con colores distintivos.
class DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const DifficultyBadge({super.key, required this.difficulty});

  /// Color estático para uso externo (chips, filtros).
  static Color colorForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'principiante':
        return AppTheme.success;
      case 'intermedio':
        return AppTheme.warning;
      case 'avanzado':
        return AppTheme.error;
      case 'experto':
        return AppTheme.rarityEpic;
      default:
        return AppTheme.rarityCommon;
    }
  }

  Color _color(BuildContext context) {
    switch (difficulty) {
      case 'principiante':
        return AppTheme.success;
      case 'intermedio':
        return AppTheme.warning;
      case 'avanzado':
        return Theme.of(context).colorScheme.error;
      case 'experto':
        return AppTheme.rarityEpic;
      default:
        return AppTheme.rarityCommon;
    }
  }

  String get _label {
    switch (difficulty) {
      case 'principiante':
        return 'Principiante';
      case 'intermedio':
        return 'Intermedio';
      case 'avanzado':
        return 'Avanzado';
      case 'experto':
        return 'Experto';
      default:
        return difficulty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
