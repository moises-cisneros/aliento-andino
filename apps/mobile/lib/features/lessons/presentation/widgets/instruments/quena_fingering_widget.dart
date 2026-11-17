import 'package:flutter/material.dart';

import '../../../../../core/audio/fingering_models.dart';
import '../../../../../core/theme/app_theme.dart';

/// Quena fingering diagram: 6 front holes plus the rear thumb hole.
///
/// Covered holes are filled cyan, open holes are transparent with a muted
/// border, half covered holes are filled on one half. Each hole has a touch
/// target of at least 48 logical pixels.
class QuenaFingeringWidget extends StatelessWidget {
  /// Note to display (e.g. `G4`, `Sol4`). Ignored when [fingering] is given.
  final String? note;

  /// Explicit fingering; takes precedence over [note].
  final QuenaFingering? fingering;

  const QuenaFingeringWidget({super.key, this.note, this.fingering});

  static const double holeSize = 48;

  @override
  Widget build(BuildContext context) {
    final resolved =
        fingering ?? (note == null ? null : QuenaFingering.forNote(note!));
    if (resolved == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Note not available in standard quena fingering',
          key: Key('quena-out-of-range'),
          textAlign: TextAlign.center,
        ),
      );
    }
    final states = resolved.states;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Hole(key: const Key('quena-hole-thumb'), state: states[0], label: 'T'),
        const SizedBox(height: 8),
        for (var i = 1; i <= 6; i++) ...[
          _Hole(key: Key('quena-hole-$i'), state: states[i], label: '$i'),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Hole extends StatelessWidget {
  final HoleState state;
  final String label;

  const _Hole({super.key, required this.state, required this.label});

  @override
  Widget build(BuildContext context) {
    final covered = state == HoleState.covered;
    return Semantics(
      label: 'Hole $label ${state.name}',
      child: SizedBox(
        width: QuenaFingeringWidget.holeSize,
        height: QuenaFingeringWidget.holeSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: covered ? AppTheme.cyan : Colors.transparent,
            border: Border.all(
              color: covered ? AppTheme.cyan : AppTheme.muted,
              width: 2,
            ),
            gradient: state == HoleState.half
                ? const LinearGradient(
                    colors: [AppTheme.cyan, Colors.transparent],
                    stops: [0.5, 0.5],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
          ),
          child: Center(child: Text(label)),
        ),
      ),
    );
  }
}
