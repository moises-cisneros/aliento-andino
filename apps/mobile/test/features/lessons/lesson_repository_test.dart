import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/features/lessons/data/datasources/local_lesson_datasource.dart';
import 'package:mobile/features/lessons/data/repositories/lesson_repository.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _lesson({
  String id = 'l1',
  String instrument = 'quena',
  String difficulty = 'principiante',
}) => {
  'id': id,
  'category_id': 'c1',
  'title': 'Lección $id',
  'description': 'desc',
  'instrument': instrument,
  'difficulty': difficulty,
};

Map<String, dynamic> _note(int position) => {
  'id': 'n$position',
  'position': position,
  'note': 'A4',
  'duration': 1.0,
};

void main() {
  late FakeAdapter adapter;
  late AppDatabase db;
  late LocalLessonDataSource local;
  late LessonRepository repo;

  setUp(() {
    adapter = FakeAdapter();
    db = AppDatabase(NativeDatabase.memory());
    local = LocalLessonDataSource(db);
    repo = LessonRepository(apiClient: fakeApiClient(adapter), local: local);
  });

  tearDown(() async => db.close());

  group('getLessons', () {
    test(
      'queries by instrument and difficulty and caches the result',
      () async {
        adapter.on('GET /v1/lessons', [_lesson()]);

        final lessons = await repo.getLessons(
          instrument: InstrumentType.quena,
          difficulty: 'principiante',
        );

        expect(lessons.single.id, 'l1');
        expect(adapter.last.queryParameters, {
          'instrument': 'quena',
          'difficulty': 'principiante',
        });
        expect(await local.getLesson('l1'), isNotNull);
      },
    );

    test('ignores an empty difficulty', () async {
      adapter.on('GET /v1/lessons', <dynamic>[]);

      await repo.getLessons(instrument: InstrumentType.tarka, difficulty: '');

      expect(adapter.last.queryParameters, {'instrument': 'tarka'});
    });

    test('offline prefers cached lessons of the same instrument', () async {
      await local.cacheLessons([]);
      adapter.on('GET /v1/lessons', [
        _lesson(id: 'q'),
        _lesson(id: 'z', instrument: 'zampona'),
      ]);
      await repo.getLessons(instrument: InstrumentType.quena);
      adapter.onError('GET /v1/lessons', 503);

      final lessons = await repo.getLessons(instrument: InstrumentType.zampona);

      expect(lessons.map((l) => l.id), ['z']);
    });

    test('offline falls back to all cached when none match', () async {
      adapter.on('GET /v1/lessons', [_lesson(id: 'q')]);
      await repo.getLessons(instrument: InstrumentType.quena);
      adapter.onError('GET /v1/lessons', 503);

      final lessons = await repo.getLessons(instrument: InstrumentType.tarka);

      expect(lessons.map((l) => l.id), ['q']);
    });

    test('offline with an empty cache rethrows', () async {
      adapter.onError('GET /v1/lessons', 503);

      await expectLater(
        repo.getLessons(instrument: InstrumentType.quena),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('getLessonById', () {
    test('caches detail only when notes are present', () async {
      adapter.on('GET /v1/lessons/l1', {
        ..._lesson(),
        'notes': [_note(0), _note(1)],
      });

      expect((await repo.getLessonById('l1')).id, 'l1');
      expect((await local.getNotes('l1')).length, 2);

      adapter.on('GET /v1/lessons/l2', _lesson(id: 'l2'));
      await repo.getLessonById('l2');
      expect(await local.getLesson('l2'), isNull);
    });

    test('offline serves the cached lesson, otherwise rethrows', () async {
      adapter.onError('GET /v1/lessons/l1', 503);
      await expectLater(repo.getLessonById('l1'), throwsA(isA<DioException>()));

      adapter.on('GET /v1/lessons/l1', {
        ..._lesson(),
        'notes': [_note(0)],
      });
      await repo.getLessonById('l1');
      adapter.onError('GET /v1/lessons/l1', 503);
      expect((await repo.getLessonById('l1')).id, 'l1');
    });
  });

  group('getCategories', () {
    final cat = {'id': 'c1', 'name': 'Quena', 'lessons_count': 4};

    test('maps, caches and serves from cache offline', () async {
      adapter.on('GET /lessons/categories', [cat]);
      expect((await repo.getCategories()).single.lessonsCount, 4);

      adapter.onError('GET /lessons/categories', 503);
      expect((await repo.getCategories()).single.name, 'Quena');
    });

    test('offline with empty cache rethrows', () async {
      adapter.onError('GET /lessons/categories', 503);

      await expectLater(repo.getCategories(), throwsA(isA<DioException>()));
    });
  });

  group('getLessonsPaginated', () {
    test('sends only provided filters and returns paging data', () async {
      adapter.on('GET /lessons', {
        'items': [_lesson()],
        'total': 1,
        'page': 1,
        'pages': 1,
      });

      final result = await repo.getLessonsPaginated(
        categoryId: 'c1',
        difficulty: 'principiante',
        search: 'ritmo',
        page: 2,
        limit: 10,
      );

      expect(adapter.last.queryParameters, {
        'page': 2,
        'limit': 10,
        'category_id': 'c1',
        'difficulty': 'principiante',
        'search': 'ritmo',
      });
      expect((result['items'] as List).length, 1);

      await repo.getLessonsPaginated(search: '');
      expect(adapter.last.queryParameters.containsKey('search'), isFalse);
    });

    test(
      'sends instrument filter in queryParameters and filters cache when offline',
      () async {
        adapter.on('GET /lessons', {
          'items': [
            _lesson(id: 'l1', instrument: 'quena'),
            _lesson(id: 'l2', instrument: 'zampona'),
          ],
          'total': 2,
          'page': 1,
          'pages': 1,
        });

        final result = await repo.getLessonsPaginated(instrument: 'quena');
        expect(adapter.last.queryParameters['instrument'], 'quena');
        expect((result['items'] as List).length, 2);

        // Offline fallback
        adapter.onError('GET /lessons', 503);
        final offlineResult = await repo.getLessonsPaginated(
          instrument: 'quena',
        );
        final offlineItems = offlineResult['items'] as List;
        expect(offlineItems.length, 1);
        expect(offlineItems.first.instrument, 'quena');
      },
    );

    test('offline returns the cache or rethrows when empty', () async {
      adapter.onError('GET /lessons', 503);
      await expectLater(
        repo.getLessonsPaginated(),
        throwsA(isA<DioException>()),
      );

      await local.cacheLessons([]);
      adapter.on('GET /lessons', {
        'items': [_lesson()],
        'total': 1,
        'page': 1,
        'pages': 1,
      });
      await repo.getLessonsPaginated();
      adapter.onError('GET /lessons', 503);

      final cached = await repo.getLessonsPaginated(categoryId: 'c1');
      expect(cached['total'], 1);
      expect(cached['pages'], 1);
    });
  });

  group('getLessonDetail', () {
    test('returns lesson, notes and user progress', () async {
      adapter.on('GET /lessons/l1', {
        ..._lesson(),
        'notes': [_note(0)],
        'user_best_score': 91,
        'user_attempts': 3,
      });

      final detail = await repo.getLessonDetail('l1');

      expect(detail['lesson'].id, 'l1');
      expect((detail['notes'] as List).length, 1);
      expect(detail['user_best_score'], 91.0);
      expect(detail['user_attempts'], 3);
    });

    test('without notes defaults and skips the cache', () async {
      adapter.on('GET /lessons/l1', _lesson());

      final detail = await repo.getLessonDetail('l1');

      expect(detail['notes'], isEmpty);
      expect(detail['user_best_score'], isNull);
      expect(detail['user_attempts'], 0);
      expect(await local.getLesson('l1'), isNull);
    });

    test('offline serves cached lesson with notes, else rethrows', () async {
      adapter.onError('GET /lessons/l1', 503);
      await expectLater(
        repo.getLessonDetail('l1'),
        throwsA(isA<DioException>()),
      );

      adapter.on('GET /lessons/l1', {
        ..._lesson(),
        'notes': [_note(0), _note(1)],
      });
      await repo.getLessonDetail('l1');
      adapter.onError('GET /lessons/l1', 503);

      final detail = await repo.getLessonDetail('l1');
      expect((detail['notes'] as List).length, 2);
      expect(detail['user_attempts'], 0);
    });
  });

  group('sequence and recommended', () {
    test('getLessonSequence maps notes and falls back to cache', () async {
      adapter.on('GET /lessons/l1/sequence', [_note(0), _note(1)]);
      expect((await repo.getLessonSequence('l1')).length, 2);

      adapter.onError('GET /lessons/l1/sequence', 503);
      await expectLater(
        repo.getLessonSequence('l1'),
        throwsA(isA<DioException>()),
      );

      adapter.on('GET /v1/lessons/l1', {
        ..._lesson(),
        'notes': [_note(0), _note(1), _note(2)],
      });
      await repo.getLessonById('l1');
      expect((await repo.getLessonSequence('l1')).length, 3);
    });

    test('getRecommended sends the limit and caches', () async {
      adapter.on('GET /lessons/recommended', [_lesson()]);

      expect((await repo.getRecommended(limit: 3)).length, 1);
      expect(adapter.last.queryParameters, {'limit': 3});
    });

    test('getRecommended offline uses downloaded lessons only', () async {
      adapter.onError('GET /lessons/recommended', 503);
      await expectLater(repo.getRecommended(), throwsA(isA<DioException>()));

      adapter.on('GET /v1/lessons/l1', {
        ..._lesson(),
        'notes': [_note(0)],
      });
      final lesson = await repo.getLessonById('l1');
      await local.saveDownload(lesson, []);

      final downloaded = await repo.getRecommended(limit: 1);
      expect(downloaded.single.id, 'l1');
    });
  });

  group('offline downloads', () {
    test('downloads helpers fail clearly without a download service', () {
      expect(() => repo.downloadLesson('l1'), throwsStateError);
      expect(() => repo.deleteDownloadedLesson('l1'), throwsStateError);
      expect(() => repo.getOfflineDownloads(), throwsStateError);
    });

    test('downloaded lessons and flags read from the local source', () async {
      expect(await repo.getDownloadedLessons(), isEmpty);
      expect(await repo.isDownloaded('l1'), isFalse);

      adapter.on('GET /v1/lessons/l1', {
        ..._lesson(),
        'notes': [_note(0)],
      });
      await local.saveDownload(await repo.getLessonById('l1'), []);

      expect(await repo.isDownloaded('l1'), isTrue);
      expect((await repo.getDownloadedLessons()).single.id, 'l1');
    });

    test('without a local source the helpers return empty values', () async {
      final bare = LessonRepository(apiClient: fakeApiClient(adapter));

      expect(await bare.getDownloadedLessons(), isEmpty);
      expect(await bare.isDownloaded('l1'), isFalse);
    });
  });
}
