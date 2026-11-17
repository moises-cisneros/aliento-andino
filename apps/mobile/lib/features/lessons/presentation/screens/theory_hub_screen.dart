import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hub de "Teoría y entrenamiento": agrupa los mini-juegos de práctica que no
/// dependen de una lección concreta (oído, lectura en pentagrama, teoría).
class TheoryHubScreen extends StatelessWidget {
  const TheoryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Teoría y entrenamiento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Practicá fundamentos sin necesidad de una lección.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _ModuleCard(
            icon: Icons.hearing,
            color: cs.secondary,
            title: 'Entrenamiento de oído',
            subtitle: 'Reconocé intervalos de oído',
            onTap: () => context.push('/ear-training'),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            icon: Icons.queue_music,
            color: cs.primary,
            title: 'Lectura en pentagrama',
            subtitle: 'Identificá notas en la partitura',
            onTap: () => context.push('/theory/sight-reading'),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            icon: Icons.school,
            color: cs.tertiary,
            title: 'Quiz de teoría',
            subtitle: 'Intervalos, figuras, armaduras y más',
            onTap: () => context.push('/theory/quiz'),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.surfaceContainerHighest),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
