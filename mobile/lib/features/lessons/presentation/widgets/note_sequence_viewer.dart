import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/note_sequence_model.dart';

/// Widget scrollable horizontal que muestra la secuencia de notas y se
/// **auto-desplaza** para mantener la nota actual a la vista (antes había que
/// deslizar a mano y la posición se perdía).
class NoteSequenceViewer extends StatefulWidget {
  final List<NoteSequenceModel> notes;
  final int? currentPosition;
  final Set<int> completedPositions;

  const NoteSequenceViewer({
    super.key,
    required this.notes,
    this.currentPosition,
    this.completedPositions = const {},
  });

  @override
  State<NoteSequenceViewer> createState() => _NoteSequenceViewerState();
}

class _NoteSequenceViewerState extends State<NoteSequenceViewer> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToCurrent();
  }

  @override
  void didUpdateWidget(NoteSequenceViewer old) {
    super.didUpdateWidget(old);
    if (widget.currentPosition != old.currentPosition) {
      _scrollToCurrent();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ancho que ocupa una tarjeta (mismo cálculo que el build) + margen 2+2.
  double _cardWidth(NoteSequenceModel n) =>
      (n.duration * 50).clamp(30.0, 120.0) + 4;

  /// Desplaza para centrar la tarjeta de la nota actual. Suma los anchos REALES
  /// (las notas de acorde que no son la primera del grupo se dibujan con ancho
  /// cero), así el cálculo es exacto pese a los anchos variables.
  void _scrollToCurrent() {
    final pos = widget.currentPosition;
    final notes = widget.notes;
    if (pos == null || pos < 0 || pos >= notes.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;

      final grouped = _groupChords(notes);
      // Tarjeta a mostrar: la primera nota del acorde, o la nota misma.
      var cardIdx = pos;
      final cur = notes[pos];
      if (cur.isChord && cur.chordGroup != null) {
        cardIdx = notes.indexOf(grouped[cur.chordGroup!]!.first);
      }

      var before = 0.0;
      var cardW = 0.0;
      for (var i = 0; i <= cardIdx && i < notes.length; i++) {
        final n = notes[i];
        if (n.isChord && n.chordGroup != null) {
          // Continuación de acorde: ancho cero (no es una tarjeta propia).
          if (grouped[n.chordGroup!]!.indexOf(n) > 0) continue;
        }
        if (i == cardIdx) {
          cardW = _cardWidth(n);
        } else {
          before += _cardWidth(n);
        }
      }

      final p = _controller.position;
      final target = (before - p.viewportDimension / 2 + cardW / 2)
          .clamp(0.0, p.maxScrollExtent);
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  Map<int, List<NoteSequenceModel>> _groupChords(
    List<NoteSequenceModel> notes,
  ) {
    final grouped = <int, List<NoteSequenceModel>>{};
    for (final n in notes) {
      if (n.isChord && n.chordGroup != null) {
        grouped.putIfAbsent(n.chordGroup!, () => []).add(n);
      }
    }
    return grouped;
  }

  /// Color basado en la altura de la nota.
  Color _noteColor(String note) {
    if (note == 'REST') return AppTheme.mutedDark;
    final octave = int.tryParse(note.replaceAll(RegExp(r'[^0-8]'), '')) ?? 4;
    const baseColors = [
      AppTheme.rarityEpic, // grave
      AppTheme.info,
      AppTheme.cyan, // cyan — matches primary
      AppTheme.success,
      AppTheme.warning,
      AppTheme.error, // agudo
    ];
    final idx = (octave - 2).clamp(0, baseColors.length - 1);
    return baseColors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.notes;
    final grouped = _groupChords(notes);

    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];

          // Saltar notas de acorde que no son la primera del grupo
          if (note.isChord && note.chordGroup != null) {
            final group = grouped[note.chordGroup!]!;
            if (group.indexOf(note) > 0) return const SizedBox.shrink();
          }

          final isCurrent = widget.currentPosition != null &&
              note.position - 1 == widget.currentPosition;
          final isCompleted =
              widget.completedPositions.contains(note.position - 1);

          // Ancho proporcional a la duración
          final width = (note.duration * 50).clamp(30.0, 120.0);

          if (note.isRest) {
            return _buildRestBlock(context, width, isCurrent);
          }

          if (note.isChord && note.chordGroup != null) {
            final group = grouped[note.chordGroup!]!;
            return _buildChordBlock(
              context,
              group,
              width,
              isCurrent,
              isCompleted,
            );
          }

          return _buildNoteBlock(context, note, width, isCurrent, isCompleted);
        },
      ),
    );
  }

  Widget _buildNoteBlock(
    BuildContext context,
    NoteSequenceModel note,
    double width,
    bool isCurrent,
    bool isCompleted,
  ) {
    final color = _noteColor(note.note);
    final borderColor = isCurrent
        ? Theme.of(context).colorScheme.primary
        : isCompleted
        ? AppTheme.success
        : Colors.transparent;

    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isCompleted
            ? color.withValues(alpha: 0.3)
            : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            note.note,
            style: TextStyle(
              color: isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          if (note.finger != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${note.finger}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ),
          if (note.hand != null)
            Text(
              note.hand == 'left'
                  ? 'L'
                  : note.hand == 'right'
                  ? 'R'
                  : 'B',
              style: const TextStyle(color: AppTheme.muted, fontSize: 9),
            ),
        ],
      ),
    );
  }

  Widget _buildChordBlock(
    BuildContext context,
    List<NoteSequenceModel> group,
    double width,
    bool isCurrent,
    bool isCompleted,
  ) {
    final borderColor = isCurrent
        ? Theme.of(context).colorScheme.primary
        : isCompleted
        ? AppTheme.success
        : Colors.transparent;

    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: group.reversed.map((n) {
          return Text(
            n.note,
            style: TextStyle(
              color: isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRestBlock(BuildContext context, double width, bool isCurrent) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          style: BorderStyle.solid,
        ),
      ),
      child: const Center(
        child: Icon(Icons.pause, color: AppTheme.mutedDark, size: 16),
      ),
    );
  }
}
