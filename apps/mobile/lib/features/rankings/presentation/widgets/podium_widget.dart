import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/leaderboard_model.dart';

/// Podio de 3 columnas animadas: plata (2º) · oro (1º) · bronce (3º).
///
/// Las columnas crecen desde cero cada vez que cambia el conjunto de
/// [entries] (p. ej. al conmutar de Quena a Zampoña). Con menos de tres
/// usuarios, los puestos vacíos se muestran como columnas atenuadas.
class PodiumWidget extends StatelessWidget {
  final List<LeaderboardEntryModel> entries;
  final Duration animationDuration;

  const PodiumWidget({
    super.key,
    required this.entries,
    this.animationDuration = const Duration(milliseconds: 600),
  });

  static const _heights = [150.0, 110.0, 80.0]; // oro, plata, bronce
  static const _medalColors = [AppTheme.gold, AppTheme.silver, AppTheme.bronze];

  LeaderboardEntryModel? _at(int index) =>
      index < entries.length ? entries[index] : null;

  @override
  Widget build(BuildContext context) {
    // Orden visual: plata, oro, bronce.
    const visualOrder = [1, 0, 2];
    final animationKey = ValueKey(
      entries.take(3).map((e) => '${e.userId}:${e.xp}').join('|'),
    );

    return TweenAnimationBuilder<double>(
      key: animationKey,
      tween: Tween(begin: 0, end: 1),
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return SizedBox(
          key: const Key('podium'),
          height: 260,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final index in visualOrder)
                Expanded(
                  child: _PodiumColumn(
                    key: Key('podium-column-${index + 1}'),
                    position: index,
                    entry: _at(index),
                    height: _heights[index] * progress,
                    color: _medalColors[index],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final int position;
  final LeaderboardEntryModel? entry;
  final double height;
  final Color color;

  const _PodiumColumn({
    super.key,
    required this.position,
    required this.entry,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = this.entry;
    final name = entry == null
        ? '—'
        : (entry.fullName.isNotEmpty ? entry.fullName : entry.username);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: position == 0 ? 28 : 22,
            backgroundColor: color.withValues(
              alpha: entry == null ? 0.15 : 0.3,
            ),
            backgroundImage: entry?.avatarUrl != null
                ? NetworkImage(entry!.avatarUrl!)
                : null,
            child: entry?.avatarUrl == null
                ? Text(
                    name.characters.first.toUpperCase(),
                    style: theme.textTheme.titleMedium,
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
          Text(
            entry == null ? '' : '${entry.xp} XP',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Container(
            key: Key('podium-bar-${position + 1}'),
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: entry == null ? 0.25 : 1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            child: height > 28
                ? Text(
                    '${position + 1}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
