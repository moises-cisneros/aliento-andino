import 'package:equatable/equatable.dart';

import '../../../data/models/practice_session_model.dart';
import '../../../data/models/progress_stats_model.dart';

/// Estados del BLoC de progreso.
abstract class ProgressState extends Equatable {
  const ProgressState();

  @override
  List<Object?> get props => [];
}

class ProgressInitial extends ProgressState {
  const ProgressInitial();
}

class ProgressLoading extends ProgressState {
  const ProgressLoading();
}

class ProgressLoaded extends ProgressState {
  final ProgressStatsModel stats;
  final List<WeeklyDataPoint> weeklyData;
  final List<PracticeSessionModel> history;

  const ProgressLoaded({
    required this.stats,
    required this.weeklyData,
    required this.history,
  });

  @override
  List<Object?> get props => [stats, weeklyData, history];
}

class ProgressError extends ProgressState {
  final String message;
  const ProgressError(this.message);

  @override
  List<Object?> get props => [message];
}
