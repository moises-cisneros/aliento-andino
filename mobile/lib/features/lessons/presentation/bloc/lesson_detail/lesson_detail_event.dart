import 'package:equatable/equatable.dart';

/// Eventos del BLoC de detalle de lección.
abstract class LessonDetailEvent extends Equatable {
  const LessonDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar detalle de lección.
class LessonDetailLoad extends LessonDetailEvent {
  final String lessonId;
  const LessonDetailLoad(this.lessonId);

  @override
  List<Object?> get props => [lessonId];
}

/// Cargar solo la secuencia de notas.
class LessonDetailLoadSequence extends LessonDetailEvent {
  final String lessonId;
  const LessonDetailLoadSequence(this.lessonId);

  @override
  List<Object?> get props => [lessonId];
}
