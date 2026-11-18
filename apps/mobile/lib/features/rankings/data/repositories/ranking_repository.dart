import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/api_client.dart';
import '../models/achievement_model.dart';
import '../models/leaderboard_model.dart';
import '../models/lesson_ranking_model.dart';
import '../models/ranking_entry_model.dart';
import '../models/user_xp_model.dart';

/// Repositorio para operaciones de rankings y logros.
///
/// Los leaderboards y Mi XP se cachean (read-through): si no hay conexión se
/// muestra lo último guardado. La UI avisa que puede estar desactualizado.
class RankingRepository {
  final ApiClient _apiClient;
  final AppDatabase? _db;

  RankingRepository({required ApiClient apiClient, AppDatabase? db})
    : _apiClient = apiClient,
      _db = db;

  // ===================== LEADERBOARDS =====================

  /// Obtener leaderboard global (top 50 por XP total).
  Future<Map<String, dynamic>> getGlobalLeaderboard() async {
    try {
      final response = await _apiClient.dio.get('/rankings/global');
      final data = response.data as Map<String, dynamic>;
      await _db?.putSnapshot('rank_global', jsonEncode(data));
      return _parseGlobal(data);
    } on DioException {
      final cached = await _db?.getSnapshot('rank_global');
      if (cached != null) {
        return _parseGlobal(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  Map<String, dynamic> _parseGlobal(Map<String, dynamic> data) => {
    'leaderboard': (data['leaderboard'] as List)
        .map((e) => RankingEntryModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    'my_rank': data['my_rank'] as int,
    'my_xp': data['my_xp'] as int,
    'my_level': data['my_level'] as int,
  };

  /// Obtener leaderboard de amigos (seguidos + yo, por XP total).
  Future<Map<String, dynamic>> getFriendsLeaderboard() async {
    try {
      final response = await _apiClient.dio.get('/rankings/friends');
      final data = response.data as Map<String, dynamic>;
      await _db?.putSnapshot('rank_friends', jsonEncode(data));
      return _parseGlobal(data);
    } on DioException {
      final cached = await _db?.getSnapshot('rank_friends');
      if (cached != null) {
        return _parseGlobal(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  /// Obtener leaderboard semanal (top 50 por XP semanal).
  Future<Map<String, dynamic>> getWeeklyLeaderboard() async {
    try {
      final response = await _apiClient.dio.get('/rankings/weekly');
      final data = response.data as Map<String, dynamic>;
      await _db?.putSnapshot('rank_weekly', jsonEncode(data));
      return _parseWeekly(data);
    } on DioException {
      final cached = await _db?.getSnapshot('rank_weekly');
      if (cached != null) {
        return _parseWeekly(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  Map<String, dynamic> _parseWeekly(Map<String, dynamic> data) => {
    'leaderboard': (data['leaderboard'] as List)
        .map((e) => RankingEntryModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    'my_rank': data['my_rank'] as int,
    'my_weekly_xp': data['my_weekly_xp'] as int,
    'days_remaining': data['days_remaining'] as int,
  };

  /// Obtener ranking de rachas (top 30).
  Future<Map<String, dynamic>> getStreaksLeaderboard() async {
    try {
      final response = await _apiClient.dio.get('/rankings/streaks');
      final data = response.data as Map<String, dynamic>;
      await _db?.putSnapshot('rank_streaks', jsonEncode(data));
      return _parseStreaks(data);
    } on DioException {
      final cached = await _db?.getSnapshot('rank_streaks');
      if (cached != null) {
        return _parseStreaks(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  Map<String, dynamic> _parseStreaks(Map<String, dynamic> data) => {
    'leaderboard': (data['leaderboard'] as List)
        .map((e) => RankingEntryModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    'my_rank': data['my_rank'] as int? ?? 0,
    'my_streak': data['my_streak'] as int,
    'my_longest': data['my_longest'] as int,
  };

  /// Leaderboard por instrumento andino (`quena` | `zampona` | `tarka`) y
  /// alcance (`weekly` | `all_time`). Cacheado por instrumento+alcance: sin
  /// conexión se muestra el último snapshot de ese mismo instrumento.
  Future<LeaderboardModel> getInstrumentLeaderboard(
    String instrument, {
    String scope = 'weekly',
  }) async {
    final cacheKey = 'rank_lb_${instrument}_$scope';
    try {
      final response = await _apiClient.dio.get(
        '/v1/rankings/leaderboard',
        queryParameters: {'instrument': instrument, 'scope': scope},
      );
      final data = response.data as Map<String, dynamic>;
      await _db?.putSnapshot(cacheKey, jsonEncode(data));
      return LeaderboardModel.fromJson(data);
    } on DioException {
      final cached = await _db?.getSnapshot(cacheKey);
      if (cached != null) {
        return LeaderboardModel.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
      rethrow;
    }
  }

  /// Obtener ranking por lección (top 20). Online-only.
  Future<Map<String, dynamic>> getLessonLeaderboard(String lessonId) async {
    final response = await _apiClient.dio.get('/rankings/lesson/$lessonId');
    final data = response.data as Map<String, dynamic>;
    return {
      'leaderboard': (data['leaderboard'] as List)
          .map((e) => LessonRankingModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      'my_best_score': (data['my_best_score'] as num?)?.toDouble() ?? 0.0,
      'my_rank': data['my_rank'] as int? ?? 0,
    };
  }

  // ===================== MY XP =====================

  /// Obtener datos completos de XP del usuario actual (cacheado offline).
  Future<UserXPModel> getMyXP() async {
    try {
      final response = await _apiClient.dio.get('/rankings/my-xp');
      final data = response.data as Map<String, dynamic>;
      await _db?.putSnapshot('rank_myxp', jsonEncode(data));
      return UserXPModel.fromJson(data);
    } on DioException {
      final cached = await _db?.getSnapshot('rank_myxp');
      if (cached != null) {
        return UserXPModel.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  // ===================== LOGROS =====================

  /// Obtener todos los logros con estado del usuario.
  Future<Map<String, dynamic>> getAllAchievements() async {
    final response = await _apiClient.dio.get('/rankings/achievements');
    final data = response.data as Map<String, dynamic>;
    return {
      'achievements': (data['achievements'] as List)
          .map((e) => AchievementModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      'total_unlocked': data['total_unlocked'] as int,
      'total_available': data['total_available'] as int,
    };
  }

  /// Obtener últimos 5 logros desbloqueados.
  Future<List<AchievementModel>> getRecentAchievements() async {
    final response = await _apiClient.dio.get('/rankings/achievements/recent');
    return (response.data as List)
        .map((e) => AchievementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
