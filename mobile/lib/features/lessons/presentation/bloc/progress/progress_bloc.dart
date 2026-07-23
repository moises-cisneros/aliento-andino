import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/network/network_error.dart';
import '../../../data/models/practice_session_model.dart';
import '../../../data/repositories/practice_repository.dart';
import 'progress_event.dart';
import 'progress_state.dart';

/// BLoC para gestionar el progreso y estadísticas del usuario.
class ProgressBloc extends Bloc<ProgressEvent, ProgressState> {
  final PracticeRepository _practiceRepository;

  ProgressBloc({required PracticeRepository practiceRepository})
    : _practiceRepository = practiceRepository,
      super(const ProgressInitial()) {
    on<ProgressLoadStats>(_onLoadStats);
    on<ProgressLoadWeekly>(_onLoadWeekly);
    on<ProgressLoadHistory>(_onLoadHistory);
  }

  Future<void> _onLoadStats(
    ProgressLoadStats event,
    Emitter<ProgressState> emit,
  ) async {
    emit(const ProgressLoading());
    try {
      final stats = await _practiceRepository.getProgressStats();
      final weekly = await _practiceRepository.getWeeklyProgress();
      final historyResult = await _practiceRepository.getPracticeHistory();
      final history = historyResult['items'] as List<PracticeSessionModel>;

      emit(ProgressLoaded(stats: stats, weeklyData: weekly, history: history));
    } catch (e) {
      emit(ProgressError(_friendlyError(e)));
    }
  }

  Future<void> _onLoadWeekly(
    ProgressLoadWeekly event,
    Emitter<ProgressState> emit,
  ) async {
    final currentState = state;
    try {
      final weekly = await _practiceRepository.getWeeklyProgress();
      if (currentState is ProgressLoaded) {
        emit(
          ProgressLoaded(
            stats: currentState.stats,
            weeklyData: weekly,
            history: currentState.history,
          ),
        );
      }
    } catch (e) {
      emit(ProgressError(_friendlyError(e)));
    }
  }

  Future<void> _onLoadHistory(
    ProgressLoadHistory event,
    Emitter<ProgressState> emit,
  ) async {
    final currentState = state;
    try {
      final result = await _practiceRepository.getPracticeHistory(
        lessonId: event.lessonId,
        page: event.page,
      );
      final history = result['items'] as List<PracticeSessionModel>;

      if (currentState is ProgressLoaded) {
        emit(
          ProgressLoaded(
            stats: currentState.stats,
            weeklyData: currentState.weeklyData,
            history: history,
          ),
        );
      } else {
        final stats = await _practiceRepository.getProgressStats();
        final weekly = await _practiceRepository.getWeeklyProgress();
        emit(
          ProgressLoaded(stats: stats, weeklyData: weekly, history: history),
        );
      }
    } catch (e) {
      emit(ProgressError(_friendlyError(e)));
    }
  }

  String _friendlyError(Object e) {
    if (isConnectionError(e)) return offlineMessage;
    if (e is DioException) return 'Error de conexión con el servidor';
    return e.toString().replaceFirst('Exception: ', '');
  }
}
