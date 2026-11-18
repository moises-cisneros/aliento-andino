import 'package:dio/dio.dart';

import '../../../../core/audio/instrument.dart';
import '../../../../core/network/api_client.dart';
import '../datasources/local_lesson_datasource.dart';
import '../models/category_model.dart';
import '../models/lesson_model.dart';
import '../models/note_sequence_model.dart';
import '../services/lesson_download_service.dart';

/// Repositorio de lecciones con soporte offline-first.
///
/// Estrategia: intenta la red y cachea el resultado; si no hay conexión
/// (DioException), devuelve lo último cacheado. Además permite "descargar" una
/// lección para practicarla sin internet.
class LessonRepository {
  final ApiClient _apiClient;
  final LocalLessonDataSource? _local;
  final LessonDownloadService? _downloads;

  const LessonRepository({
    required ApiClient apiClient,
    LocalLessonDataSource? local,
    LessonDownloadService? downloads,
  }) : _apiClient = apiClient,
       _local = local,
       _downloads = downloads;

  /// Obtener catálogo de lecciones filtradas por instrumento andino y dificultad (SUB-04-B / HU-04).
  Future<List<LessonModel>> getLessons({
    required InstrumentType instrument,
    String? difficulty,
  }) async {
    try {
      final queryParams = <String, dynamic>{'instrument': instrument.name};
      if (difficulty != null && difficulty.isNotEmpty) {
        queryParams['difficulty'] = difficulty;
      }

      final response = await _apiClient.dio.get(
        '/v1/lessons',
        queryParameters: queryParams,
      );
      final list = response.data as List<dynamic>;
      final items = list
          .map((e) => LessonModel.fromJson(e as Map<String, dynamic>))
          .toList();

      await _local?.cacheLessons(items);
      return items;
    } on DioException {
      final cached = await _local?.getLessons(difficulty: difficulty);
      if (cached != null && cached.isNotEmpty) {
        final filtered = cached
            .where((l) => l.instrument == instrument.name)
            .toList();
        if (filtered.isNotEmpty) return filtered;
        return cached;
      }
      rethrow;
    }
  }

  /// Obtener modelo de lección por ID (SUB-04-B / HU-04).
  Future<LessonModel> getLessonById(String lessonId) async {
    try {
      final response = await _apiClient.dio.get('/v1/lessons/$lessonId');
      final data = response.data as Map<String, dynamic>;
      final lesson = LessonModel.fromJson(data);
      final notes =
          (data['notes'] as List<dynamic>?)
              ?.map(
                (e) => NoteSequenceModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [];
      if (notes.isNotEmpty) {
        await _local?.cacheLessonDetail(lesson, notes);
      }
      return lesson;
    } on DioException {
      final cached = await _local?.getLesson(lessonId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Obtener categorías activas con conteo de lecciones.
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _apiClient.dio.get('/lessons/categories');
      final data = response.data as List<dynamic>;
      final categories = data
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _local?.cacheCategories(categories);
      return categories;
    } on DioException {
      final cached = await _local?.getCategories();
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  /// Obtener lecciones con filtros paginados (compatibilidad con flujo previo).
  Future<Map<String, dynamic>> getLessonsPaginated({
    String? categoryId,
    String? difficulty,
    String? genre,
    String? search,
    String? instrument,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (genre != null && genre.isNotEmpty) queryParams['genre'] = genre;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (instrument != null && instrument.isNotEmpty) {
        queryParams['instrument'] = instrument;
      }

      final response = await _apiClient.dio.get(
        '/lessons',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .map((e) => LessonModel.fromJson(e as Map<String, dynamic>))
          .toList();

      await _local?.cacheLessons(items);

      return {
        'items': items,
        'total': data['total'],
        'page': data['page'],
        'pages': data['pages'],
      };
    } on DioException {
      // Sin red: devolver lo cacheado (sin búsqueda de texto offline).
      final cached = await _local?.getLessons(
        categoryId: categoryId,
        difficulty: difficulty,
      );
      if (cached != null && cached.isNotEmpty) {
        var filtered = cached;
        if (instrument != null && instrument.isNotEmpty) {
          filtered = filtered
              .where(
                (l) => l.instrument.toLowerCase() == instrument.toLowerCase(),
              )
              .toList();
        }
        return {
          'items': filtered,
          'total': filtered.length,
          'page': 1,
          'pages': 1,
        };
      }
      rethrow;
    }
  }

  /// Obtener detalle de lección con notas y progreso del usuario.
  Future<Map<String, dynamic>> getLessonDetail(String lessonId) async {
    try {
      final response = await _apiClient.dio.get('/lessons/$lessonId');
      final data = response.data as Map<String, dynamic>;

      final lesson = LessonModel.fromJson(data);
      final notes =
          (data['notes'] as List<dynamic>?)
              ?.map(
                (e) => NoteSequenceModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [];
      final userBestScore = (data['user_best_score'] as num?)?.toDouble();
      final userAttempts = data['user_attempts'] as int? ?? 0;

      // Cacheamos lección + notas (sin marcar "descargada"); así, si después
      // se va el internet, la práctica de esta lección igual funciona.
      if (notes.isNotEmpty) {
        await _local?.cacheLessonDetail(lesson, notes);
      }

      return {
        'lesson': lesson,
        'notes': notes,
        'user_best_score': userBestScore,
        'user_attempts': userAttempts,
      };
    } on DioException {
      final lesson = await _local?.getLesson(lessonId);
      if (lesson != null) {
        final notes = await _local?.getNotes(lessonId) ?? [];
        return {
          'lesson': lesson,
          'notes': notes,
          'user_best_score': lesson.userBestScore,
          'user_attempts': 0,
        };
      }
      rethrow;
    }
  }

  /// Obtener solo la secuencia de notas (endpoint ligero).
  Future<List<NoteSequenceModel>> getLessonSequence(String lessonId) async {
    try {
      final response = await _apiClient.dio.get('/lessons/$lessonId/sequence');
      final data = response.data as List<dynamic>;
      return data
          .map((e) => NoteSequenceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException {
      final cached = await _local?.getNotes(lessonId);
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  /// Obtener lecciones recomendadas según el skill_level del usuario.
  Future<List<LessonModel>> getRecommended({int limit = 6}) async {
    try {
      final response = await _apiClient.dio.get(
        '/lessons/recommended',
        queryParameters: {'limit': limit},
      );
      final data = response.data as List<dynamic>;
      final items = data
          .map((e) => LessonModel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _local?.cacheLessons(items);
      return items;
    } on DioException {
      // Fallback: lo descargado para offline es lo más útil de recomendar.
      final cached = await _local?.getLessons(onlyDownloaded: true);
      if (cached != null && cached.isNotEmpty) {
        return cached.take(limit).toList();
      }
      rethrow;
    }
  }

  // ---------------- Offline ----------------

  /// Descarga una lección (notas + audio) y la marca como disponible para
  /// practicar sin conexión. Todo o nada: ver [LessonDownloadService].
  Future<void> downloadLesson(String lessonId) {
    return _requireDownloads().downloadLesson(lessonId);
  }

  /// Elimina la lección descargada (base local y archivo de audio).
  Future<void> deleteDownloadedLesson(String lessonId) {
    return _requireDownloads().deleteDownloadedLesson(lessonId);
  }

  /// Descargas con el espacio que ocupan; detecta audios borrados a mano.
  Future<OfflineDownloads> getOfflineDownloads() {
    return _requireDownloads().listDownloads();
  }

  LessonDownloadService _requireDownloads() {
    final service = _downloads;
    if (service == null) {
      throw StateError(
        'LessonRepository was created without a download service',
      );
    }
    return service;
  }

  /// Lecciones descargadas para uso offline.
  Future<List<LessonModel>> getDownloadedLessons() async {
    return await _local?.getLessons(onlyDownloaded: true) ?? [];
  }

  /// Indica si una lección está descargada para offline.
  Future<bool> isDownloaded(String lessonId) async {
    return await _local?.isDownloaded(lessonId) ?? false;
  }
}
