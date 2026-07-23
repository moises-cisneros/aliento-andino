import 'package:equatable/equatable.dart';

/// Eventos del BLoC de progreso.
abstract class ProgressEvent extends Equatable {
  const ProgressEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar estadísticas generales.
class ProgressLoadStats extends ProgressEvent {
  const ProgressLoadStats();
}

/// Cargar progreso semanal.
class ProgressLoadWeekly extends ProgressEvent {
  const ProgressLoadWeekly();
}

/// Cargar historial de prácticas.
class ProgressLoadHistory extends ProgressEvent {
  final String? lessonId;
  final int page;

  const ProgressLoadHistory({this.lessonId, this.page = 1});

  @override
  List<Object?> get props => [lessonId, page];
}
