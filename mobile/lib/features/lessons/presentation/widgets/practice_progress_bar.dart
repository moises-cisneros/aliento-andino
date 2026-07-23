import 'package:flutter/material.dart';

/// Barra de progreso durante la práctica.
class PracticeProgressBar extends StatelessWidget {
  final int currentPosition;
  final int totalNotes;

  const PracticeProgressBar({
    super.key,
    required this.currentPosition,
    required this.totalNotes,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalNotes > 0 ? currentPosition / totalNotes : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nota ${currentPosition + 1} de $totalNotes',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
