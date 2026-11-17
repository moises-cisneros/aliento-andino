import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/lesson_model.dart';
import 'difficulty_badge.dart';
import 'offline_badge_widget.dart';

/// Card de lección para la lista principal.
class LessonCard extends StatelessWidget {
  final LessonModel lesson;
  final VoidCallback onTap;

  /// Bloqueada por la ruta de aprendizaje (no se dominó la anterior).
  final bool locked;

  /// Bloqueada por ser contenido premium (usuario sin suscripción).
  final bool premiumLocked;

  /// La lección está descargada y se puede practicar sin conexión.
  final bool isDownloaded;

  const LessonCard({
    super.key,
    required this.lesson,
    required this.onTap,
    this.locked = false,
    this.premiumLocked = false,
    this.isDownloaded = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: (locked || premiumLocked) ? 0.55 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          child: Row(
            children: [
              // Ícono / thumbnail
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.music_note, color: accent, size: 28),
                    if (premiumLocked)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(
                          Icons.workspace_premium,
                          color: AppTheme.warning,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            lesson.title,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDownloaded) ...[
                          const SizedBox(width: 6),
                          const OfflineBadgeWidget(isDownloaded: true),
                        ],
                      ],
                    ),
                    // Autor · género (si están), ej. "Beethoven · Clásica".
                    if (lesson.artist != null || lesson.genre != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          lesson.artist,
                          lesson.genre,
                        ].whereType<String>().join(' · '),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        DifficultyBadge(difficulty: lesson.difficulty),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.speed,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${lesson.tempoBpm} BPM',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Estado: corona (premium), candado (ruta), score, o flecha
              if (premiumLocked)
                Icon(Icons.workspace_premium, color: AppTheme.warning)
              else if (locked)
                Icon(
                  Icons.lock_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              else if (lesson.userBestScore != null) ...[
                Column(
                  children: [
                    Text(
                      '${lesson.userBestScore!.toInt()}%',
                      style: TextStyle(
                        color: _scoreColor(lesson.userBestScore!),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'mejor',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ] else
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _scoreColor(double score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 50) return AppTheme.warning;
    return AppTheme.error;
  }
}
