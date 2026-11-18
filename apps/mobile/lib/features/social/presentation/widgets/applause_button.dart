import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Botón de aplausos (reacción) con área táctil >= 48x48 px.
///
/// Respeta la Ley de Fitts de `apps/mobile/DESIGN.md` (regla ergonómica 1) y
/// anima el icono al cambiar de estado.
class ApplauseButton extends StatelessWidget {
  final bool isApplauded;
  final int count;
  final VoidCallback onPressed;

  const ApplauseButton({
    super.key,
    required this.isApplauded,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isApplauded ? cs.primary : Theme.of(context).hintColor;
    return Semantics(
      button: true,
      label: 'Aplaudir, $count aplausos',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isApplauded
                        ? Icons.celebration
                        : Icons.celebration_outlined,
                    key: ValueKey(isApplauded),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
