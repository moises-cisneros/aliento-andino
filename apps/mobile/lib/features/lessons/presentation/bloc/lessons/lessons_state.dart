import 'package:equatable/equatable.dart';
import 'package:mobile/core/audio/instrument.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/lesson_model.dart';

/// Estados del BLoC de lecciones.
abstract class LessonsState extends Equatable {
  const LessonsState();

  @override
  List<Object?> get props => [];
}

class LessonsInitial extends LessonsState {
  const LessonsInitial();
}

class LessonsLoading extends LessonsState {
  const LessonsLoading();
}

class LessonsLoaded extends LessonsState {
  final List<CategoryModel> categories;

  /// Lista visible (ya filtrada por categoría/dificultad/búsqueda).
  final List<LessonModel> lessons;

  /// Catálogo completo (para filtrar en cliente y calcular la ruta).
  final List<LessonModel> allLessons;

  /// Ids de lecciones bloqueadas según la ruta de aprendizaje.
  final Set<String> lockedIds;

  /// Próxima lección a hacer en la ruta (null si está todo dominado).
  final LessonModel? nextLesson;

  final String? activeCategory;
  final String? activeDifficulty;
  final String? activeGenre;
  final InstrumentType? activeInstrument;
  final String searchQuery;

  const LessonsLoaded({
    required this.categories,
    required this.lessons,
    this.allLessons = const [],
    this.lockedIds = const {},
    this.nextLesson,
    this.activeCategory,
    this.activeDifficulty,
    this.activeGenre,
    this.activeInstrument,
    this.searchQuery = '',
  });

  bool isLocked(LessonModel l) => lockedIds.contains(l.id);

  /// Géneros distintos presentes en el catálogo cargado (orden alfabético).
  List<String> get availableGenres {
    final set = <String>{};
    for (final l in allLessons) {
      final g = l.genre;
      if (g != null && g.isNotEmpty) set.add(g);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  List<Object?> get props => [
    categories,
    lessons,
    allLessons,
    lockedIds,
    nextLesson,
    activeCategory,
    activeDifficulty,
    activeGenre,
    activeInstrument,
    searchQuery,
  ];
}

class LessonsError extends LessonsState {
  final String message;
  const LessonsError(this.message);

  @override
  List<Object?> get props => [message];
}
