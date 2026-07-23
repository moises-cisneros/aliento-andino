import 'package:equatable/equatable.dart';

import '../../../data/models/lesson_model.dart';
import '../../../data/models/note_sequence_model.dart';
import '../../../data/models/practice_session_model.dart';

/// Estados del BLoC de práctica.
abstract class PracticeState extends Equatable {
  const PracticeState();

  @override
  List<Object?> get props => [];
}

class PracticeInitial extends PracticeState {
  const PracticeInitial();
}

class PracticeReady extends PracticeState {
  final LessonModel lesson;
  final List<NoteSequenceModel> notes;
  final int currentPosition;

  const PracticeReady({
    required this.lesson,
    required this.notes,
    this.currentPosition = 0,
  });

  @override
  List<Object?> get props => [lesson, notes, currentPosition];
}

class PracticePlaying extends PracticeState {
  final int currentPosition;
  final int correctCount;
  final int wrongCount;
  final String currentExpectedNote;
  final double elapsedSeconds;
  final List<NoteSequenceModel> notes;

  /// Feedback transitorio del último error (no bloquea: la práctica sigue en
  /// la misma nota). La UI lo muestra un par de segundos y se desvanece.
  final String? lastWrongPlayed;
  final String? lastWrongExpected;

  /// Si true (intermedio/avanzado), la octava importa: tocar la nota correcta
  /// en otra octava NO cuenta. En principiante es false (tolerante).
  final bool octaveStrict;

  /// Filtro de manos activo: null = ambas, 'left' = solo izquierda, 'right' =
  /// solo derecha. [handFilterAvailable] indica si la lección tiene notas de
  /// ambas manos (si no, no tiene sentido mostrar el selector).
  final String? handFilter;
  final bool handFilterAvailable;

  const PracticePlaying({
    required this.currentPosition,
    required this.correctCount,
    required this.wrongCount,
    required this.currentExpectedNote,
    required this.elapsedSeconds,
    required this.notes,
    this.lastWrongPlayed,
    this.lastWrongExpected,
    this.octaveStrict = false,
    this.handFilter,
    this.handFilterAvailable = false,
  });

  @override
  List<Object?> get props => [
    currentPosition,
    correctCount,
    wrongCount,
    currentExpectedNote,
    elapsedSeconds,
    lastWrongPlayed,
    lastWrongExpected,
    octaveStrict,
    handFilter,
    handFilterAvailable,
  ];
}

class PracticePaused extends PracticeState {
  final int currentPosition;
  final int correctCount;
  final int wrongCount;
  final String? errorMessage;
  final String? expectedNote;
  final String? playedNote;
  final List<NoteSequenceModel> notes;
  final double elapsedSeconds;

  const PracticePaused({
    required this.currentPosition,
    required this.correctCount,
    required this.wrongCount,
    this.errorMessage,
    this.expectedNote,
    this.playedNote,
    required this.notes,
    this.elapsedSeconds = 0,
  });

  @override
  List<Object?> get props => [
    currentPosition,
    correctCount,
    wrongCount,
    errorMessage,
    elapsedSeconds,
  ];
}

class PracticeCompleted extends PracticeState {
  final double score;
  final int correctNotes;
  final int totalNotes;
  final int wrongNotes;
  final double averageTempo;
  final double elapsedSeconds;
  final List<Map<String, dynamic>> errorsDetail;

  const PracticeCompleted({
    required this.score,
    required this.correctNotes,
    required this.totalNotes,
    required this.wrongNotes,
    required this.averageTempo,
    required this.errorsDetail,
    this.elapsedSeconds = 0,
  });

  @override
  List<Object?> get props => [
    score,
    correctNotes,
    totalNotes,
    wrongNotes,
    averageTempo,
    elapsedSeconds,
  ];
}

class PracticeResultSubmitted extends PracticeState {
  final PracticeSessionModel session;
  final String? aiFeedback;

  const PracticeResultSubmitted({required this.session, this.aiFeedback});

  @override
  List<Object?> get props => [session, aiFeedback];
}

class PracticeError extends PracticeState {
  final String message;
  const PracticeError(this.message);

  @override
  List<Object?> get props => [message];
}
