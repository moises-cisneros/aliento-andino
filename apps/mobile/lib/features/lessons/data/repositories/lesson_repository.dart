import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/network/api_client.dart';
import '../datasources/local_lesson_datasource.dart';
import '../models/category_model.dart';
import '../models/lesson_model.dart';
import '../models/note_sequence_model.dart';

/// Repositorio de lecciones con soporte offline-first.
///
/// Estrategia: intenta la red y cachea el resultado; si no hay conexión
/// (DioException), devuelve lo último cacheado. Además permite "descargar" una
/// lección para practicarla sin internet.
class LessonRepository {
  final ApiClient _apiClient;
  final LocalLessonDataSource? _local;

  const LessonRepository({
    required ApiClient apiClient,
    LocalLessonDataSource? local,
  }) : _apiClient = apiClient,
       _local = local;

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

  /// Obtener lecciones con filtros. El catálogo es curado (~decenas de
  /// lecciones), así que se trae todo de una (limit 100 = tope del backend) para
  /// que la lista no quede cortada. Si algún día supera las 100, conviene
  /// paginar/scroll infinito.
  Future<Map<String, dynamic>> getLessons({
    String? categoryId,
    String? difficulty,
    String? search,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

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
        return {'items': cached, 'total': cached.length, 'page': 1, 'pages': 1};
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

  /// Descarga una lección (metadatos + secuencia de notas) y la marca como
  /// disponible para practicar sin conexión.
  Future<void> downloadLesson(String lessonId) async {
    final response = await _apiClient.dio.get('/lessons/$lessonId');
    final data = response.data as Map<String, dynamic>;
    final lesson = LessonModel.fromJson(data);

    var notes =
        (data['notes'] as List<dynamic>?)
            ?.map((e) => NoteSequenceModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <NoteSequenceModel>[];

    // Si el detalle no trajo notas, pedimos el endpoint de secuencia.
    if (notes.isEmpty) {
      notes = await getLessonSequence(lessonId);
    }

    await _local?.cacheLessonDetail(lesson, notes, markDownloaded: true);

    // Descargar el audio de preview para reproducirlo offline (best-effort:
    // si falla, la lección igual queda descargada para practicar).
    final audioUrl = lesson.audioPreviewUrl;
    if (_local != null && audioUrl != null && audioUrl.isNotEmpty) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/lesson_audio_$lessonId${_audioExt(audioUrl)}';
        // Dio fresco: el audio vive en GCS, no en la API (sin interceptores).
        await Dio().download(audioUrl, path);
        await _local.setAudioLocalPath(lessonId, path);
      } catch (_) {
        // Audio opcional: ignorar fallos de descarga.
      }
    }
  }

  String _audioExt(String url) {
    final urlPath = Uri.parse(url).path;
    final dot = urlPath.lastIndexOf('.');
    if (dot != -1 && dot > urlPath.lastIndexOf('/')) {
      return urlPath.substring(dot);
    }
    return '.mp3';
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
