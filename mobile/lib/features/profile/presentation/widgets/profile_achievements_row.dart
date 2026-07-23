import 'package:flutter/material.dart';

import '../../../rankings/data/models/achievement_model.dart';

/// Fila horizontal de logros recientes.
class ProfileAchievementsRow extends StatelessWidget {
  final List<AchievementModel> achievements;
  final VoidCallback onViewAll;

  const ProfileAchievementsRow({
    super.key,
    required this.achievements,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Logros recientes',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: Text(
                  'Ver todos →',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: achievements.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final a = achievements[index];
                return _AchievementMiniCard(achievement: a);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementMiniCard extends StatelessWidget {
  final AchievementModel achievement;

  const _AchievementMiniCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: achievement.isUnlocked
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconFromName(achievement.icon),
            size: 28,
            color: achievement.isUnlocked
                ? Theme.of(context).colorScheme.primary
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFromName(String name) {
    const map = <String, IconData>{
      'music_note': Icons.music_note,
      'school': Icons.school,
      'piano': Icons.piano,
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
    return map[name] ?? Icons.emoji_events;
  }
}
