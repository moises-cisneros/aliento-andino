import 'package:equatable/equatable.dart';
import 'package:mobile/core/audio/instrument.dart';

/// Eventos del BLoC de lecciones.
abstract class LessonsEvent extends Equatable {
  const LessonsEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar categorías.
class LessonsLoadCategories extends LessonsEvent {
  const LessonsLoadCategories();
}

/// Refrescar datos (scores/ruta) SIN mostrar loading ni perder los filtros
/// activos. Se usa al volver de una lección para actualizar la ruta.
class LessonsRefresh extends LessonsEvent {
  const LessonsRefresh();
}

/// Cargar lecciones de una categoría.
class LessonsLoadByCategory extends LessonsEvent {
  final String categoryId;
  const LessonsLoadByCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

/// Filtrar por dificultad.
class LessonsFilterByDifficulty extends LessonsEvent {
  final String? difficulty;
  const LessonsFilterByDifficulty(this.difficulty);

  @override
  List<Object?> get props => [difficulty];
}

/// Filtrar por género musical (null = todos).
class LessonsFilterByGenre extends LessonsEvent {
  final String? genre;
  const LessonsFilterByGenre(this.genre);

  @override
  List<Object?> get props => [genre];
}

/// Filtrar por instrumento andino.
class LessonsFilterByInstrument extends LessonsEvent {
  final InstrumentType instrument;
  const LessonsFilterByInstrument(this.instrument);

  @override
  List<Object?> get props => [instrument];
}

/// Buscar lecciones por texto.
class LessonsSearch extends LessonsEvent {
  final String query;
  const LessonsSearch(this.query);

  @override
  List<Object?> get props => [query];
}
