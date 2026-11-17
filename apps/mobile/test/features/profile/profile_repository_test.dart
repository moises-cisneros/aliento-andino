import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/features/profile/data/repositories/profile_repository.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _me() => {
  'id': 'u1',
  'email': 'ana@test.dev',
  'username': 'ana',
  'full_name': 'Ana Quena',
  'bio': 'Quenista',
  'skill_level': 'beginner',
  'preferred_instruments': ['quena', 'tarka'],
  'breath_sensitivity_rms': 0.04,
  'created_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> _xp() => {'total_xp': 120, 'level': 2};

List<Map<String, dynamic>> _achievements() => [
  {'id': 'a1', 'code': 'first', 'name': 'Primera nota'},
];

void main() {
  late FakeAdapter adapter;
  late AppDatabase db;
  late ProfileRepository repo;

  void routeProfile() {
    adapter
      ..on('GET /auth/me', _me())
      ..on('GET /rankings/my-xp', _xp())
      ..on('GET /rankings/achievements/recent', _achievements());
  }

  setUp(() {
    adapter = FakeAdapter();
    db = AppDatabase(NativeDatabase.memory());
    repo = ProfileRepository(apiClient: fakeApiClient(adapter), db: db);
  });

  tearDown(() async => db.close());

  group('getMyProfile', () {
    test('combines the three endpoints and caches them', () async {
      routeProfile();

      final profile = await repo.getMyProfile();

      final user = profile['user'];
      expect(user.username, 'ana');
      expect(user.preferredInstruments, ['quena', 'tarka']);
      expect(user.breathSensitivityRms, 0.04);
      expect(profile['xp_data'].totalXp, 120);
      expect((profile['recent_achievements'] as List).single.code, 'first');
      expect(await db.getSnapshot('profile_me'), isNotNull);
      expect(await db.getSnapshot('profile_xp'), isNotNull);
      expect(await db.getSnapshot('profile_achievements'), isNotNull);
    });

    test('falls back to the cached snapshots when offline', () async {
      routeProfile();
      await repo.getMyProfile();
      adapter.onError('GET /auth/me', 503);

      final profile = await repo.getMyProfile();

      expect(profile['user'].email, 'ana@test.dev');
    });

    test('rethrows when offline with an incomplete cache', () async {
      adapter
        ..onError('GET /auth/me', 503)
        ..onError('GET /rankings/my-xp', 503)
        ..onError('GET /rankings/achievements/recent', 503);
      await db.putSnapshot('profile_me', jsonEncode(_me()));

      await expectLater(repo.getMyProfile(), throwsA(isA<DioException>()));
    });

    test('applies defaults for sparse user payloads', () async {
      adapter
        ..on('GET /auth/me', <String, dynamic>{})
        ..on('GET /rankings/my-xp', <String, dynamic>{})
        ..on('GET /rankings/achievements/recent', <dynamic>[]);

      final user = (await repo.getMyProfile())['user'];

      expect(user.isActive, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.authProvider, 'local');
      expect(user.preferredInstruments, isEmpty);
    });
  });

  group('getSocialProfile', () {
    final social = {
      'id': 'u1',
      'username': 'ana',
      'followers_count': 3,
      'created_at': '2026-01-01',
    };

    test('returns and caches the profile', () async {
      adapter.on('GET /users/u1/profile', social);

      final profile = await repo.getSocialProfile('u1');

      expect(profile.followersCount, 3);
      expect(await db.getSnapshot('social_profile_u1'), isNotNull);
    });

    test('serves the cache offline and rethrows without it', () async {
      adapter.onError('GET /users/u1/profile', 503);
      await expectLater(
        repo.getSocialProfile('u1'),
        throwsA(isA<DioException>()),
      );

      await db.putSnapshot('social_profile_u1', jsonEncode(social));
      expect((await repo.getSocialProfile('u1')).followersCount, 3);
    });
  });

  group('updateProfile', () {
    test('sends only the provided fields and caches the answer', () async {
      adapter.on('PUT /v1/users/me', {..._me(), 'full_name': 'Ana M.'});

      final user = await repo.updateProfile(
        fullName: 'Ana M.',
        username: 'ana',
        bio: 'hola',
        avatarUrl: 'http://a/x.png',
        preferredInstruments: ['quena'],
        breathSensitivityRms: 0.05,
      );

      expect(user.fullName, 'Ana M.');
      expect(adapter.last.data, {
        'full_name': 'Ana M.',
        'username': 'ana',
        'bio': 'hola',
        'avatar_url': 'http://a/x.png',
        'preferred_instruments': ['quena'],
        'breath_sensitivity_rms': 0.05,
      });
      expect(await db.getSnapshot('profile_me'), contains('Ana M.'));
    });

    test('omits null fields from the request body', () async {
      adapter.on('PUT /v1/users/me', _me());

      await repo.updateProfile(bio: 'solo bio');

      expect(adapter.last.data, {'bio': 'solo bio'});
    });

    test('offline: queues the update and merges it into the cache', () async {
      await db.putSnapshot('profile_me', jsonEncode(_me()));
      adapter.onError('PUT /v1/users/me', 503);

      final user = await repo.updateProfile(bio: 'offline bio');

      expect(user.bio, 'offline bio');
      expect(user.username, 'ana');
      expect(
        await db.getSnapshot('pending_profile_update'),
        contains('offline'),
      );
      expect(await db.getSnapshot('profile_me'), contains('offline bio'));
    });

    test('offline without cache builds the user from the body', () async {
      adapter.onError('PUT /v1/users/me', 503);

      final user = await repo.updateProfile(username: 'nuevo');

      expect(user.username, 'nuevo');
    });
  });

  group('getMyPosts', () {
    test('caches the first page only', () async {
      adapter.on('GET /users/u1/posts', pageJson([postJson()]));

      final first = await repo.getMyPosts('u1');
      expect((first['items'] as List).length, 1);
      expect(await db.getSnapshot('my_posts_u1'), isNotNull);

      await db.putSnapshot('my_posts_u1', '[]');
      await repo.getMyPosts('u1', cursor: 'c');
      expect(adapter.last.queryParameters['cursor'], 'c');
      expect(await db.getSnapshot('my_posts_u1'), '[]');
    });

    test('offline returns cached posts, or empty without a cache', () async {
      adapter.onError('GET /users/u1/posts', 503);

      final empty = await repo.getMyPosts('u1');
      expect(empty['items'], isEmpty);
      expect(empty['has_more'], isFalse);

      await db.putSnapshot('my_posts_u1', jsonEncode([postJson()]));
      final cached = await repo.getMyPosts('u1');
      expect((cached['items'] as List).length, 1);

      final paged = await repo.getMyPosts('u1', cursor: 'c');
      expect(paged['items'], isEmpty);
    });
  });
}
