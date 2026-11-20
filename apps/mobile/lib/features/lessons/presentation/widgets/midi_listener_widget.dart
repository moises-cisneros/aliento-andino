import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/midi_input_service.dart';
import '../bloc/practice/practice_bloc.dart';
import '../bloc/practice/practice_event.dart';
import '../bloc/practice/practice_state.dart';

/// Escucha la entrada MIDI (vía [MidiInputService]) y la evalúa contra la nota
/// esperada del PracticeBloc, igual que el micrófono pero con **precisión
/// exacta** (recibe la tecla digital, no infiere del sonido).
///
/// Compara la tecla MIDI (con tolerancia de octava) contra la nota esperada →
/// `PracticeNoteCorrect` / `PracticeNoteWrong` (cooldown 1s). Los aerófonos
/// andinos son monofónicos: no existe evaluación de acordes.
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

    _onSingleNote(e, state);
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

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
