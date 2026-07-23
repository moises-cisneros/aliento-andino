import 'package:flutter/material.dart';

/// Badge visual del nivel auto-declarado del usuario.
class SkillLevelBadge extends StatelessWidget {
  final String? level; // 'beginner' | 'intermediate' | 'advanced'
  final bool compact;

  const SkillLevelBadge({super.key, this.level, this.compact = false});

  static ({IconData icon, Color color, String label}) propsFor(String? level) {
    switch (level) {
      case 'advanced':
        return (
          icon: Icons.workspace_premium,
          color: const Color(0xFFF59E0B),
          label: 'Avanzado',
        );
      case 'intermediate':
        return (
          icon: Icons.trending_up,
          color: const Color(0xFF8B5CF6),
          label: 'Intermedio',
        );
      case 'beginner':
        return (
          icon: Icons.spa,
          color: const Color(0xFF10B981),
          label: 'Principiante',
        );
      default:
        return (
          icon: Icons.help_outline,
          color: Colors.grey,
          label: 'Sin nivel',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = propsFor(level);
    final padH = compact ? 8.0 : 10.0;
    final padV = compact ? 4.0 : 6.0;
    final iconSize = compact ? 12.0 : 14.0;
    final fontSize = compact ? 11.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: p.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(p.icon, size: iconSize, color: p.color),
          const SizedBox(width: 4),
          Text(
            p.label,
            style: TextStyle(
              color: p.color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
