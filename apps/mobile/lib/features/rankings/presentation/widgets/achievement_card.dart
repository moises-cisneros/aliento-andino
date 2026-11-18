import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/achievement_model.dart';

/// Card de logro con estado bloqueado/desbloqueado.
class AchievementCard extends StatelessWidget {
  final AchievementModel achievement;

  const AchievementCard({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    final rarityColor = _rarityColor(achievement.rarity);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked
            ? Theme.of(context).colorScheme.surface
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? rarityColor.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: rarityColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono
          Icon(
            _getIcon(achievement.icon),
            size: 32,
            color: isUnlocked ? rarityColor : Theme.of(context).dividerColor,
          ),
          const SizedBox(height: 8),
          // Nombre
          Text(
            achievement.name,
            style: TextStyle(
              color: isUnlocked
                  ? Theme.of(context).colorScheme.onSurface
                  : AppTheme.muted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Descripción o progreso
          if (isUnlocked)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: rarityColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Desbloqueado',
                  style: TextStyle(color: rarityColor, fontSize: 11),
                ),
              ],
            )
          else ...[
            // Barra de progreso
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: achievement.requirementValue > 0
                    ? (achievement.progress / achievement.requirementValue)
                          .clamp(0.0, 1.0)
                    : 0,
                minHeight: 4,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).dividerColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${achievement.progress}/${achievement.requirementValue}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 4),
          // Badge de rareza + XP
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: rarityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '+${achievement.xpReward} XP',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'rare':
        return AppTheme.rarityRare;
      case 'epic':
        return AppTheme.rarityEpic;
      case 'legendary':
        return AppTheme.rarityLegendary;
      default:
        return AppTheme.rarityCommon;
    }
  }

  IconData _getIcon(String iconName) {
    const iconMap = {
      'music_note': Icons.music_note,
      'school': Icons.school,
      'quena': Icons.music_note,
      'zampona': Icons.graphic_eq,
      'tarka': Icons.audiotrack,
      'emoji_events': Icons.emoji_events,
      'stars': Icons.stars,
      'local_fire_department': Icons.local_fire_department,
      'whatshot': Icons.whatshot,
      'military_tech': Icons.military_tech,
      'diamond': Icons.diamond,
      'star': Icons.star,
      'auto_awesome': Icons.auto_awesome,
      'trending_up': Icons.trending_up,
      'feed': Icons.feed,
      'groups': Icons.groups,
      'celebration': Icons.celebration,
      'upgrade': Icons.upgrade,
      'rocket_launch': Icons.rocket_launch,
      'workspace_premium': Icons.workspace_premium,
      'timer': Icons.timer,
      'hourglass_top': Icons.hourglass_top,
    };
    return iconMap[iconName] ?? Icons.emoji_events;
  }
}
