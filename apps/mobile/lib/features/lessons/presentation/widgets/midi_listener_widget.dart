import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/note_sequence_model.dart';
import '../../data/services/midi_input_service.dart';
import '../bloc/practice/practice_bloc.dart';
import '../bloc/practice/practice_event.dart';
import '../bloc/practice/practice_state.dart';

/// Escucha la entrada MIDI (vía [MidiInputService]) y la evalúa contra la nota
/// esperada del PracticeBloc, igual que el micrófono pero con **precisión
/// exacta** (recibe la tecla digital, no infiere del sonido).
///
/// - **Nota simple:** compara la tecla MIDI (con tolerancia de octava) →
///   `PracticeNoteCorrect` / `PracticeNoteWrong` (cooldown 1s).
/// - **Acorde:** acumula las teclas pulsadas en una ventana corta y compara los
///   pitch classes contra el `chord_group`; al alcanzar las notas requeridas
///   emite Correct por cada posición del grupo.
///
/// Igual que [NoteListenerWidget], es un widget "invisible": solo lifecycle +
/// dispatch al bloc. La regla de "se queda en la misma nota si está mal" la
/// aplica el bloc (PracticeRetry).
class MidiListenerWidget extends StatefulWidget {
  final MidiInputService service;

  const MidiListenerWidget({super.key, required this.service});

  @override
  State<MidiListenerWidget> createState() => _MidiListenerWidgetState();
}

class _MidiListenerWidgetState extends State<MidiListenerWidget> {
  StreamSubscription<MidiNoteEvent>? _sub;
  DateTime _lastWrong = DateTime.fromMillisecondsSinceEpoch(0);
  static const _wrongCooldown = Duration(seconds: 1);

  // Buffer de pitch-classes recientes para detectar acordes (teclas casi
  // simultáneas llegan como note-on separados).
  final List<_TimedPc> _recent = [];
  static const _chordWindow = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    _sub = widget.service.noteOnStream.listen(_onNote);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onNote(MidiNoteEvent e) {
    if (!mounted) return;
    final state = context.read<PracticeBloc>().state;
    if (state is! PracticePlaying) return;
    if (state.currentPosition >= state.notes.length) return;

    final current = state.notes[state.currentPosition];
    if (current.isChord) {
      _onChordNote(e, state);
    } else {
      _onSingleNote(e, state);
    }
  }

  void _onSingleNote(MidiNoteEvent e, PracticePlaying state) {
    final expected = state.currentExpectedNote;
    if (expected.toUpperCase() == 'REST') return;
    final expMidi = noteNameToMidi(expected);
    if (expMidi == null) return;

    final ok =
        e.midi == expMidi ||
        (!state.octaveStrict && e.midi % 12 == expMidi % 12);
    if (ok) {
      context.read<PracticeBloc>().add(
        PracticeNoteCorrect(state.currentPosition),
      );
    } else {
      final now = DateTime.now();
      if (now.difference(_lastWrong) < _wrongCooldown) return;
      _lastWrong = now;
      context.read<PracticeBloc>().add(
        PracticeNoteWrong(
          position: state.currentPosition,
          expected: expected,
          played: e.note,
        ),
      );
    }
  }

  void _onChordNote(MidiNoteEvent e, PracticePlaying state) {
    final now = DateTime.now();
    _recent.add(_TimedPc(e.midi % 12, now));
    _recent.removeWhere((t) => now.difference(t.at) > _chordWindow);

    final group = _gatherChordGroup(state.notes, state.currentPosition);
    if (group.isEmpty) return;

    final expectedPCs = <int>{};
    for (final n in group) {
      final m = noteNameToMidi(n.note);
      if (m != null) expectedPCs.add(m % 12);
    }
    if (expectedPCs.isEmpty) return;

    final detectedPCs = _recent.map((t) => t.pc).toSet();
    final intersection = expectedPCs.intersection(detectedPCs);
    // Tolerancia: al menos la mitad (redondeo arriba) de las notas del acorde.
    final required = ((expectedPCs.length + 1) / 2).ceil();

    if (intersection.length >= required) {
      final bloc = context.read<PracticeBloc>();
      for (var i = 0; i < group.length; i++) {
        bloc.add(PracticeNoteCorrect(state.currentPosition + i));
      }
      _recent.clear();
    } else if (!expectedPCs.contains(e.midi % 12)) {
      // Tecla claramente fuera del acorde → error (con cooldown).
      if (now.difference(_lastWrong) < _wrongCooldown) return;
      _lastWrong = now;
      context.read<PracticeBloc>().add(
        PracticeNoteWrong(
          position: state.currentPosition,
          expected: group.map((n) => n.note).join('+'),
          played: e.note,
        ),
      );
    }
  }

  /// Junta todas las notas consecutivas con el mismo chord_group desde idx.
  List<NoteSequenceModel> _gatherChordGroup(
    List<NoteSequenceModel> notes,
    int startIdx,
  ) {
    if (startIdx >= notes.length) return const [];
    final group = notes[startIdx].chordGroup;
    if (group == null) return [notes[startIdx]];
    final result = <NoteSequenceModel>[];
    for (var i = startIdx; i < notes.length; i++) {
      if (notes[i].chordGroup == group) {
        result.add(notes[i]);
      } else {
        break;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _TimedPc {
  final int pc;
  final DateTime at;
  _TimedPc(this.pc, this.at);
}
