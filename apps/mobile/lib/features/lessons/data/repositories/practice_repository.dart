import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/api_client.dart';
import '../models/practice_session_model.dart';
import '../models/progress_stats_model.dart';

/// Repositorio de práctica y progreso con soporte offline.
///
/// `submitPractice` envía al backend si hay conexión; si no, encola la práctica
/// en el outbox local (Drift) y devuelve un resultado "pendiente" para que la
/// UI no se rompa. El [PracticeSyncService] vacía esa cola al reconectar.
class PracticeRepository {
  final ApiClient _apiClient;
  final AppDatabase? _db;

  static const _uuid = Uuid();

  static const _pendingFeedbackMsg =
      'Tu práctica se guardó sin conexión. El XP y el feedback con IA se '
      'aplicarán cuando vuelvas a tener internet.';

  const PracticeRepository({required ApiClient apiClient, AppDatabase? db})
    : _apiClient = apiClient,
      _db = db;

  /// Enviar resultado de práctica. Offline → se encola y se devuelve "pendiente".
  Future<Map<String, dynamic>> submitPractice({
    required String lessonId,
    required double score,
    required int correctNotes,
    required int totalNotes,
    required int wrongNotes,
    required int missedNotes,
    required double averageTempo,
    required double totalTimeSeconds,
    List<Map<String, dynamic>>? errorsDetail,
    bool completed = true,
    String? clientId,
  }) async {
    final cid = clientId ?? _uuid.v4();
    final body = <String, dynamic>{
      'client_id': cid,
      'lesson_id': lessonId,
      'score': score,
      'correct_notes': correctNotes,
      'total_notes': totalNotes,
      'wrong_notes': wrongNotes,
      'missed_notes': missedNotes,
      'average_tempo': averageTempo,
      'total_time_seconds': totalTimeSeconds,
      'errors_detail': errorsDetail,
      'completed': completed,
    };

    try {
      final response = await _apiClient.dio.post(
        '/practice/submit',
        data: body,
      );
      final data = response.data as Map<String, dynamic>;
      return {
        'session': PracticeSessionModel.fromJson(
          data['session'] as Map<String, dynamic>,
        ),
        'ai_feedback': data['ai_feedback'] as String?,
        'xp_earned': data['xp_earned'] as int? ?? 0,
        'new_level': data['new_level'] as bool? ?? false,
        'current_level': data['current_level'] as int? ?? 1,
        'new_achievements': data['new_achievements'] as List? ?? [],
        'pending': false,
      };
    } on DioException catch (e) {
      // Si el servidor respondió (4xx/5xx), NO es falta de conexión: propagamos
      // para no mostrar un falso "guardado sin conexión". Solo encolamos cuando
      // de verdad no hubo respuesta (timeout / sin red).
      if (e.response != null) rethrow;
      // Sin conexión real: encolar para sincronizar después.
      await _db?.enqueuePractice(
        PendingPracticeCompanion.insert(
          clientId: cid,
          lessonId: lessonId,
          score: score,
          correctNotes: correctNotes,
          totalNotes: totalNotes,
          wrongNotes: wrongNotes,
          missedNotes: missedNotes,
          averageTempo: averageTempo,
          totalTimeSeconds: totalTimeSeconds,
          errorsDetailJson: Value(
            errorsDetail == null ? null : jsonEncode(errorsDetail),
          ),
          completed: Value(completed),
        ),
      );

      final localSession = PracticeSessionModel(
        id: cid,
        userId: '',
        lessonId: lessonId,
        score: score,
        correctNotes: correctNotes,
        totalNotes: totalNotes,
        wrongNotes: wrongNotes,
        missedNotes: missedNotes,
        averageTempo: averageTempo,
        expectedTempo: 0,
        tempoAccuracy: 0,
        totalTimeSeconds: totalTimeSeconds,
        completed: completed,
        aiFeedback: _pendingFeedbackMsg,
      );

      return {
        'session': localSession,
        'ai_feedback': _pendingFeedbackMsg,
        'xp_earned': 0,
        'new_level': false,
        'current_level': 1,
        'new_achievements': <dynamic>[],
        'pending': true,
      };
    }
  }

  /// Obtener una sesión por ID (útil para polling de ai_feedback).
  Future<PracticeSessionModel> getSession(String sessionId) async {
    final response = await _apiClient.dio.get('/practice/sessions/$sessionId');
    return PracticeSessionModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Obtener historial de prácticas, más recientes primero (la 1ª página sin
  /// filtro se cachea offline).
  ///
  /// Sin [lessonId] usa `GET /api/v1/practice/history?page&size`. Con
  /// [lessonId] usa el endpoint legacy, el único que filtra por lección.
  ///
  /// Con [offlineFallback] (por defecto) un fallo de red devuelve lo cacheado o
  /// vacío para no romper la pantalla de Progreso. En `false` el error llega al
  /// llamador (la pantalla de Historial lo muestra en vez de fingir "sin datos").
  Future<Map<String, dynamic>> getPracticeHistory({
    String? lessonId,
    int page = 1,
    int size = 20,
    bool offlineFallback = true,
  }) async {
    final isDefault = lessonId == null && page == 1;
    try {
      final Response<dynamic> response;
      if (lessonId == null) {
        response = await _apiClient.dio.get(
          '/v1/practice/history',
          queryParameters: {'page': page, 'size': size},
        );
      } else {
        response = await _apiClient.dio.get(
          '/practice/history',
          queryParameters: {'page': page, 'limit': size, 'lesson_id': lessonId},
        );
      }
      final data = response.data as Map<String, dynamic>;
      final rawItems = data['items'] as List<dynamic>;
      if (isDefault) {
        await _db?.putSnapshot('practice_history', jsonEncode(rawItems));
      }
      final items = rawItems
          .map((e) => PracticeSessionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return {
        'items': items,
        'total': data['total'],
        'page': data['page'],
        'size': data['size'] ?? size,
        'pages': data['pages'],
      };
    } on DioException {
      if (!offlineFallback) rethrow;
      // Offline: el historial es secundario; devolvemos lo cacheado o vacío
      // para no romper la pantalla de Progreso.
      List<PracticeSessionModel> items = [];
      if (isDefault) {
        final cached = await _db?.getSnapshot('practice_history');
        if (cached != null) {
          items = (jsonDecode(cached) as List<dynamic>)
              .map(
                (e) => PracticeSessionModel.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return {
        'items': items,
        'total': items.length,
        'page': 1,
        'size': size,
        'pages': 1,
      };
    }
  }

  /// Obtener estadísticas de progreso del usuario (cacheadas para offline).
  Future<ProgressStatsModel> getProgressStats() async {
    try {
      final response = await _apiClient.dio.get('/progress/stats');
      final data = response.data as Map<String, dynamic>;
      await _db?.putSnapshot('progress_stats', jsonEncode(data));
      return ProgressStatsModel.fromJson(data);
    } on DioException {
      final cached = await _db?.getSnapshot('progress_stats');
      if (cached != null) {
        return ProgressStatsModel.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
      rethrow;
    }
  }

  /// Obtener desafíos de la semana con el progreso del usuario (cacheado).
  Future<({List<WeeklyChallengeModel> challenges, int daysRemaining})>
  getWeeklyChallenges() async {
    try {
      final response = await _apiClient.dio.get('/challenges/weekly');
      final data = response.data as Map<String, dynamic>;
      await _db?.putSnapshot('weekly_challenges', jsonEncode(data));
      return _mapChallenges(data);
    } on DioException {
      final cached = await _db?.getSnapshot('weekly_challenges');
      if (cached != null) {
        return _mapChallenges(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  ({List<WeeklyChallengeModel> challenges, int daysRemaining}) _mapChallenges(
    Map<String, dynamic> data,
  ) {
    final list = (data['challenges'] as List? ?? [])
        .map((e) => WeeklyChallengeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      challenges: list,
      daysRemaining: data['days_remaining'] as int? ?? 0,
    );
  }

  /// Obtener progreso semanal (cacheado para offline).
  Future<List<WeeklyDataPoint>> getWeeklyProgress() async {
    try {
      final response = await _apiClient.dio.get('/progress/weekly');
      final data = response.data as List<dynamic>;
      await _db?.putSnapshot('progress_weekly', jsonEncode(data));
      return data
          .map((e) => WeeklyDataPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException {
      final cached = await _db?.getSnapshot('progress_weekly');
      if (cached != null) {
        final list = jsonDecode(cached) as List<dynamic>;
        return list
            .map((e) => WeeklyDataPoint.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }
}
