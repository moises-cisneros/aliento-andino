import 'dart:convert';

import '../app_database.dart';

/// Offline lesson package as stored on the device: lesson metadata, the score
/// (notes) as JSON and the local path of the reference audio.
class OfflineLesson {
  final String id;
  final String title;
  final String instrument;
  final String notesJson;
  final String? localAudioPath;
  final DateTime downloadedAt;

  const OfflineLesson({
    required this.id,
    required this.title,
    required this.instrument,
    required this.notesJson,
    required this.localAudioPath,
    required this.downloadedAt,
  });
}

/// Data access for downloaded lessons.
///
/// A download is the lesson row (`CachedLessons`, flagged with `downloadedAt`)
/// plus its notes (`CachedNotes`); this DAO exposes both as a single
/// [OfflineLesson] so callers never deal with the two tables.
class OfflineLessonsDao {
  final AppDatabase _db;

  const OfflineLessonsDao(this._db);

  /// Whether [lessonId] has been fully downloaded.
  Future<bool> isDownloaded(String lessonId) async {
    final row = await _db.getCachedLesson(lessonId);
    return row?.downloadedAt != null;
  }

  /// Returns the offline package for [lessonId], or null if not downloaded.
  Future<OfflineLesson?> getOfflineLesson(String lessonId) async {
    final row = await _db.getCachedLesson(lessonId);
    final downloadedAt = row?.downloadedAt;
    if (row == null || downloadedAt == null) return null;
    return _toOfflineLesson(row, downloadedAt);
  }

  /// All downloaded lessons, in catalog order.
  Future<List<OfflineLesson>> listOfflineLessons() async {
    final rows = await _db.getCachedLessons(onlyDownloaded: true);
    return [
      for (final row in rows) await _toOfflineLesson(row, row.downloadedAt!),
    ];
  }

  Future<OfflineLesson> _toOfflineLesson(
    CachedLesson row,
    DateTime downloadedAt,
  ) async {
    final notes = await _db.getCachedNotes(row.id);
    return OfflineLesson(
      id: row.id,
      title: row.title,
      instrument: row.instrument,
      notesJson: jsonEncode([
        for (final n in notes)
          {
            'position': n.position,
            'note': n.note,
            'duration': n.duration,
            'is_rest': n.isRest,
            'finger': n.finger,
            'hand': n.hand,
            'velocity': n.velocity,
            'is_chord': n.isChord,
            'chord_group': n.chordGroup,
          },
      ]),
      localAudioPath: row.audioLocalPath,
      downloadedAt: downloadedAt,
    );
  }

  /// Drops the offline package of [lessonId]. Returns the audio path it had,
  /// so the caller can delete the file.
  Future<String?> removeDownload(String lessonId) async {
    final path = await _db.getAudioLocalPath(lessonId);
    await _db.clearLessonDownload(lessonId);
    return path;
  }

  /// Persists a complete download atomically: lesson, notes, audio path and
  /// the downloaded mark land together or not at all.
  Future<void> saveDownload({
    required CachedLessonsCompanion lesson,
    required List<CachedNotesCompanion> notes,
    required String? localAudioPath,
    required DateTime downloadedAt,
  }) {
    return _db.transaction(() async {
      await _db.upsertLessons([lesson]);
      final lessonId = lesson.id.value;
      await _db.replaceLessonNotes(lessonId, notes);
      if (localAudioPath != null) {
        await _db.setAudioLocalPath(lessonId, localAudioPath);
      }
      await _db.markLessonDownloaded(lessonId, downloadedAt);
    });
  }
}
