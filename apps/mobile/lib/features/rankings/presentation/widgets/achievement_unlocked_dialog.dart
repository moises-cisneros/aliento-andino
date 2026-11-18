import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/achievement_model.dart';

/// Dialog con animación al desbloquear un logro.
class AchievementUnlockedDialog extends StatelessWidget {
  final AchievementModel achievement;

  const AchievementUnlockedDialog({super.key, required this.achievement});

  /// Mostrar el dialog para un logro desbloqueado.
  static Future<void> show(BuildContext context, AchievementModel achievement) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AchievementUnlockedDialog(achievement: achievement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityColor(achievement.rarity);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: rarityColor.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.2),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Text(
              '🎉 ¡Logro Desbloqueado!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Ícono grande
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: rarityColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: rarityColor.withValues(alpha: 0.5),
                  width: 3,
                ),
              ),
              child: Icon(
                _getIcon(achievement.icon),
                size: 40,
                color: rarityColor,
              ),
            ),
            const SizedBox(height: 16),
            // Nombre
            Text(
              achievement.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Descripción
            Text(
              achievement.description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // XP reward
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+${achievement.xpReward} XP',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Rareza
            Text(
              _rarityLabel(achievement.rarity),
              style: TextStyle(
                color: rarityColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            // Botón
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: rarityColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  '¡Genial!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
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

  String _rarityLabel(String rarity) {
    switch (rarity) {
      case 'rare':
        return '⭐ Raro';
      case 'epic':
        return '💎 Épico';
      case 'legendary':
        return '👑 Legendario';
      default:
        return 'Común';
    }
  }

  IconData _getIcon(String iconName) {
    const iconMap = {
      'music_note': Icons.music_note,
      'school': Icons.school,
      'piano': Icons.music_note,
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
