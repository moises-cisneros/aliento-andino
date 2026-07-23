import 'package:flutter/material.dart';
import '../../data/models/post_model.dart';

/// Card de resultado de práctica embebida en un post.
class PracticeResultCard extends StatelessWidget {
  final PracticeSessionSummary session;

  const PracticeResultCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final accuracy = session.totalNotes > 0
        ? ((session.correctNotes / session.totalNotes) * 100).toInt()
        : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.piano,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  session.lessonTitle ?? 'Práctica libre',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat(context, 'Score', '${session.score.toInt()}%'),
              _stat(context, 'Precisión', '$accuracy%'),
              _stat(
                context,
                'Notas',
                '${session.correctNotes}/${session.totalNotes}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11),
        ),
      ],
    );
  }
}
