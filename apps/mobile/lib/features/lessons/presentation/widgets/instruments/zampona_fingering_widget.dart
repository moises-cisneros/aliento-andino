import 'package:flutter/material.dart';

import '../../../../../core/audio/fingering_models.dart';
import '../../../../../core/theme/app_theme.dart';

/// Zampoña diagram: two horizontal rows, Arca (7 tubes) and Ira (6 tubes).
/// The tube to blow is highlighted in cyan.
class ZamponaFingeringWidget extends StatelessWidget {
  /// Note to display (e.g. `G4`). Ignored when [fingering] is given.
  final String? note;
  final ZamponaFingering? fingering;

  const ZamponaFingeringWidget({super.key, this.note, this.fingering});

  static const double tubeWidth = 48;

  @override
  Widget build(BuildContext context) {
    final resolved =
        fingering ?? (note == null ? null : ZamponaFingering.forNote(note!));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TubeRow(row: 'arca', active: resolved),
              const SizedBox(height: 8),
              _TubeRow(row: 'ira', active: resolved),
            ],
          ),
        ),
        if (resolved == null && note != null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Note not available on this zampoña',
              key: Key('zampona-out-of-range'),
            ),
          ),
      ],
    );
  }
}

class _TubeRow extends StatelessWidget {
  final String row;
  final ZamponaFingering? active;

  const _TubeRow({required this.row, required this.active});

  @override
  Widget build(BuildContext context) {
    final count = ZamponaFingering.tubeCounts[row]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Tube(
              key: Key('zampona-$row-$i'),
              // Graves más largos (i=1), agudos más cortos (i=count).
              height: 64.0 + (count - i) * 8.0,
              highlighted:
                  active != null &&
                  active!.activeRow == row &&
                  active!.tubeIndex == i,
            ),
          ),
      ],
    );
  }
}

class _Tube extends StatelessWidget {
  final double height;
  final bool highlighted;

  const _Tube({super.key, required this.height, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: highlighted ? 'Active tube' : 'Tube',
      child: Container(
        width: ZamponaFingeringWidget.tubeWidth,
        height: height,
        decoration: BoxDecoration(
          color: highlighted ? AppTheme.cyan : Colors.transparent,
          border: Border.all(
            color: highlighted ? AppTheme.cyan : AppTheme.muted,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
