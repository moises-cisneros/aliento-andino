import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/core/database/daos/offline_lessons_dao.dart';
import 'package:mobile/features/lessons/data/services/lesson_download_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Future<ResponseBody> Function(RequestOptions options) handler;

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _audioUrl = 'http://cdn.test/audio/quena-1.mp3';

Map<String, dynamic> _lessonJson({
  String? audioUrl = _audioUrl,
  bool withNotes = true,
}) => {
  'id': 'lesson-1',
  'category_id': 'cat-1',
  'title': 'Huayno basico',
  'instrument': 'tarka',
  'difficulty': 'principiante',
  'tempo_bpm': 80,
  'audio_preview_url': audioUrl,
  if (withNotes)
    'notes': [
      {'position': 0, 'note': 'D4', 'duration': 1.0},
      {'position': 1, 'note': 'E4', 'duration': 0.5},
    ],
};

void main() {
  late AppDatabase db;
  late Directory dir;
  late _FakeAdapter api;
  late _FakeAdapter audio;
  late LessonDownloadService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('lesson_download_test');
    api = _FakeAdapter((_) async => _json(_lessonJson()));
    audio = _FakeAdapter(
      (_) async => ResponseBody.fromBytes([1, 2, 3, 4], 200),
    );
    service = LessonDownloadService(
      api: Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = api,
      audioClient: Dio()..httpClientAdapter = audio,
      db: db,
      audioDirectory: () async => dir,
    );
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  group('OfflineLessonsDao', () {
    test('inserts and queries an offline lesson', () async {
      final dao = OfflineLessonsDao(db);
      expect(await dao.isDownloaded('l1'), isFalse);

      final when = DateTime(2026, 11, 17, 10);
      await dao.saveDownload(
        lesson: CachedLessonsCompanion.insert(
          id: 'l1',
          categoryId: 'c1',
          title: 'Sikuri',
          difficulty: 'intermedio',
          instrument: const Value('zampona'),
        ),
        notes: [
          CachedNotesCompanion.insert(
            lessonId: 'l1',
            position: 0,
            note: 'G4',
            duration: 1,
          ),
        ],
        localAudioPath: '/data/audio.mp3',
        downloadedAt: when,
      );

      expect(await dao.isDownloaded('l1'), isTrue);
      final lesson = (await dao.getOfflineLesson('l1'))!;
      expect(lesson.title, 'Sikuri');
      expect(lesson.instrument, 'zampona');
      expect(lesson.localAudioPath, '/data/audio.mp3');
      expect(lesson.downloadedAt, when);
      final notes = jsonDecode(lesson.notesJson) as List;
      expect(notes, hasLength(1));
      expect((notes.single as Map)['note'], 'G4');
      expect(await dao.listOfflineLessons(), hasLength(1));
    });

    test(
      'a lesson that is only cached (not downloaded) is not offline',
      () async {
        await db.upsertLessons([
          CachedLessonsCompanion.insert(
            id: 'l2',
            categoryId: 'c1',
            title: 'Solo cache',
            difficulty: 'principiante',
          ),
        ]);
        final dao = OfflineLessonsDao(db);

        expect(await dao.isDownloaded('l2'), isFalse);
        expect(await dao.getOfflineLesson('l2'), isNull);
        expect(await dao.listOfflineLessons(), isEmpty);
      },
    );
  });

  group('LessonDownloadService', () {
    test(
      'downloads notes and audio and marks the lesson as downloaded',
      () async {
        await service.downloadLesson('lesson-1');

        expect(await service.isLessonDownloaded('lesson-1'), isTrue);
        expect(service.statusOf('lesson-1').value, DownloadStatus.downloaded);
        final offline = (await OfflineLessonsDao(
          db,
        ).getOfflineLesson('lesson-1'))!;
        expect(offline.instrument, 'tarka');
        expect(jsonDecode(offline.notesJson) as List, hasLength(2));
        final file = File(offline.localAudioPath!);
        expect(file.existsSync(), isTrue);
        expect(file.readAsBytesSync(), [1, 2, 3, 4]);
        expect(File('${file.path}.part').existsSync(), isFalse);
      },
    );

    test(
      'falls back to the sequence endpoint when detail has no notes',
      () async {
        api.handler = (o) async => o.path.endsWith('/sequence')
            ? _json([
                {'position': 0, 'note': 'A4', 'duration': 1.0},
              ])
            : _json(_lessonJson(withNotes: false));

        await service.downloadLesson('lesson-1');

        final offline = (await OfflineLessonsDao(
          db,
        ).getOfflineLesson('lesson-1'))!;
        expect(jsonDecode(offline.notesJson) as List, hasLength(1));
      },
    );

    test('a lesson without audio is downloaded with no audio path', () async {
      api.handler = (_) async => _json(_lessonJson(audioUrl: null));

      await service.downloadLesson('lesson-1');

      final offline = (await OfflineLessonsDao(
        db,
      ).getOfflineLesson('lesson-1'))!;
      expect(offline.localAudioPath, isNull);
      expect(audio.requests, isEmpty);
    });

    test(
      'network failure mid-download rolls back and flags download_failed',
      () async {
        audio.handler = (o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        );

        await expectLater(
          service.downloadLesson('lesson-1'),
          throwsA(isA<LessonDownloadException>()),
        );

        expect(
          service.statusOf('lesson-1').value,
          DownloadStatus.downloadFailed,
        );
        expect(await service.isLessonDownloaded('lesson-1'), isFalse);
        expect(dir.listSync(), isEmpty);
      },
    );

    test('API failure leaves nothing behind', () async {
      api.handler = (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionTimeout,
      );

      await expectLater(
        service.downloadLesson('lesson-1'),
        throwsA(isA<LessonDownloadException>()),
      );

      expect(service.statusOf('lesson-1').value, DownloadStatus.downloadFailed);
      expect(await db.getCachedLesson('lesson-1'), isNull);
    });

    test(
      'disk full surfaces InsufficientStorageException and cleans up',
      () async {
        audio.handler = (o) async => throw DioException(
          requestOptions: o,
          error: const FileSystemException(
            'No space left on device',
            '/data/audio.part',
            OSError('No space left on device', 28),
          ),
        );

        await expectLater(
          service.downloadLesson('lesson-1'),
          throwsA(isA<InsufficientStorageException>()),
        );

        expect(
          service.statusOf('lesson-1').value,
          DownloadStatus.downloadFailed,
        );
        expect(await service.isLessonDownloaded('lesson-1'), isFalse);
        expect(dir.listSync(), isEmpty);
      },
    );

    test(
      'a failed re-download keeps the previously downloaded lesson',
      () async {
        await service.downloadLesson('lesson-1');
        audio.handler = (o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        );

        await expectLater(
          service.downloadLesson('lesson-1'),
          throwsA(isA<LessonDownloadException>()),
        );

        expect(await service.isLessonDownloaded('lesson-1'), isTrue);
        final offline = (await OfflineLessonsDao(
          db,
        ).getOfflineLesson('lesson-1'))!;
        expect(File(offline.localAudioPath!).existsSync(), isTrue);
      },
    );
  });
}
