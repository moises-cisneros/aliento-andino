import 'package:equatable/equatable.dart';

import '../../../data/models/lesson_model.dart';
import '../../../data/models/note_sequence_model.dart';

/// Estados del BLoC de detalle de lección.
abstract class LessonDetailState extends Equatable {
  const LessonDetailState();

  @override
  List<Object?> get props => [];
}

class LessonDetailInitial extends LessonDetailState {
  const LessonDetailInitial();
}

class LessonDetailLoading extends LessonDetailState {
  const LessonDetailLoading();
}

class LessonDetailLoaded extends LessonDetailState {
  final LessonModel lesson;
  final List<NoteSequenceModel> notes;
  final double? userBestScore;
  final int userAttempts;

  const LessonDetailLoaded({
    required this.lesson,
    required this.notes,
    this.userBestScore,
    this.userAttempts = 0,
  });

  @override
  List<Object?> get props => [lesson, notes, userBestScore, userAttempts];
}

class LessonDetailError extends LessonDetailState {
  final String message;
  const LessonDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
