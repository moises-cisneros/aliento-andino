import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/audio/instrument.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/lesson_model.dart';
import '../../../data/repositories/lesson_repository.dart';
import 'learning_path.dart';
import 'lessons_event.dart';
import 'lessons_state.dart';

/// BLoC de lecciones. Carga el catálogo completo una vez, filtra en cliente
/// (categoría/dificultad/búsqueda) y calcula la ruta de aprendizaje (bloqueos
/// por dominio).
class LessonsBloc extends Bloc<LessonsEvent, LessonsState> {
  final LessonRepository _lessonRepository;

  List<CategoryModel> _categories = const [];
  List<LessonModel> _all = const [];
  Set<String> _lockedIds = const {};
  LessonModel? _next;
  InstrumentType? _instrument;
  String? _category;
  String? _difficulty;
  String? _genre;
  String _query = '';

  LessonsBloc({required LessonRepository lessonRepository})
    : _lessonRepository = lessonRepository,
      super(const LessonsInitial()) {
    on<LessonsLoadCategories>(_onLoadCategories);
    on<LessonsRefresh>(_onRefresh);
    on<LessonsLoadByCategory>(_onLoadByCategory);
    on<LessonsFilterByDifficulty>(_onFilterByDifficulty);
    on<LessonsFilterByGenre>(_onFilterByGenre);
    on<LessonsFilterByInstrument>(_onFilterByInstrument);
    on<LessonsSearch>(_onSearch);
  }

  /// Refresca scores/ruta sin loading ni perder filtros (al volver de practicar).
  Future<void> _onRefresh(
    LessonsRefresh event,
    Emitter<LessonsState> emit,
  ) async {
    if (state is! LessonsLoaded) {
      add(const LessonsLoadCategories());
      return;
    }
    try {
      _categories = await _lessonRepository.getCategories();
      final result = await _lessonRepository.getLessonsPaginated(limit: 100);
      _all = result['items'] as List<LessonModel>;
      _recomputePath();
      _emit(emit); // mantiene _category/_difficulty/_query
    } catch (_) {
      // Refresco silencioso: si falla, dejamos los datos actuales.
    }
  }

  Future<void> _onLoadCategories(
    LessonsLoadCategories event,
    Emitter<LessonsState> emit,
  ) async {
    emit(const LessonsLoading());
    try {
      _categories = await _lessonRepository.getCategories();
      final result = await _lessonRepository.getLessonsPaginated(
        instrument: _instrument?.name,
        limit: 100,
      );
      _all = result['items'] as List<LessonModel>;
      _recomputePath();
      _category = null;
      _difficulty = null;
      _query = '';
      _emit(emit);
    } catch (e) {
      emit(LessonsError(e.toString()));
    }
  }

  void _recomputePath() {
    final instrumentLessons = _instrument == null
        ? _all
        : _all
              .where(
                (l) =>
                    l.instrument.trim().toLowerCase() ==
                    _instrument!.name.toLowerCase(),
              )
              .toList();
    final path = LearningPath.compute(
      instrumentLessons.isNotEmpty ? instrumentLessons : _all,
    );
    _lockedIds = path.lockedIds;
    _next = path.next;
  }

  void _onLoadByCategory(
    LessonsLoadByCategory event,
    Emitter<LessonsState> emit,
  ) {
    if (state is! LessonsLoaded) return;
    // Toggle: tocar la categoría activa la deselecciona.
    _category = (_category == event.categoryId) ? null : event.categoryId;
    _emit(emit);
  }

  void _onFilterByDifficulty(
    LessonsFilterByDifficulty event,
    Emitter<LessonsState> emit,
  ) {
    if (state is! LessonsLoaded) return;
    _difficulty = event.difficulty;
    _emit(emit);
  }

  void _onFilterByGenre(
    LessonsFilterByGenre event,
    Emitter<LessonsState> emit,
  ) {
    if (state is! LessonsLoaded) return;
    _genre = event.genre;
    _emit(emit);
  }

  Future<void> _onFilterByInstrument(
    LessonsFilterByInstrument event,
    Emitter<LessonsState> emit,
  ) async {
    _instrument = event.instrument;
    if (state is LessonsLoaded) {
      final hasInstrumentLessons = _all.any(
        (l) =>
            l.instrument.trim().toLowerCase() ==
            event.instrument.name.toLowerCase(),
      );
      if (!hasInstrumentLessons) {
        try {
          final result = await _lessonRepository.getLessonsPaginated(
            instrument: event.instrument.name,
            limit: 100,
          );
          final items = result['items'] as List<LessonModel>;
          if (items.isNotEmpty) {
            final existingIds = _all.map((l) => l.id).toSet();
            _all.addAll(items.where((l) => !existingIds.contains(l.id)));
          }
        } catch (_) {
          // Si no hay red, conserva _all en memoria
        }
      }
      _recomputePath();
      _emit(emit);
    }
  }

  void _onSearch(LessonsSearch event, Emitter<LessonsState> emit) {
    if (state is! LessonsLoaded) return;
    _query = event.query.trim().toLowerCase();
    _emit(emit);
  }

  void _emit(Emitter<LessonsState> emit) {
    final filtered =
        _all.where((l) {
            if (_instrument != null &&
                l.instrument.trim().toLowerCase() !=
                    _instrument!.name.toLowerCase()) {
              return false;
            }
            if (_category != null && l.categoryId != _category) return false;
            if (_difficulty != null && l.difficulty != _difficulty) {
              return false;
            }
            if (_genre != null && l.genre != _genre) return false;
            if (_query.isNotEmpty &&
                !l.title.toLowerCase().contains(_query) &&
                !l.description.toLowerCase().contains(_query)) {
              return false;
            }
            return true;
          }).toList()
          // Orden de progresión: por dificultad y luego por 'order'.
          ..sort((a, b) {
            final r = LearningPath.difficultyRank(
              a.difficulty,
            ).compareTo(LearningPath.difficultyRank(b.difficulty));
            return r != 0 ? r : a.order.compareTo(b.order);
          });

    emit(
      LessonsLoaded(
        categories: _categories,
        lessons: filtered,
        allLessons: _all,
        lockedIds: _lockedIds,
        nextLesson: _next,
        activeCategory: _category,
        activeDifficulty: _difficulty,
        activeGenre: _genre,
        activeInstrument: _instrument,
        searchQuery: _query,
      ),
    );
  }
}
