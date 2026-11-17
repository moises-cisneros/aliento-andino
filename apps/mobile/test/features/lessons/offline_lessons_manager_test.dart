import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/core/database/daos/offline_lessons_dao.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/lessons/data/datasources/local_lesson_datasource.dart';
import 'package:mobile/features/lessons/data/repositories/lesson_repository.dart';
import 'package:mobile/features/lessons/data/services/lesson_download_service.dart';
import 'package:mobile/features/lessons/presentation/screens/offline_lessons_screen.dart';
import 'package:mobile/features/lessons/presentation/widgets/offline_badge_widget.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late AppDatabase db;
  late Directory dir;
  late LessonDownloadService service;
  late LessonRepository repo;

  Future<File> seedDownload(
    String id, {
    List<int> audio = const [1, 2, 3],
    bool createFile = true,
  }) async {
    final file = File('${dir.path}/lesson_audio_$id.mp3');
    if (createFile) file.writeAsBytesSync(audio);
    await OfflineLessonsDao(db).saveDownload(
      lesson: CachedLessonsCompanion.insert(
        id: id,
        categoryId: 'c1',
        title: 'Leccion $id',
        difficulty: 'principiante',
        instrument: const Value('quena'),
      ),
      notes: [
        CachedNotesCompanion.insert(
          lessonId: id,
          position: 0,
          note: 'D4',
          duration: 1,
        ),
      ],
      localAudioPath: file.path,
      downloadedAt: DateTime(2026, 11, 17),
    );
    return file;
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('offline_manager_test');
    service = LessonDownloadService(
      api: Dio(),
      db: db,
      audioDirectory: () async => dir,
    );
    repo = LessonRepository(
      apiClient: _MockApiClient(),
      local: LocalLessonDataSource(db),
      downloads: service,
    );
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  group('OfflineBadgeWidget', () {
    testWidgets('shows the offline icon when the lesson is downloaded', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: OfflineBadgeWidget(isDownloaded: true)),
      );

      expect(find.byKey(const ValueKey('offline-badge-icon')), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.byKey(const ValueKey('offline-badge-icon')),
      );
      expect(icon.icon, Icons.offline_pin_rounded);
    });

    testWidgets('shows nothing when the lesson is not downloaded', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: OfflineBadgeWidget(isDownloaded: false)),
      );

      expect(find.byType(Icon), findsNothing);
    });
  });

  group('deleteDownloadedLesson', () {
    test('removes database rows and the audio file', () async {
      final file = await seedDownload('l1');
      expect(file.existsSync(), isTrue);

      await repo.deleteDownloadedLesson('l1');

      expect(await service.isLessonDownloaded('l1'), isFalse);
      expect(file.existsSync(), isFalse);
      expect(await db.getCachedNotes('l1'), isEmpty);
      expect(await db.getAudioLocalPath('l1'), isNull);
      // Catalog metadata is kept so the lesson still lists as not downloaded.
      expect(await db.getCachedLesson('l1'), isNotNull);
    });

    test('keeps other downloads untouched', () async {
      await seedDownload('l1');
      final other = await seedDownload('l2');

      await repo.deleteDownloadedLesson('l1');

      expect(await service.isLessonDownloaded('l2'), isTrue);
      expect(other.existsSync(), isTrue);
    });
  });

  group('listDownloads', () {
    test('reports the space used by the audio files', () async {
      await seedDownload('l1', audio: List.filled(2048, 1));
      await seedDownload('l2', audio: List.filled(1024, 1));

      final downloads = await repo.getOfflineDownloads();

      expect(downloads.entries, hasLength(2));
      expect(downloads.totalBytes, 3072);
      expect(downloads.stale, isEmpty);
    });

    test(
      'audio removed from the filesystem is flagged for re-download',
      () async {
        await seedDownload('l1');
        await seedDownload('l2', createFile: false);

        final downloads = await repo.getOfflineDownloads();

        expect(downloads.stale, ['l2']);
        expect(downloads.entries.map((e) => e.lesson.id), ['l1']);
        expect(await service.isLessonDownloaded('l2'), isFalse);
        expect(await service.isLessonDownloaded('l1'), isTrue);
      },
    );
  });

  group('OfflineLessonsScreen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        RepositoryProvider<LessonRepository>.value(
          value: repo,
          child: const MaterialApp(home: OfflineLessonsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows an empty state without downloads', (tester) async {
      await tester.runAsync(() => pumpScreen(tester));

      expect(find.textContaining('Todavía no descargaste'), findsOneWidget);
    });

    testWidgets('lists downloads, total space and deletes an item', (
      tester,
    ) async {
      late File file;
      await tester.runAsync(() async {
        file = await seedDownload('l1', audio: List.filled(2048, 1));
        await seedDownload('l2', audio: List.filled(1024, 1));
        await tester.pumpWidget(
          RepositoryProvider<LessonRepository>.value(
            value: repo,
            child: const MaterialApp(home: OfflineLessonsScreen()),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.text('Leccion l1'), findsOneWidget);
      expect(find.text('Leccion l2'), findsOneWidget);
      expect(find.textContaining('3.0 KB en uso'), findsOneWidget);
      expect(find.byType(OfflineBadgeWidget), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('delete-l1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      // Close the dialog, then give the real I/O (db + file) time to finish.
      await tester.pumpAndSettle();
      // Each db/file step resumes only after a pump, so alternate real time
      // and pumps until the list reflects the deletion.
      for (
        var i = 0;
        i < 20 && find.text('Leccion l1').evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Leccion l1'), findsNothing);
      expect(find.text('Leccion l2'), findsOneWidget);
      await tester.runAsync(() async {
        expect(file.existsSync(), isFalse);
        expect(await service.isLessonDownloaded('l1'), isFalse);
      });
    });
  });
}
