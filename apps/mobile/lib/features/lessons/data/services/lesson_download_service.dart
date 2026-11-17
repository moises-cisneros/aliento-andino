import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/offline_lessons_dao.dart';
import '../datasources/local_lesson_datasource.dart';
import '../models/lesson_model.dart';
import '../models/note_sequence_model.dart';

/// Download lifecycle of a single lesson.
enum DownloadStatus { idle, downloading, downloaded, downloadFailed }

/// The device ran out of disk space while saving the lesson audio.
class InsufficientStorageException implements Exception {
  const InsufficientStorageException();

  @override
  String toString() => 'InsufficientStorageException: not enough disk space';
}

/// The download failed (network or server); nothing was kept on the device.
class LessonDownloadException implements Exception {
  final Object cause;

  const LessonDownloadException(this.cause);

  @override
  String toString() => 'LessonDownloadException: $cause';
}

/// A downloaded lesson and the disk space its audio takes.
class OfflineDownloadEntry {
  final OfflineLesson lesson;
  final int audioBytes;

  const OfflineDownloadEntry({required this.lesson, required this.audioBytes});
}

/// Result of listing downloads: the valid ones plus the ids that were found
/// inconsistent (audio file missing) and flagged for re-download.
class OfflineDownloads {
  final List<OfflineDownloadEntry> entries;
  final List<String> stale;

  const OfflineDownloads({required this.entries, required this.stale});

  int get totalBytes => entries.fold(0, (sum, e) => sum + e.audioBytes);
}

/// Downloads a lesson package (notes JSON + reference audio) and persists it
/// in the local Drift database so it can be practiced without a connection.
///
/// A download is all-or-nothing: the audio is written to a `.part` file and
/// only renamed once complete, and the database is written in one transaction
/// after the audio is safe on disk. Any failure removes the partial file and
/// leaves the lesson in [DownloadStatus.downloadFailed].
class LessonDownloadService {
  /// Error codes for "disk full": ENOSPC (Linux/Android/iOS/macOS),
  /// ERROR_HANDLE_DISK_FULL and ERROR_DISK_FULL (Windows).
  static const _diskFullCodes = {28, 39, 112};

  final Dio _api;
  final Dio _audioClient;
  final LocalLessonDataSource _local;
  final OfflineLessonsDao _dao;
  final Future<Directory> Function() _audioDirectory;
  final Map<String, ValueNotifier<DownloadStatus>> _statuses = {};

  LessonDownloadService({
    required Dio api,
    required AppDatabase db,
    required Future<Directory> Function() audioDirectory,
    Dio? audioClient,
  }) : _api = api,
       // The audio lives in cloud storage, not behind the API: use a client
       // without the API interceptors (auth headers must not leak there).
       _audioClient = audioClient ?? Dio(),
       _local = LocalLessonDataSource(db),
       _dao = OfflineLessonsDao(db),
       _audioDirectory = audioDirectory;

  /// Observable status of [lessonId] (starts as [DownloadStatus.idle]).
  ValueListenable<DownloadStatus> statusOf(String lessonId) =>
      _notifier(lessonId);

  ValueNotifier<DownloadStatus> _notifier(String lessonId) =>
      _statuses.putIfAbsent(lessonId, () => ValueNotifier(DownloadStatus.idle));

  Future<bool> isLessonDownloaded(String lessonId) =>
      _dao.isDownloaded(lessonId);

  /// Deletes the downloaded package (database rows and audio file).
  Future<void> deleteDownloadedLesson(String lessonId) async {
    final audioPath = await _dao.removeDownload(lessonId);
    if (audioPath != null) await _deleteQuietly(File(audioPath));
    _notifier(lessonId).value = DownloadStatus.idle;
  }

  /// Downloaded lessons with the space their audio uses.
  ///
  /// Lessons whose audio file vanished from the filesystem (user cleaned the
  /// storage by hand) are un-marked as downloaded so they show up as
  /// needing a re-download; their ids come back in [OfflineDownloads.stale].
  Future<OfflineDownloads> listDownloads() async {
    final entries = <OfflineDownloadEntry>[];
    final stale = <String>[];
    for (final lesson in await _dao.listOfflineLessons()) {
      final path = lesson.localAudioPath;
      var bytes = 0;
      if (path != null) {
        final file = File(path);
        if (!await file.exists()) {
          await _dao.removeDownload(lesson.id);
          _notifier(lesson.id).value = DownloadStatus.idle;
          stale.add(lesson.id);
          continue;
        }
        bytes = await file.length();
      }
      entries.add(OfflineDownloadEntry(lesson: lesson, audioBytes: bytes));
    }
    return OfflineDownloads(entries: entries, stale: stale);
  }

  /// Downloads [lessonId]. Throws [InsufficientStorageException] when the disk
  /// is full and [LessonDownloadException] for any other failure.
  Future<void> downloadLesson(String lessonId) async {
    final status = _notifier(lessonId);
    status.value = DownloadStatus.downloading;

    final wasDownloaded = await _dao.isDownloaded(lessonId);
    File? partial;
    File? finalAudio;
    try {
      final response = await _api.get('/lessons/$lessonId');
      final data = response.data as Map<String, dynamic>;
      final lesson = LessonModel.fromJson(data);
      final notes = await _readNotes(lessonId, data);

      String? audioPath;
      final audioUrl = lesson.audioPreviewUrl;
      if (audioUrl != null && audioUrl.isNotEmpty) {
        final dir = await _audioDirectory();
        finalAudio = File(
          '${dir.path}/lesson_audio_$lessonId${_audioExt(audioUrl)}',
        );
        partial = File('${finalAudio.path}.part');
        await _audioClient.download(audioUrl, partial.path);
        await partial.rename(finalAudio.path);
        partial = null;
        audioPath = finalAudio.path;
      }

      await _local.saveDownload(lesson, notes, localAudioPath: audioPath);
      status.value = DownloadStatus.downloaded;
    } catch (error) {
      await _rollback(partial, wasDownloaded ? null : finalAudio);
      status.value = DownloadStatus.downloadFailed;
      if (_isDiskFull(error)) throw const InsufficientStorageException();
      throw LessonDownloadException(error);
    }
  }

  Future<List<NoteSequenceModel>> _readNotes(
    String lessonId,
    Map<String, dynamic> detail,
  ) async {
    final inline = detail['notes'] as List<dynamic>?;
    var notes = [
      for (final e in inline ?? const [])
        NoteSequenceModel.fromJson(e as Map<String, dynamic>),
    ];
    if (notes.isEmpty) {
      final response = await _api.get('/lessons/$lessonId/sequence');
      notes = [
        for (final e in response.data as List<dynamic>)
          NoteSequenceModel.fromJson(e as Map<String, dynamic>),
      ];
    }
    return notes;
  }

  Future<void> _rollback(File? partial, File? newAudio) async {
    for (final file in [partial, newAudio]) {
      if (file != null) await _deleteQuietly(file);
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort: a leftover file is better than masking the real error.
    }
  }

  bool _isDiskFull(Object error) {
    final cause = error is DioException ? error.error : error;
    if (cause is FileSystemException) {
      return _diskFullCodes.contains(cause.osError?.errorCode);
    }
    return false;
  }

  String _audioExt(String url) {
    final path = Uri.parse(url).path;
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot > path.lastIndexOf('/')) return path.substring(dot);
    return '.mp3';
  }
}
