import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/achievement_model.dart';

/// Insignia de la vitrina: estado bloqueado/desbloqueado y fecha de obtención.
class BadgeItemWidget extends StatelessWidget {
  final AchievementModel achievement;

  const BadgeItemWidget({super.key, required this.achievement});

  static String formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = achievement.isUnlocked;
    final date = achievement.unlockedAt;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked
            ? scheme.surface
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? AppTheme.gold.withValues(alpha: 0.6)
              : scheme.surfaceContainerHighest,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Opacity(
                opacity: unlocked ? 1 : 0.4,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Image.asset(
                    achievement.iconAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _AndeanMedalFallback(),
                  ),
                ),
              ),
              if (!unlocked)
                Icon(
                  Icons.lock,
                  key: const Key('badge_locked_icon'),
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked ? scheme.onSurface : scheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unlocked && date != null
                ? 'Obtenida el ${formatDate(date)}'
                : (unlocked ? 'Obtenida' : 'Bloqueada'),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Ilustración genérica de medalla andina cuando el icono no existe.
class _AndeanMedalFallback extends StatelessWidget {
  const _AndeanMedalFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('badge_fallback_medal'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.gold.withValues(alpha: 0.15),
        border: Border.all(color: AppTheme.gold, width: 2),
      ),
      child: const Icon(Icons.military_tech, size: 32, color: AppTheme.gold),
    );
  }
}
