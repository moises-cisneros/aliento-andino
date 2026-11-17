import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/note_sequence_model.dart';
import '../bloc/practice/practice_bloc.dart';
import '../bloc/practice/practice_event.dart';
import '../bloc/practice/practice_state.dart';
import '../services/note_detector.dart';

/// Widget que escucha el micrófono y emite eventos al PracticeBloc.
///
/// Comportamiento dual:
/// - **Notas individuales** (is_chord=false): YIN monofónico. Match (con
///   tolerancia de octava ±1) → PracticeNoteCorrect.
/// - **Acordes** (is_chord=true): FFT polifónico. Detecta hasta 4 notas
///   simultáneas, compara pitch classes con el chord_group y emite Correct
///   por cada posición del grupo si hay match.
///
/// Para errores hay cooldown de 1s (notas) / 2s (acordes) para no spammear
/// cuando el usuario mantiene una nota mala.
class NoteListenerWidget extends StatefulWidget {
  /// Expone el [NoteDetector] interno al padre (o `null` al destruirse) para que
  /// pueda controlar la grabación del mismo stream del micrófono (grabar mientras
  /// se detecta). El widget sigue siendo dueño del ciclo de vida del detector.
  final ValueChanged<NoteDetector?>? onDetector;

  const NoteListenerWidget({super.key, this.onDetector});

  @override
  State<NoteListenerWidget> createState() => _NoteListenerWidgetState();
}

class _NoteListenerWidgetState extends State<NoteListenerWidget> {
  final NoteDetector _detector = NoteDetector();
  StreamSubscription<DetectedNote>? _noteSub;
  StreamSubscription<ChordDetectionResult>? _chordSub;

  DateTime _lastWrongEmitted = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastChordWrongEmitted = DateTime.fromMillisecondsSinceEpoch(0);
  static const _wrongCooldown = Duration(seconds: 1);
  static const _chordWrongCooldown = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ok = await _detector.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo acceder al micrófono. La práctica seguirá manual.',
            ),
          ),
        );
      }
      return;
    }
    // El widget pudo haberse destruido mientras esperábamos start(): en ese caso
    // no suscribimos (quedarían listeners sin cancelar) y liberamos el detector.
    if (!mounted) {
      unawaited(_detector.dispose());
      return;
    }
    _noteSub = _detector.notes.listen(_onNoteDetected);
    _chordSub = _detector.chords.listen(_onChordDetected);
    // Exponer el detector ya listo al padre (para grabar el stream del mic).
    widget.onDetector?.call(_detector);
  }

  @override
  void dispose() {
    // Avisar al padre que el detector ya no está disponible (no usa setState:
    // solo limpia una referencia que se lee en callbacks, no en build).
    widget.onDetector?.call(null);
    _noteSub?.cancel();
    _chordSub?.cancel();
    // dispose() es síncrono y no podemos await; dejamos la limpieza async
    // explícita. NoteDetector.dispose() ya es robusto ante fallos parciales.
    unawaited(_detector.dispose());
    super.dispose();
  }

  void _onNoteDetected(DetectedNote detected) {
    if (!mounted) return;
    final state = context.read<PracticeBloc>().state;
    if (state is! PracticePlaying) return;
    if (state.currentPosition >= state.notes.length) return;

    final current = state.notes[state.currentPosition];
    // Si la posición actual es parte de un acorde, lo maneja el chord listener.
    if (current.isChord) return;

    final expected = state.currentExpectedNote;
    if (expected.toUpperCase() == 'REST') return;

    final match = _matchesExpected(
      detected.note,
      expected,
      !state.octaveStrict,
    );
    if (match) {
      context.read<PracticeBloc>().add(
        PracticeNoteCorrect(state.currentPosition),
      );
    } else {
      // Cooldown para no spammear errores cuando el usuario sostiene una nota mala
      final now = DateTime.now();
      if (now.difference(_lastWrongEmitted) < _wrongCooldown) return;
      _lastWrongEmitted = now;
      context.read<PracticeBloc>().add(
        PracticeNoteWrong(
          position: state.currentPosition,
          expected: expected,
          played: detected.note,
        ),
      );
    }
  }

  void _onChordDetected(ChordDetectionResult result) {
    if (!mounted) return;
    final state = context.read<PracticeBloc>().state;
    if (state is! PracticePlaying) return;
    if (state.currentPosition >= state.notes.length) return;

    final current = state.notes[state.currentPosition];
    if (!current.isChord) return;

    // Recolectar todas las notas del mismo chord_group
    final group = _gatherChordGroup(state.notes, state.currentPosition);
    if (group.isEmpty) return;

    // Pitch classes esperadas (sin octava)
    final expectedPCs = <int>{};
    for (final n in group) {
      final m = _noteToMidi(n.note);
      if (m != null) expectedPCs.add(m % 12);
    }
    if (expectedPCs.isEmpty) return;

    final detectedPCs = result.pitches.map((p) => p.midi % 12).toSet();
    final intersection = expectedPCs.intersection(detectedPCs);
    // Tolerancia: al menos ceil(N/2) notas correctas del acorde
    final required = ((expectedPCs.length + 1) / 2).ceil();

    if (intersection.length >= required) {
      // Match → emitir Correct para cada posición del grupo
      final bloc = context.read<PracticeBloc>();
      for (var i = 0; i < group.length; i++) {
        bloc.add(PracticeNoteCorrect(state.currentPosition + i));
      }
    } else {
      final now = DateTime.now();
      if (now.difference(_lastChordWrongEmitted) < _chordWrongCooldown) return;
      _lastChordWrongEmitted = now;
      final played =
          result.match?.label ??
          result.pitches.take(3).map((p) => p.note).join('+');
      final expectedLabel = group.map((n) => n.note).join('+');
      context.read<PracticeBloc>().add(
        PracticeNoteWrong(
          position: state.currentPosition,
          expected: expectedLabel,
          played: played,
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

  /// Parsea "C4", "F#5", "Bb3" → número MIDI. Retorna null si no parsea.
  int? _noteToMidi(String note) {
    final m = RegExp(r'^([A-G])([#b]?)(\d+)').firstMatch(note);
    if (m == null) return null;
    final letter = m.group(1)!;
    final accidental = m.group(2)!;
    final octave = int.parse(m.group(3)!);
    const letterToSemi = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    var semi = letterToSemi[letter]!;
    if (accidental == '#') semi++;
    if (accidental == 'b') semi--;
    return (octave + 1) * 12 + semi;
  }

  /// Compara nota detectada con la esperada. Si [tolerateOctave] es true,
  /// "C4" == "C5" se considera match (principiante). En estricto, la octava
  /// debe coincidir (intermedio/avanzado).
  bool _matchesExpected(String detected, String expected, bool tolerateOctave) {
    if (detected == expected) return true;
    if (!tolerateOctave) return false;
    return _noteName(detected) == _noteName(expected);
  }

  String _noteName(String note) {
    // Quita el dígito de octava (último char numérico)
    final m = RegExp(r'^([A-G][#b]?)').firstMatch(note);
    return m?.group(1) ?? note;
  }

  @override
  Widget build(BuildContext context) {
    // Widget "invisible": solo lifecycle + listening.
    // Activa/desactiva chord detection cuando la posición actual entra/sale
    // de un acorde.
    return BlocListener<PracticeBloc, PracticeState>(
      listener: (context, state) {
        if (state is PracticePlaying) {
          final inChord =
              state.currentPosition < state.notes.length &&
              state.notes[state.currentPosition].isChord;
          _detector.setChordDetectionEnabled(inChord);
        } else if (state is PracticeCompleted || state is PracticeError) {
          _detector.stop();
        }
      },
      child: const SizedBox.shrink(),
    );
  }
}
