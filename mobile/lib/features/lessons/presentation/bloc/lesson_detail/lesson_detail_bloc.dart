import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/lesson_model.dart';
import '../../../data/models/note_sequence_model.dart';
import '../../../data/repositories/lesson_repository.dart';
import 'lesson_detail_event.dart';
import 'lesson_detail_state.dart';

/// BLoC para gestionar el detalle de una lección.
class LessonDetailBloc extends Bloc<LessonDetailEvent, LessonDetailState> {
  final LessonRepository _lessonRepository;

  LessonDetailBloc({required LessonRepository lessonRepository})
    : _lessonRepository = lessonRepository,
      super(const LessonDetailInitial()) {
    on<LessonDetailLoad>(_onLoad);
    on<LessonDetailLoadSequence>(_onLoadSequence);
  }

  Future<void> _onLoad(
    LessonDetailLoad event,
    Emitter<LessonDetailState> emit,
  ) async {
    emit(const LessonDetailLoading());
    try {
      final data = await _lessonRepository.getLessonDetail(event.lessonId);
      emit(
        LessonDetailLoaded(
          lesson: data['lesson'] as LessonModel,
          notes: data['notes'] as List<NoteSequenceModel>,
          userBestScore: data['user_best_score'] as double?,
          userAttempts: data['user_attempts'] as int? ?? 0,
        ),
      );
    } catch (e) {
      emit(LessonDetailError(e.toString()));
    }
  }

  Future<void> _onLoadSequence(
    LessonDetailLoadSequence event,
    Emitter<LessonDetailState> emit,
  ) async {
    emit(const LessonDetailLoading());
    try {
      final notes = await _lessonRepository.getLessonSequence(event.lessonId);
      final currentState = state;
      if (currentState is LessonDetailLoaded) {
        emit(
          LessonDetailLoaded(
            lesson: currentState.lesson,
            notes: notes,
            userBestScore: currentState.userBestScore,
            userAttempts: currentState.userAttempts,
          ),
        );
      }
    } catch (e) {
      emit(LessonDetailError(e.toString()));
    }
  }
}
