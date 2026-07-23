import '../../../../core/network/api_client.dart';
import '../models/user_profile_model.dart';
import '../models/user_summary_model.dart';
import '../models/post_model.dart';

/// Repositorio de usuarios: perfiles, follows, búsqueda.
class UserRepository {
  final ApiClient _apiClient;

  const UserRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Obtener perfil público de un usuario.
  Future<UserProfileModel> getUserProfile(String userId) async {
    final response = await _apiClient.dio.get('/users/$userId/profile');
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Resolver un username (de una @mención) a su id, para abrir el perfil.
  Future<String> getUserIdByUsername(String username) async {
    final response = await _apiClient.dio.get('/users/by-username/$username');
    return (response.data as Map<String, dynamic>)['id'] as String;
  }

  /// Obtener posts de un usuario (cursor-based).
  Future<Map<String, dynamic>> getUserPosts(
    String userId, {
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _apiClient.dio.get(
      '/users/$userId/posts',
      queryParameters: params,
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return {
      'items': items,
      'next_cursor': data['next_cursor'],
      'has_more': data['has_more'] ?? false,
    };
  }

  /// Toggle follow/unfollow.
  Future<Map<String, dynamic>> toggleFollow(String userId) async {
    final response = await _apiClient.dio.post('/users/$userId/follow');
    return response.data as Map<String, dynamic>;
  }

  /// Posts con media de un usuario (pestaña Media).
  Future<Map<String, dynamic>> getUserMedia(
    String userId, {
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;
    final response = await _apiClient.dio.get(
      '/users/$userId/media',
      queryParameters: params,
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return {
      'items': items,
      'next_cursor': data['next_cursor'],
      'has_more': data['has_more'] ?? false,
    };
  }

  /// Usuarios sugeridos para seguir.
  Future<List<UserSummaryModel>> getSuggestions({int limit = 10}) async {
    final response = await _apiClient.dio.get(
      '/users/suggestions',
      queryParameters: {'limit': limit},
    );
    return (response.data as List<dynamic>)
        .map((e) => UserSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtener seguidores.
  Future<Map<String, dynamic>> getFollowers(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '/users/$userId/followers',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((e) => UserSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return {
      'items': items,
      'total': data['total'],
      'page': data['page'],
      'pages': data['pages'],
    };
  }

  /// Obtener usuarios que sigue.
  Future<Map<String, dynamic>> getFollowing(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '/users/$userId/following',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((e) => UserSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return {
      'items': items,
      'total': data['total'],
      'page': data['page'],
      'pages': data['pages'],
    };
  }

  /// Buscar usuarios por nombre o username.
  Future<Map<String, dynamic>> searchUsers(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '/users/search',
      queryParameters: {'q': query, 'page': page, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((e) => UserSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return {
      'items': items,
      'total': data['total'],
      'page': data['page'],
      'pages': data['pages'],
    };
  }
}
