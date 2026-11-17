import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/lesson_model.dart';
import '../../data/models/note_sequence_model.dart';
import '../../data/repositories/lesson_repository.dart';

// ===================== EVENTOS =====================

abstract class LessonPlayerEvent extends Equatable {
  const LessonPlayerEvent();

  @override
  List<Object?> get props => [];
}

class LoadLessonPlayer extends LessonPlayerEvent {
  final String lessonId;

  const LoadLessonPlayer(this.lessonId);

  @override
  List<Object?> get props => [lessonId];
}

class StartPlayback extends LessonPlayerEvent {
  const StartPlayback();
}

class PausePlayback extends LessonPlayerEvent {
  const PausePlayback();
}

class ResumePlayback extends LessonPlayerEvent {
  const ResumePlayback();
}

class RestartPlayback extends LessonPlayerEvent {
  const RestartPlayback();
}

class NoteEvaluated extends LessonPlayerEvent {
  final int noteIndex;
  final bool isCorrect;
  final double? centsDeviation;

  const NoteEvaluated({
    required this.noteIndex,
    required this.isCorrect,
    this.centsDeviation,
  });

  @override
  List<Object?> get props => [noteIndex, isCorrect, centsDeviation];
}

// ===================== ESTADOS =====================

abstract class LessonPlayerState extends Equatable {
  const LessonPlayerState();

  @override
  List<Object?> get props => [];
}

class LessonPlayerInitial extends LessonPlayerState {
  const LessonPlayerInitial();
}

class LessonPlayerLoading extends LessonPlayerState {
  const LessonPlayerLoading();
}

class LessonPlayerLoaded extends LessonPlayerState {
  final LessonModel lesson;
  final List<NoteSequenceModel> notes;
  final bool isPlaying;
  final int currentNoteIndex;
  final int currentMeasure;
  final int correctNotesCount;
  final int wrongNotesCount;
  final double score; // 0.0 a 100.0
  final bool isCompleted;
  final bool isOffline;

  const LessonPlayerLoaded({
    required this.lesson,
    required this.notes,
    this.isPlaying = false,
    this.currentNoteIndex = 0,
    this.currentMeasure = 1,
    this.correctNotesCount = 0,
    this.wrongNotesCount = 0,
    this.score = 100.0,
    this.isCompleted = false,
    this.isOffline = false,
  });

  NoteSequenceModel? get currentNote =>
      (currentNoteIndex >= 0 && currentNoteIndex < notes.length)
      ? notes[currentNoteIndex]
      : null;

  int get totalNotes => notes.length;

  double get progress =>
      notes.isEmpty ? 0.0 : (currentNoteIndex / notes.length).clamp(0.0, 1.0);

  LessonPlayerLoaded copyWith({
    LessonModel? lesson,
    List<NoteSequenceModel>? notes,
    bool? isPlaying,
    int? currentNoteIndex,
    int? currentMeasure,
    int? correctNotesCount,
    int? wrongNotesCount,
    double? score,
    bool? isCompleted,
    bool? isOffline,
  }) {
    return LessonPlayerLoaded(
      lesson: lesson ?? this.lesson,
      notes: notes ?? this.notes,
      isPlaying: isPlaying ?? this.isPlaying,
      currentNoteIndex: currentNoteIndex ?? this.currentNoteIndex,
      currentMeasure: currentMeasure ?? this.currentMeasure,
      correctNotesCount: correctNotesCount ?? this.correctNotesCount,
      wrongNotesCount: wrongNotesCount ?? this.wrongNotesCount,
      score: score ?? this.score,
      isCompleted: isCompleted ?? this.isCompleted,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  @override
  List<Object?> get props => [
    lesson,
    notes,
    isPlaying,
    currentNoteIndex,
    currentMeasure,
    correctNotesCount,
    wrongNotesCount,
    score,
    isCompleted,
    isOffline,
  ];
}

class LessonPlayerError extends LessonPlayerState {
  final String message;
  final bool isOffline;

  const LessonPlayerError(this.message, {this.isOffline = false});

  @override
  List<Object?> get props => [message, isOffline];
}

// ===================== BLOC =====================

class LessonPlayerBloc extends Bloc<LessonPlayerEvent, LessonPlayerState> {
  final LessonRepository lessonRepository;

  LessonPlayerBloc({required this.lessonRepository})
    : super(const LessonPlayerInitial()) {
    on<LoadLessonPlayer>(_onLoadLessonPlayer);
    on<StartPlayback>(_onStartPlayback);
    on<PausePlayback>(_onPausePlayback);
    on<ResumePlayback>(_onResumePlayback);
    on<RestartPlayback>(_onRestartPlayback);
    on<NoteEvaluated>(_onNoteEvaluated);
  }

  Future<void> _onLoadLessonPlayer(
    LoadLessonPlayer event,
    Emitter<LessonPlayerState> emit,
  ) async {
    emit(const LessonPlayerLoading());
    try {
      final detail = await lessonRepository.getLessonDetail(event.lessonId);
      final lesson = detail['lesson'] as LessonModel;
      final notes =
          (detail['notes'] as List<dynamic>?)?.cast<NoteSequenceModel>() ?? [];

      emit(
        LessonPlayerLoaded(
          lesson: lesson,
          notes: notes,
          isPlaying: false,
          currentNoteIndex: 0,
          currentMeasure: 1,
          correctNotesCount: 0,
          wrongNotesCount: 0,
          score: 100.0,
          isCompleted: false,
          isOffline: false,
        ),
      );
    } catch (e) {
      // Intentar cargar modelo directamente
      try {
        final lesson = await lessonRepository.getLessonById(event.lessonId);
        emit(
          LessonPlayerLoaded(
            lesson: lesson,
            notes: const [],
            isPlaying: false,
            currentNoteIndex: 0,
            currentMeasure: 1,
            isOffline: true,
          ),
        );
      } catch (_) {
        emit(LessonPlayerError(e.toString(), isOffline: true));
      }
    }
  }

  void _onStartPlayback(StartPlayback event, Emitter<LessonPlayerState> emit) {
    if (state is LessonPlayerLoaded) {
      final current = state as LessonPlayerLoaded;
      emit(current.copyWith(isPlaying: true));
    }
  }

  void _onPausePlayback(PausePlayback event, Emitter<LessonPlayerState> emit) {
    if (state is LessonPlayerLoaded) {
      final current = state as LessonPlayerLoaded;
      emit(current.copyWith(isPlaying: false));
    }
  }

  void _onResumePlayback(
    ResumePlayback event,
    Emitter<LessonPlayerState> emit,
  ) {
    if (state is LessonPlayerLoaded) {
      final current = state as LessonPlayerLoaded;
      emit(current.copyWith(isPlaying: true));
    }
  }

  void _onRestartPlayback(
    RestartPlayback event,
    Emitter<LessonPlayerState> emit,
  ) {
    if (state is LessonPlayerLoaded) {
      final current = state as LessonPlayerLoaded;
      emit(
        current.copyWith(
          isPlaying: false,
          currentNoteIndex: 0,
          currentMeasure: 1,
          correctNotesCount: 0,
          wrongNotesCount: 0,
          score: 100.0,
          isCompleted: false,
        ),
      );
    }
  }

  void _onNoteEvaluated(NoteEvaluated event, Emitter<LessonPlayerState> emit) {
    if (state is! LessonPlayerLoaded) return;
    final current = state as LessonPlayerLoaded;

    final newCorrect = current.correctNotesCount + (event.isCorrect ? 1 : 0);
    final newWrong = current.wrongNotesCount + (event.isCorrect ? 0 : 1);
    final evaluatedTotal = newCorrect + newWrong;
    final currentScore = evaluatedTotal == 0
        ? 100.0
        : ((newCorrect / evaluatedTotal) * 100.0).clamp(0.0, 100.0);

    final nextIndex = current.currentNoteIndex + 1;
    // Cada 4 notas avanza de compás en 4/4
    final nextMeasure = 1 + (nextIndex ~/ 4);
    final isDone = nextIndex >= current.notes.length;

    emit(
      current.copyWith(
        currentNoteIndex: nextIndex,
        currentMeasure: nextMeasure,
        correctNotesCount: newCorrect,
        wrongNotesCount: newWrong,
        score: currentScore,
        isPlaying: !isDone,
        isCompleted: isDone,
      ),
    );
  }
}
