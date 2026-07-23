import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Badge circular con posición (#1 dorado, #2 plata, #3 bronce).
class RankBadge extends StatelessWidget {
  final int rank;
  final double size;

  const RankBadge({super.key, required this.rank, this.size = 32});

  @override
  Widget build(BuildContext context) {
    if (rank <= 3) {
      final colors = [AppTheme.gold, AppTheme.silver, AppTheme.bronze];
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors[rank - 1].withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: colors[rank - 1].withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '#$rank',
            style: TextStyle(
              color: colors[rank - 1],
              fontWeight: FontWeight.bold,
              fontSize: size * 0.35,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          '#$rank',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}
