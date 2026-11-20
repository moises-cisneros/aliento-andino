import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/practice/practice_bloc.dart';
import '../bloc/practice/practice_event.dart';
import '../bloc/practice/practice_state.dart';
import '../services/note_detector.dart';

/// Widget que escucha el micrófono y emite eventos al PracticeBloc.
///
/// Los aerófonos andinos son monofónicos: usa YIN y, si la nota detectada
/// coincide con la esperada (con tolerancia de octava ±1) y está dentro de
/// [toleranceCents] del instrumento activo, emite PracticeNoteCorrect.
///
/// Para errores hay cooldown de 1s para no spammear cuando el usuario
/// mantiene una nota mala.
class NoteListenerWidget extends StatefulWidget {
  /// Expone el [NoteDetector] interno al padre (o `null` al destruirse) para que
  /// pueda controlar la grabación del mismo stream del micrófono (grabar mientras
  /// se detecta). El widget sigue siendo dueño del ciclo de vida del detector.
  final ValueChanged<NoteDetector?>? onDetector;

  /// Tolerancia de afinación (±cents) del instrumento activo
  /// (`InstrumentType.defaultToleranceCents`).
  final double toleranceCents;

  const NoteListenerWidget({
    super.key,
    this.onDetector,
    this.toleranceCents = 15.0,
  });

  @override
  State<NoteListenerWidget> createState() => _NoteListenerWidgetState();
}

class _NoteListenerWidgetState extends State<NoteListenerWidget> {
  late final NoteDetector _detector = NoteDetector(
    toleranceCents: widget.toleranceCents,
  );
  StreamSubscription<DetectedNote>? _noteSub;

  DateTime _lastWrongEmitted = DateTime.fromMillisecondsSinceEpoch(0);
  static const _wrongCooldown = Duration(seconds: 1);

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
    // Exponer el detector ya listo al padre (para grabar el stream del mic).
    widget.onDetector?.call(_detector);
  }

  @override
  void dispose() {
    // Avisar al padre que el detector ya no está disponible (no usa setState:
    // solo limpia una referencia que se lee en callbacks, no en build).
    widget.onDetector?.call(null);
    _noteSub?.cancel();
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
  void didUpdateWidget(covariant NoteListenerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _detector.toleranceCents = widget.toleranceCents;
  }

  @override
  Widget build(BuildContext context) {
    // Widget "invisible": solo lifecycle + listening.
    return BlocListener<PracticeBloc, PracticeState>(
      listener: (context, state) {
        if (state is PracticeCompleted || state is PracticeError) {
          _detector.stop();
        }
      },
      child: const SizedBox.shrink(),
    );
  }
}
