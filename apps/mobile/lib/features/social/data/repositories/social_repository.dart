import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/api_client.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../models/reaction_toggle_model.dart';

/// Repositorio de red social: posts, likes, comentarios, reportes.
class SocialRepository {
  final ApiClient _apiClient;
  final AppDatabase? _db;

  const SocialRepository({required ApiClient apiClient, AppDatabase? db})
    : _apiClient = apiClient,
      _db = db;

  /// Obtener feed del usuario (cursor-based). La 1ª página se cachea offline.
  Future<Map<String, dynamic>> getFeed({String? cursor, int limit = 20}) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (cursor != null) params['cursor'] = cursor;

      final response = await _apiClient.dio.get(
        '/feed',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final rawItems = data['items'] as List<dynamic>;
      if (cursor == null) {
        await _db?.putSnapshot('feed', jsonEncode(rawItems));
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
      // Offline: devolver el último feed guardado (solo 1ª página).
      if (cursor == null) {
        final cached = await _db?.getSnapshot('feed');
        if (cached != null) {
          final items = (jsonDecode(cached) as List<dynamic>)
              .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
              .toList();
          return {'items': items, 'next_cursor': null, 'has_more': false};
        }
      }
      rethrow;
    }
  }

  /// Feed cronológico global (todos los posts, sin filtro de seguidos).
  Future<Map<String, dynamic>> getRecentFeed({
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _apiClient.dio.get(
      '/feed/recent',
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

  /// Feed de posts de un hashtag (cursor-based).
  Future<Map<String, dynamic>> getHashtagFeed(
    String tag, {
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _apiClient.dio.get(
      '/hashtags/$tag/feed',
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

  /// Obtener posts populares (explore).
  Future<Map<String, dynamic>> getExplore({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '/feed/explore',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return {
      'items': items,
      'total': data['total'],
      'page': data['page'],
      'pages': data['pages'],
    };
  }

  /// Buscar posts por texto/hashtag.
  Future<List<PostModel>> searchPosts(String query, {int limit = 20}) async {
    final response = await _apiClient.dio.get(
      '/posts/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crear publicación.
  Future<PostModel> createPost({
    required String content,
    String postType = 'text',
    String? mediaUrl,
    String? practiceSessionId,
  }) async {
    final body = <String, dynamic>{'content': content, 'post_type': postType};
    if (mediaUrl != null) body['media_url'] = mediaUrl;
    if (practiceSessionId != null) {
      body['practice_session_id'] = practiceSessionId;
    }

    final response = await _apiClient.dio.post('/posts', data: body);
    return PostModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Obtener detalle de un post.
  Future<PostModel> getPostDetail(String postId) async {
    final response = await _apiClient.dio.get('/posts/$postId');
    return PostModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Editar el contenido de un post (solo el autor).
  Future<PostModel> updatePost(String postId, String content) async {
    final response = await _apiClient.dio.put(
      '/posts/$postId',
      data: {'content': content},
    );
    return PostModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Eliminar un post.
  Future<void> deletePost(String postId) async {
    await _apiClient.dio.delete('/posts/$postId');
  }

  /// Alterna el aplauso (reacción) vía `POST /posts/{id}/react` (contrato #41).
  Future<ReactionToggleModel> reactToPost(String postId) async {
    final response = await _apiClient.dio.post('/posts/$postId/react');
    return ReactionToggleModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Toggle like en un post.
  Future<Map<String, dynamic>> toggleLike(String postId) async {
    final response = await _apiClient.dio.post('/posts/$postId/like');
    return response.data as Map<String, dynamic>;
  }

  /// Toggle guardar/bookmark un post. Devuelve {'saved': bool}.
  Future<bool> toggleSave(String postId) async {
    final response = await _apiClient.dio.post('/posts/$postId/save');
    final data = response.data as Map<String, dynamic>;
    return data['saved'] as bool? ?? false;
  }

  /// Feed de posts guardados por el usuario (cursor-based).
  Future<Map<String, dynamic>> getSavedFeed({
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _apiClient.dio.get(
      '/me/saved',
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

  /// Obtener comentarios de un post.
  Future<Map<String, dynamic>> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '/posts/$postId/comments',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return {
      'items': items,
      'total': data['total'],
      'page': data['page'],
      'pages': data['pages'],
    };
  }

  /// Crear comentario o reply (si parentCommentId está presente).
  Future<CommentModel> createComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (parentCommentId != null) {
      body['parent_comment_id'] = parentCommentId;
    }
    final response = await _apiClient.dio.post(
      '/posts/$postId/comments',
      data: body,
    );
    return CommentModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Obtener replies de un comentario.
  Future<List<CommentModel>> getReplies(
    String commentId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '/comments/$commentId/replies',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Toggle like en un comentario. Devuelve {'liked': bool, 'likes_count': int}.
  Future<Map<String, dynamic>> toggleCommentLike(String commentId) async {
    final response = await _apiClient.dio.post('/comments/$commentId/like');
    return response.data as Map<String, dynamic>;
  }

  /// Editar el contenido de un comentario (solo el autor).
  Future<CommentModel> updateComment(String commentId, String content) async {
    final response = await _apiClient.dio.put(
      '/comments/$commentId',
      data: {'content': content},
    );
    return CommentModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Eliminar comentario.
  Future<void> deleteComment(String postId, String commentId) async {
    await _apiClient.dio.delete('/posts/$postId/comments/$commentId');
  }

  /// Reportar contenido.
  Future<void> createReport({
    String? postId,
    String? commentId,
    String? reportedUserId,
    required String reason,
    String? description,
  }) async {
    final body = <String, dynamic>{'reason': reason};
    if (postId != null) body['post_id'] = postId;
    if (commentId != null) body['comment_id'] = commentId;
    if (reportedUserId != null) body['reported_user_id'] = reportedUserId;
    if (description != null) body['description'] = description;

    await _apiClient.dio.post('/reports', data: body);
  }
}
