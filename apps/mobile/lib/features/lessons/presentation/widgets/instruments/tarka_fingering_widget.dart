import 'package:flutter/material.dart';

import '../../../../../core/audio/fingering_models.dart';
import '../../../../../core/theme/app_theme.dart';

/// Tarka diagram: a wooden body with 6 rectangular front holes.
/// Covered holes are filled cyan, open holes are transparent with a muted
/// border.
class TarkaFingeringWidget extends StatelessWidget {
  /// Note to display (e.g. `C5`). Ignored when [fingering] is given.
  final String? note;
  final TarkaFingering? fingering;

  const TarkaFingeringWidget({super.key, this.note, this.fingering});

  static const double holeSize = 48;

  @override
  Widget build(BuildContext context) {
    final resolved =
        fingering ?? (note == null ? null : TarkaFingering.forNote(note!));
    if (resolved == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Note not available in the tarka scale',
          key: Key('tarka-out-of-range'),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5E3C), // wood tone
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < TarkaFingering.holeCount; i++) ...[
            _Hole(
              key: Key('tarka-hole-${i + 1}'),
              covered: resolved.holesCovered[i],
            ),
            if (i < TarkaFingering.holeCount - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Hole extends StatelessWidget {
  final bool covered;

  const _Hole({super.key, required this.covered});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: covered ? 'Hole covered' : 'Hole open',
      child: Container(
        width: TarkaFingeringWidget.holeSize,
        height: TarkaFingeringWidget.holeSize,
        decoration: BoxDecoration(
          color: covered ? AppTheme.cyan : Colors.transparent,
          border: Border.all(
            color: covered ? AppTheme.cyan : AppTheme.muted,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
