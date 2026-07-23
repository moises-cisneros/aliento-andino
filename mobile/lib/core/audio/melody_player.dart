import 'dart:async';

import '../../features/lessons/data/models/note_sequence_model.dart';
import 'tone_synth.dart';

/// Reproduce una secuencia de notas con el [ToneSynth] al tempo de la lección,
/// con multiplicador de velocidad (cámara lenta). Agrupa acordes (mismo
/// chord_group) para que suenen juntos y respeta los silencios.
class MelodyPlayer {
  final ToneSynth _synth;
  bool _playing = false;
  int _runId = 0;

  MelodyPlayer(this._synth);

  bool get isPlaying => _playing;

  /// Reproduce [notes] a [bpm] por [tempo] (1.0 = normal, 0.5 = mitad). Llama
  /// [onIndex] al sonar cada nota/acorde (para resaltar) y [onDone] al terminar.
  Future<void> play(
    List<NoteSequenceModel> notes, {
    required int bpm,
    double tempo = 1.0,
    void Function(int index)? onIndex,
    void Function()? onDone,
  }) async {
    stop();
    _playing = true;
    final runId = ++_runId;
    final beatMs = 60000.0 / (bpm <= 0 ? 80 : bpm) / (tempo <= 0 ? 1.0 : tempo);

    var i = 0;
    while (_playing && runId == _runId && i < notes.length) {
      final note = notes[i];
      final group = note.chordGroup;
      double durBeats;
      if (group != null) {
        // Agrupar todas las notas consecutivas del mismo acorde.
        final start = i;
        while (i < notes.length && notes[i].chordGroup == group) {
          final n = notes[i];
          if (!n.isRest) {
            _synth.play(n.note, seconds: _toneSeconds(n.duration, beatMs));
          }
          i++;
        }
        durBeats = notes[start].duration;
        onIndex?.call(start);
      } else {
        if (!note.isRest) {
          _synth.play(note.note,
              seconds: _toneSeconds(note.duration, beatMs));
        }
        durBeats = note.duration;
        onIndex?.call(i);
        i++;
      }
      await Future.delayed(
        Duration(milliseconds: (durBeats * beatMs).round()),
      );
    }

    if (_playing && runId == _runId) {
      _playing = false;
      onDone?.call();
    }
  }

  double _toneSeconds(double durBeats, double beatMs) {
    final s = durBeats * beatMs / 1000.0;
    return s.clamp(0.25, 1.6);
  }

  void stop() {
    _playing = false;
    _runId++;
    _synth.stopAll();
  }
}
