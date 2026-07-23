import 'package:equatable/equatable.dart';

import '../../../data/models/note_sequence_model.dart';

/// Eventos del BLoC de práctica.
abstract class PracticeEvent extends Equatable {
  const PracticeEvent();

  @override
  List<Object?> get props => [];
}

/// Iniciar práctica con notas esperadas.
class PracticeStart extends PracticeEvent {
  final String lessonId;
  final List<NoteSequenceModel> expectedNotes;
  const PracticeStart({required this.lessonId, required this.expectedNotes});

  @override
  List<Object?> get props => [lessonId, expectedNotes];
}

/// Nota detectada por la IA (futuro) o botón de debug.
class PracticeNoteDetected extends PracticeEvent {
  final String detectedNote;
  final int position;
  const PracticeNoteDetected({
    required this.detectedNote,
    required this.position,
  });

  @override
  List<Object?> get props => [detectedNote, position];
}

/// Nota correcta.
class PracticeNoteCorrect extends PracticeEvent {
  final int position;
  const PracticeNoteCorrect(this.position);

  @override
  List<Object?> get props => [position];
}

/// Nota incorrecta.
class PracticeNoteWrong extends PracticeEvent {
  final int position;
  final String expected;
  final String played;
  const PracticeNoteWrong({
    required this.position,
    required this.expected,
    required this.played,
  });

  @override
  List<Object?> get props => [position, expected, played];
}

/// Pausar práctica.
class PracticePause extends PracticeEvent {
  const PracticePause();
}

/// Reanudar práctica (avanza a la siguiente nota tras una pausa).
class PracticeResume extends PracticeEvent {
  const PracticeResume();
}

/// Reintentar la MISMA nota (no avanza): se usa tras un error para que el
/// usuario repita hasta acertar, y al reanudar una pausa manual.
class PracticeRetry extends PracticeEvent {
  const PracticeRetry();
}

/// Reiniciar la lección desde la primera nota (resetea progreso y cronómetro).
class PracticeRestart extends PracticeEvent {
  const PracticeRestart();
}

/// Cambiar el filtro de manos: null = ambas, 'left' = izquierda, 'right' =
/// derecha. Reinicia la práctica con las notas de esa mano.
class PracticeSetHand extends PracticeEvent {
  final String? hand;
  const PracticeSetHand(this.hand);

  @override
  List<Object?> get props => [hand];
}

/// Loop de sección (A-B): repetir el rango de notas [start, end] (índices en la
/// secuencia) mientras [enabled]. Al pasar `end`, vuelve a `start`.
class PracticeSetLoop extends PracticeEvent {
  final bool enabled;
  final int start;
  final int end;
  const PracticeSetLoop({
    required this.enabled,
    required this.start,
    required this.end,
  });

  @override
  List<Object?> get props => [enabled, start, end];
}

/// Completar práctica.
class PracticeComplete extends PracticeEvent {
  const PracticeComplete();
}

/// Enviar resultado de práctica a la API.
class PracticeSubmitResult extends PracticeEvent {
  final double score;
  final int correctNotes;
  final int wrongNotes;
  final int missedNotes;
  final double averageTempo;
  final double totalTimeSeconds;
  final List<Map<String, dynamic>> errorsDetail;

  const PracticeSubmitResult({
    required this.score,
    required this.correctNotes,
    required this.wrongNotes,
    required this.missedNotes,
    required this.averageTempo,
    required this.totalTimeSeconds,
    required this.errorsDetail,
  });

  @override
  List<Object?> get props => [
    score,
    correctNotes,
    wrongNotes,
    missedNotes,
    averageTempo,
    totalTimeSeconds,
    errorsDetail,
  ];
}
