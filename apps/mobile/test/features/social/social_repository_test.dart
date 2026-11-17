import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/features/social/data/repositories/social_repository.dart';

import '../../helpers/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late AppDatabase db;
  late SocialRepository repo;

  setUp(() {
    adapter = FakeAdapter();
    db = AppDatabase(NativeDatabase.memory());
    repo = SocialRepository(apiClient: fakeApiClient(adapter), db: db);
  });

  tearDown(() async => db.close());

  group('feeds', () {
    test('getFeed parses items and caches the first page', () async {
      adapter.on('GET /feed', pageJson([postJson()]));

      final result = await repo.getFeed();

      expect((result['items'] as List).length, 1);
      expect(result['next_cursor'], 'next');
      expect(result['has_more'], isTrue);
      expect(adapter.last.queryParameters, {'limit': 20});
      expect(await db.getSnapshot('feed'), isNotNull);
    });

    test('getFeed with cursor sends it and does not overwrite cache', () async {
      adapter.on('GET /feed', pageJson([postJson()]));

      await repo.getFeed(cursor: 'abc', limit: 5);

      expect(adapter.last.queryParameters, {'limit': 5, 'cursor': 'abc'});
      expect(await db.getSnapshot('feed'), isNull);
    });

    test('getFeed serves the cached first page when offline', () async {
      await db.putSnapshot('feed', jsonEncode([postJson(id: 'cached')]));
      adapter.onError('GET /feed', 503);

      final result = await repo.getFeed();

      expect((result['items'] as List).single.id, 'cached');
      expect(result['has_more'], isFalse);
      expect(result['next_cursor'], isNull);
    });

    test('getFeed rethrows when offline without cache', () async {
      adapter.onError('GET /feed', 503);

      await expectLater(repo.getFeed(), throwsA(isA<DioException>()));
    });

    test('getFeed rethrows on a paginated request even with cache', () async {
      await db.putSnapshot('feed', jsonEncode([postJson()]));
      adapter.onError('GET /feed', 503);

      await expectLater(
        repo.getFeed(cursor: 'x'),
        throwsA(isA<DioException>()),
      );
    });

    test(
      'getRecentFeed, getHashtagFeed and getSavedFeed parse pages',
      () async {
        adapter
          ..on('GET /feed/recent', pageJson([postJson()]))
          ..on('GET /hashtags/quena/feed', pageJson([postJson(), postJson()]))
          ..on('GET /me/saved', pageJson([postJson()]));

        final recent = await repo.getRecentFeed(cursor: 'c');
        final tag = await repo.getHashtagFeed('quena', cursor: 'c');
        final saved = await repo.getSavedFeed(cursor: 'c');

        expect((recent['items'] as List).length, 1);
        expect((tag['items'] as List).length, 2);
        expect((saved['items'] as List).length, 1);
        expect(tag['has_more'], isTrue);
      },
    );

    test('has_more defaults to false when absent', () async {
      adapter.on('GET /feed/recent', {'items': <dynamic>[]});

      final result = await repo.getRecentFeed();

      expect(result['has_more'], isFalse);
    });

    test('getExplore returns pagination metadata', () async {
      adapter.on('GET /feed/explore', pageJson([postJson()]));

      final result = await repo.getExplore(page: 2, limit: 10);

      expect(result['total'], 1);
      expect(result['pages'], 1);
      expect(adapter.last.queryParameters, {'page': 2, 'limit': 10});
    });

    test('searchPosts sends the query', () async {
      adapter.on('GET /posts/search', pageJson([postJson()]));

      final posts = await repo.searchPosts('quena');

      expect(posts.single.content, 'Practicando quena');
      expect(adapter.last.queryParameters['q'], 'quena');
    });
  });

  group('posts', () {
    test('createPost sends optional fields only when present', () async {
      adapter.on('POST /posts', postJson());

      await repo.createPost(content: 'hola');
      expect(adapter.last.data, {'content': 'hola', 'post_type': 'text'});

      await repo.createPost(
        content: 'hola',
        postType: 'practice',
        mediaUrl: 'http://m/x.jpg',
        practiceSessionId: 's1',
      );
      expect(adapter.last.data, {
        'content': 'hola',
        'post_type': 'practice',
        'media_url': 'http://m/x.jpg',
        'practice_session_id': 's1',
      });
    });

    test(
      'getPostDetail, updatePost, deletePost hit the post resource',
      () async {
        adapter
          ..on('GET /posts/p1', postJson())
          ..on('PUT /posts/p1', postJson())
          ..on('DELETE /posts/p1', null, status: 204);

        expect((await repo.getPostDetail('p1')).id, 'p1');
        expect((await repo.updatePost('p1', 'nuevo')).id, 'p1');
        expect(adapter.requests[1].data, {'content': 'nuevo'});
        await repo.deletePost('p1');
        expect(adapter.last.method, 'DELETE');
      },
    );

    test('toggleLike returns the server payload', () async {
      adapter.on('POST /posts/p1/like', {'liked': true, 'likes_count': 3});

      final result = await repo.toggleLike('p1');

      expect(result['liked'], isTrue);
      expect(result['likes_count'], 3);
    });

    test('toggleSave returns the saved flag and defaults to false', () async {
      adapter.on('POST /posts/p1/save', {'saved': true});
      expect(await repo.toggleSave('p1'), isTrue);

      adapter.on('POST /posts/p2/save', <String, dynamic>{});
      expect(await repo.toggleSave('p2'), isFalse);
    });
  });

  group('comments', () {
    test('getComments parses items with pagination', () async {
      adapter.on('GET /posts/p1/comments', pageJson([commentJson()]));

      final result = await repo.getComments('p1');

      expect((result['items'] as List).single.content, 'Bravo');
      expect(result['pages'], 1);
    });

    test('createComment includes parent id only for replies', () async {
      adapter.on('POST /posts/p1/comments', commentJson());

      await repo.createComment('p1', 'hola');
      expect(adapter.last.data, {'content': 'hola'});

      await repo.createComment('p1', 'hola', parentCommentId: 'c9');
      expect(adapter.last.data, {'content': 'hola', 'parent_comment_id': 'c9'});
    });

    test(
      'getReplies, updateComment, toggleCommentLike, deleteComment',
      () async {
        adapter
          ..on('GET /comments/c1/replies', pageJson([commentJson()]))
          ..on('PUT /comments/c1', commentJson())
          ..on('POST /comments/c1/like', {'liked': true, 'likes_count': 1})
          ..on('DELETE /posts/p1/comments/c1', null, status: 204);

        expect((await repo.getReplies('c1')).length, 1);
        expect((await repo.updateComment('c1', 'editado')).id, 'c1');
        expect((await repo.toggleCommentLike('c1'))['liked'], isTrue);
        await repo.deleteComment('p1', 'c1');
        expect(adapter.last.path, '/posts/p1/comments/c1');
      },
    );
  });

  group('reports', () {
    test('createReport sends only the provided targets', () async {
      adapter.on('POST /reports', {'ok': true}, status: 201);

      await repo.createReport(reason: 'spam');
      expect(adapter.last.data, {'reason': 'spam'});

      await repo.createReport(
        postId: 'p1',
        commentId: 'c1',
        reportedUserId: 'u1',
        reason: 'spam',
        description: 'detalle',
      );
      expect(adapter.last.data, {
        'reason': 'spam',
        'post_id': 'p1',
        'comment_id': 'c1',
        'reported_user_id': 'u1',
        'description': 'detalle',
      });
    });
  });

  test('works without a local database', () async {
    final noDb = SocialRepository(apiClient: fakeApiClient(adapter));
    adapter.on('GET /feed', pageJson([postJson()]));

    expect(((await noDb.getFeed())['items'] as List).length, 1);

    adapter.onError('GET /feed', 503);
    await expectLater(noDb.getFeed(), throwsA(isA<DioException>()));
  });
}
