import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/features/lessons/data/repositories/practice_repository.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _session({String id = 's1'}) => {
  'id': id,
  'user_id': 'u1',
  'lesson_id': 'l1',
  'score': 88.5,
  'correct_notes': 9,
  'total_notes': 10,
  'created_at': '2026-11-17T10:00:00Z',
};

Future<Map<String, dynamic>> _submit(
  PracticeRepository repo, {
  String? clientId,
  List<Map<String, dynamic>>? errors,
}) => repo.submitPractice(
  lessonId: 'l1',
  score: 80,
  correctNotes: 8,
  totalNotes: 10,
  wrongNotes: 1,
  missedNotes: 1,
  averageTempo: 70,
  totalTimeSeconds: 30,
  errorsDetail: errors,
  clientId: clientId,
);

void main() {
  late FakeAdapter adapter;
  late AppDatabase db;
  late PracticeRepository repo;

  setUp(() {
    adapter = FakeAdapter();
    db = AppDatabase(NativeDatabase.memory());
    repo = PracticeRepository(apiClient: fakeApiClient(adapter), db: db);
  });

  tearDown(() async => db.close());

  group('submitPractice', () {
    test('posts the body and maps the response', () async {
      adapter.on('POST /practice/submit', {
        'session': _session(),
        'ai_feedback': 'Muy bien',
        'xp_earned': 25,
        'new_level': true,
        'current_level': 3,
        'new_achievements': ['a'],
      });

      final result = await _submit(repo, clientId: 'cid');

      expect(adapter.last.data['client_id'], 'cid');
      expect(adapter.last.data['lesson_id'], 'l1');
      expect(result['pending'], isFalse);
      expect(result['xp_earned'], 25);
      expect(result['new_level'], isTrue);
      expect(result['current_level'], 3);
      expect(result['ai_feedback'], 'Muy bien');
      expect(result['new_achievements'], ['a']);
      expect(result['session'].score, 88.5);
    });

    test(
      'generates a client id and defaults optional response fields',
      () async {
        adapter.on('POST /practice/submit', {'session': _session()});

        final result = await _submit(repo);

        expect(adapter.last.data['client_id'], isNotEmpty);
        expect(result['xp_earned'], 0);
        expect(result['current_level'], 1);
        expect(result['new_achievements'], isEmpty);
      },
    );

    test('a server error is propagated and nothing is queued', () async {
      adapter.onError('POST /practice/submit', 500);

      await expectLater(_submit(repo), throwsA(isA<DioException>()));
      expect(await db.pendingCount(), 0);
    });

    test('without a response the practice is queued as pending', () async {
      adapter.onCall(
        'POST /practice/submit',
        (o) => Future.error(
          DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      final result = await _submit(
        repo,
        clientId: 'offline-1',
        errors: [
          {'note': 'A4'},
        ],
      );

      expect(result['pending'], isTrue);
      expect(result['xp_earned'], 0);
      expect(result['session'].id, 'offline-1');
      expect(result['ai_feedback'], contains('sin conexión'));
      expect(await db.pendingCount(), 1);
    });

    test('offline without a local db still returns a pending result', () async {
      final noDb = PracticeRepository(apiClient: fakeApiClient(adapter));
      adapter.onCall(
        'POST /practice/submit',
        (o) => Future.error(
          DioException(
            requestOptions: o,
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );

      expect((await _submit(noDb))['pending'], isTrue);
    });
  });

  test('getSession fetches a session by id', () async {
    adapter.on('GET /practice/sessions/s1', _session());

    expect((await repo.getSession('s1')).id, 's1');
  });

  group('getPracticeHistory', () {
    final page = {
      'items': [_session()],
      'total': 1,
      'page': 1,
      'pages': 1,
    };

    test('default history uses the v1 endpoint and is cached', () async {
      adapter.on('GET /v1/practice/history', page);

      final result = await repo.getPracticeHistory();

      expect((result['items'] as List).length, 1);
      expect(result['size'], 20);
      expect(adapter.last.queryParameters, {'page': 1, 'size': 20});
      expect(await db.getSnapshot('practice_history'), isNotNull);
    });

    test(
      'filtering by lesson uses the legacy endpoint without caching',
      () async {
        adapter.on('GET /practice/history', {...page, 'size': 5});

        final result = await repo.getPracticeHistory(lessonId: 'l1', size: 5);

        expect(adapter.last.queryParameters['lesson_id'], 'l1');
        expect(adapter.last.queryParameters['limit'], 5);
        expect(result['size'], 5);
        expect(await db.getSnapshot('practice_history'), isNull);
      },
    );

    test('offline returns cache, then empty for non-default queries', () async {
      adapter
        ..onError('GET /v1/practice/history', 503)
        ..onError('GET /practice/history', 503);

      final empty = await repo.getPracticeHistory();
      expect(empty['items'], isEmpty);
      expect(empty['total'], 0);

      await db.putSnapshot('practice_history', jsonEncode([_session()]));
      final cached = await repo.getPracticeHistory();
      expect((cached['items'] as List).length, 1);

      final filtered = await repo.getPracticeHistory(lessonId: 'l1');
      expect(filtered['items'], isEmpty);
    });

    test('rethrows when offlineFallback is disabled', () async {
      adapter.onError('GET /v1/practice/history', 503);

      expect(
        repo.getPracticeHistory(offlineFallback: false),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('progress', () {
    test(
      'getProgressStats caches, serves cache offline, rethrows empty',
      () async {
        adapter.on('GET /progress/stats', {
          'total_sessions': 4,
          'current_streak': 2,
          'favorite_category': 'Quena',
        });
        expect((await repo.getProgressStats()).totalSessions, 4);

        adapter.onError('GET /progress/stats', 503);
        expect((await repo.getProgressStats()).currentStreak, 2);

        final fresh = PracticeRepository(
          apiClient: fakeApiClient(adapter),
          db: AppDatabase(NativeDatabase.memory()),
        );
        await expectLater(
          fresh.getProgressStats(),
          throwsA(isA<DioException>()),
        );
      },
    );

    test(
      'getWeeklyChallenges maps challenges and falls back to cache',
      () async {
        adapter.on('GET /challenges/weekly', {
          'challenges': [
            {'key': 'k', 'title': 'Reto', 'target': 5, 'progress': 2},
          ],
          'days_remaining': 3,
        });
        final live = await repo.getWeeklyChallenges();
        expect(live.challenges.single.title, 'Reto');
        expect(live.daysRemaining, 3);

        adapter.onError('GET /challenges/weekly', 503);
        expect((await repo.getWeeklyChallenges()).daysRemaining, 3);

        final fresh = PracticeRepository(
          apiClient: fakeApiClient(adapter),
          db: AppDatabase(NativeDatabase.memory()),
        );
        await expectLater(
          fresh.getWeeklyChallenges(),
          throwsA(isA<DioException>()),
        );
      },
    );

    test('challenges tolerate a payload without fields', () async {
      adapter.on('GET /challenges/weekly', <String, dynamic>{});

      final result = await repo.getWeeklyChallenges();

      expect(result.challenges, isEmpty);
      expect(result.daysRemaining, 0);
    });

    test('getWeeklyProgress maps points and falls back to cache', () async {
      adapter.on('GET /progress/weekly', [
        {'date': '2026-11-16', 'sessions_count': 2, 'average_score': 75},
      ]);
      expect((await repo.getWeeklyProgress()).single.sessionsCount, 2);

      adapter.onError('GET /progress/weekly', 503);
      expect((await repo.getWeeklyProgress()).single.date, '2026-11-16');

      final fresh = PracticeRepository(
        apiClient: fakeApiClient(adapter),
        db: AppDatabase(NativeDatabase.memory()),
      );
      await expectLater(
        fresh.getWeeklyProgress(),
        throwsA(isA<DioException>()),
      );
    });
  });
}
