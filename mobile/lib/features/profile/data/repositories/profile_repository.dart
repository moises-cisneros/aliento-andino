import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../rankings/data/models/achievement_model.dart';
import '../../../rankings/data/models/user_xp_model.dart';
import '../../../social/data/models/post_model.dart';
import '../../../social/data/models/user_profile_model.dart';

/// Repositorio de perfil: combina datos de múltiples endpoints.
class ProfileRepository {
  final ApiClient _apiClient;
  final AppDatabase? _db;

  const ProfileRepository({required ApiClient apiClient, AppDatabase? db})
    : _apiClient = apiClient,
      _db = db;

  /// Carga datos completos del perfil propio en paralelo (cacheado para offline).
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final results = await Future.wait([
        _apiClient.dio.get('/auth/me'),
        _apiClient.dio.get('/rankings/my-xp'),
        _apiClient.dio.get('/rankings/achievements/recent'),
      ]);

      final userData = results[0].data as Map<String, dynamic>;
      final xpData = results[1].data as Map<String, dynamic>;
      final achievementsRaw = results[2].data as List<dynamic>;

      await _db?.putSnapshot('profile_me', jsonEncode(userData));
      await _db?.putSnapshot('profile_xp', jsonEncode(xpData));
      await _db?.putSnapshot('profile_achievements', jsonEncode(achievementsRaw));

      return _buildProfile(userData, xpData, achievementsRaw);
    } on DioException {
      final me = await _db?.getSnapshot('profile_me');
      final xp = await _db?.getSnapshot('profile_xp');
      final ach = await _db?.getSnapshot('profile_achievements');
      if (me != null && xp != null && ach != null) {
        return _buildProfile(
          jsonDecode(me) as Map<String, dynamic>,
          jsonDecode(xp) as Map<String, dynamic>,
          jsonDecode(ach) as List<dynamic>,
        );
      }
      rethrow;
    }
  }

  Map<String, dynamic> _buildProfile(
    Map<String, dynamic> userData,
    Map<String, dynamic> xpData,
    List<dynamic> achievementsRaw,
  ) {
    final user = UserEntity(
      id: (userData['id'] as String?) ?? '',
      email: (userData['email'] as String?) ?? '',
      username: (userData['username'] as String?) ?? '',
      fullName: (userData['full_name'] as String?) ?? '',
      avatarUrl: userData['avatar_url'] as String?,
      bio: userData['bio'] as String?,
      isActive: userData['is_active'] as bool? ?? true,
      isAdmin: userData['is_admin'] as bool? ?? false,
      isVerified: userData['is_verified'] as bool? ?? false,
      authProvider: (userData['auth_provider'] as String?) ?? 'local',
      createdAt: (userData['created_at'] as String?) ?? '',
      updatedAt: userData['updated_at'] as String?,
    );

    final achievements = achievementsRaw
        .map((e) => AchievementModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return {
      'user': user,
      'xp_data': UserXPModel.fromJson(xpData),
      'recent_achievements': achievements,
    };
  }

  /// Obtener perfil social (contadores) del usuario actual (cacheado offline).
  Future<UserProfileModel> getSocialProfile(String userId) async {
    try {
      final response = await _apiClient.dio.get('/users/$userId/profile');
      final data = response.data as Map<String, dynamic>;
      await _db?.putSnapshot('social_profile_$userId', jsonEncode(data));
      return UserProfileModel.fromJson(data);
    } on DioException {
      final cached = await _db?.getSnapshot('social_profile_$userId');
      if (cached != null) {
        return UserProfileModel.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
      rethrow;
    }
  }

  /// Actualizar perfil del usuario.
  Future<UserEntity> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (username != null) body['username'] = username;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;

    final response = await _apiClient.dio.put('/auth/me', data: body);
    final data = response.data as Map<String, dynamic>;
    return UserEntity(
      id: (data['id'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      username: (data['username'] as String?) ?? '',
      fullName: (data['full_name'] as String?) ?? '',
      avatarUrl: data['avatar_url'] as String?,
      bio: data['bio'] as String?,
      isActive: data['is_active'] as bool? ?? true,
      isAdmin: data['is_admin'] as bool? ?? false,
      isVerified: data['is_verified'] as bool? ?? false,
      authProvider: (data['auth_provider'] as String?) ?? 'local',
      createdAt: (data['created_at'] as String?) ?? '',
      updatedAt: data['updated_at'] as String?,
    );
  }

  /// Obtener posts propios con cursor pagination.
  Future<Map<String, dynamic>> getMyPosts(
    String userId, {
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (cursor != null) params['cursor'] = cursor;

      final response = await _apiClient.dio.get(
        '/users/$userId/posts',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final rawItems = data['items'] as List<dynamic>;
      // Solo cacheamos la 1ª página (cursor null).
      if (cursor == null) {
        await _db?.putSnapshot('my_posts_$userId', jsonEncode(rawItems));
      }
      final items = rawItems
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return {
        'items': items,
        'next_cursor': data['next_cursor'],
        'has_more': data['has_more'] ?? false,
      };
    } on DioException {
      // Offline: los posts son secundarios para ver el perfil → cache o vacío.
      List<PostModel> items = [];
      if (cursor == null) {
        final cached = await _db?.getSnapshot('my_posts_$userId');
        if (cached != null) {
          items = (jsonDecode(cached) as List<dynamic>)
              .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return {'items': items, 'next_cursor': null, 'has_more': false};
    }
  }
}
