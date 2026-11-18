import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/ranking_entry_model.dart';

/// Podio animado de 3 columnas para los 3 mejores intérpretes.
///
/// Colores oficiales de medallas:
/// - Oro: #FFD700 (1° lugar - columna central, más alta)
/// - Plata: #C0C0C0 (2° lugar - columna izquierda)
/// - Bronce: #CD7F32 (3° lugar - columna derecha)
class PodiumWidget extends StatelessWidget {
  final List<RankingEntryModel> entries;

  const PodiumWidget({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        alignment: Alignment.center,
        child: Text(
          'Sin intérpretes en el podio aún esta semana',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      );
    }

    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2do lugar: Plata (#C0C0C0)
          Expanded(
            child: _PodiumStep(
              rank: 2,
              entry: second,
              color: AppTheme.silver,
              pedestalHeight: 100,
              medalLabel: '2°',
            ),
          ),
          const SizedBox(width: 8),
          // 1er lugar: Oro (#FFD700) - más alto
          Expanded(
            child: _PodiumStep(
              rank: 1,
              entry: first,
              color: AppTheme.gold,
              pedestalHeight: 135,
              medalLabel: '1°',
              isWinner: true,
            ),
          ),
          const SizedBox(width: 8),
          // 3er lugar: Bronce (#CD7F32)
          Expanded(
            child: _PodiumStep(
              rank: 3,
              entry: third,
              color: AppTheme.bronze,
              pedestalHeight: 75,
              medalLabel: '3°',
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumStep extends StatelessWidget {
  final int rank;
  final RankingEntryModel? entry;
  final Color color;
  final double pedestalHeight;
  final String medalLabel;
  final bool isWinner;

  const _PodiumStep({
    required this.rank,
    required this.entry,
    required this.color,
    required this.pedestalHeight,
    required this.medalLabel,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEntry = entry != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Corona para el 1er puesto
        if (isWinner)
          Icon(Icons.workspace_premium, color: color, size: 28)
        else
          const SizedBox(height: 28),
        const SizedBox(height: 4),

        // Avatar con anillo de medalla
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasEntry ? color : theme.colorScheme.outlineVariant,
                  width: isWinner ? 3 : 2,
                ),
                boxShadow: hasEntry && isWinner
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: isWinner ? 28 : 22,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: hasEntry && entry!.avatarUrl != null
                    ? NetworkImage(entry!.avatarUrl!)
                    : null,
                child: hasEntry
                    ? (entry!.avatarUrl == null
                          ? Text(
                              entry!.username.isNotEmpty
                                  ? entry!.username[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: isWinner ? 18 : 14,
                              ),
                            )
                          : null)
                    : Icon(
                        Icons.person_outline,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        size: 20,
                      ),
              ),
            ),
            // Badge medalla #1, #2, #3
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  medalLabel,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Nombre del usuario
        SizedBox(
          height: 18,
          child: Text(
            hasEntry
                ? (entry!.fullName.isNotEmpty
                      ? entry!.fullName
                      : entry!.username)
                : '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
              color: hasEntry
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 2),

        // XP
        SizedBox(
          height: 16,
          child: Text(
            hasEntry ? '${entry!.xp} XP' : '0 XP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: hasEntry
                  ? color
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Pedestal animado con gradiente
        TweenAnimationBuilder<double>(
          key: ValueKey('podium_col_${rank}_${entry?.userId ?? "empty"}'),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, animValue, child) {
            return Container(
              height: pedestalHeight * animValue,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: isWinner ? 0.35 : 0.22),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: color.withValues(alpha: isWinner ? 0.8 : 0.4),
                  width: isWinner ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: isWinner ? 26 : 20,
                    fontWeight: FontWeight.w900,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
