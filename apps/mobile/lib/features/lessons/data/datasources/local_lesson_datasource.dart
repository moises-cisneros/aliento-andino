import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/offline_lessons_dao.dart';
import '../models/category_model.dart';
import '../models/lesson_model.dart';
import '../models/note_sequence_model.dart';

/// Fuente de datos LOCAL de lecciones (cache offline sobre Drift/SQLite).
///
/// Traduce entre los modelos de la API y las filas de la base local. No conoce
/// la red: el repositorio decide cuándo leer de acá y cuándo refrescar.
class LocalLessonDataSource {
  final AppDatabase _db;

  const LocalLessonDataSource(this._db);

  // ---------------- Categorías ----------------

  Future<void> cacheCategories(List<CategoryModel> categories) {
    return _db.upsertCategories([
      for (final c in categories)
        CachedCategoriesCompanion.insert(
          id: c.id,
          name: c.name,
          description: Value(c.description),
          icon: Value(c.icon),
          sortOrder: Value(c.order),
          lessonsCount: Value(c.lessonsCount),
        ),
    ]);
  }

  Future<List<CategoryModel>> getCategories() async {
    final rows = await _db.getCachedCategories();
    return rows
        .map(
          (r) => CategoryModel(
            id: r.id,
            name: r.name,
            description: r.description,
            icon: r.icon,
            order: r.sortOrder,
            lessonsCount: r.lessonsCount,
          ),
        )
        .toList();
  }

  // ---------------- Lecciones ----------------

  /// Cachea metadatos de lecciones SIN tocar la marca de descarga (un refresh
  /// de la lista no debe borrar lo que el usuario descargó para offline).
  Future<void> cacheLessons(List<LessonModel> lessons) {
    return _db.upsertLessons([for (final l in lessons) _toCompanion(l)]);
  }

  Future<List<LessonModel>> getLessons({
    String? categoryId,
    String? difficulty,
    bool onlyDownloaded = false,
  }) async {
    final rows = await _db.getCachedLessons(
      categoryId: categoryId,
      difficulty: difficulty,
      onlyDownloaded: onlyDownloaded,
    );
    return rows.map(_toModel).toList();
  }

  Future<LessonModel?> getLesson(String id) async {
    final row = await _db.getCachedLesson(id);
    return row == null ? null : _toModel(row);
  }

  Future<bool> isDownloaded(String id) async {
    final row = await _db.getCachedLesson(id);
    return row?.downloadedAt != null;
  }

  Future<void> setAudioLocalPath(String lessonId, String path) =>
      _db.setAudioLocalPath(lessonId, path);

  Future<String?> getAudioLocalPath(String lessonId) =>
      _db.getAudioLocalPath(lessonId);

  /// Guarda lección + sus notas. `markDownloaded` marca la lección como
  /// disponible para practicar sin conexión.
  Future<void> cacheLessonDetail(
    LessonModel lesson,
    List<NoteSequenceModel> notes, {
    bool markDownloaded = false,
  }) async {
    await _db.upsertLessons([_toCompanion(lesson)]);
    await _db.replaceLessonNotes(
      lesson.id,
      _toNoteCompanions(lesson.id, notes),
    );
    if (markDownloaded) {
      await _db.markLessonDownloaded(lesson.id, DateTime.now());
    }
  }

  /// Persists a complete offline package (lesson + notes + audio path +
  /// downloaded mark) in a single transaction.
  Future<void> saveDownload(
    LessonModel lesson,
    List<NoteSequenceModel> notes, {
    String? localAudioPath,
  }) {
    return OfflineLessonsDao(_db).saveDownload(
      lesson: _toCompanion(lesson),
      notes: _toNoteCompanions(lesson.id, notes),
      localAudioPath: localAudioPath,
      downloadedAt: DateTime.now(),
    );
  }

  List<CachedNotesCompanion> _toNoteCompanions(
    String lessonId,
    List<NoteSequenceModel> notes,
  ) {
    return [
      for (final n in notes)
        CachedNotesCompanion.insert(
          lessonId: lessonId,
          position: n.position,
          note: n.note,
          duration: n.duration,
          isRest: Value(n.isRest),
          finger: Value(n.finger),
          hand: Value(n.hand),
          velocity: Value(n.velocity),
          isChord: Value(n.isChord),
          chordGroup: Value(n.chordGroup),
        ),
    ];
  }

  Future<List<NoteSequenceModel>> getNotes(String lessonId) async {
    final rows = await _db.getCachedNotes(lessonId);
    return rows
        .map(
          (r) => NoteSequenceModel(
            id: '',
            position: r.position,
            note: r.note,
            duration: r.duration,
            isRest: r.isRest,
            finger: r.finger,
            hand: r.hand,
            velocity: r.velocity,
            isChord: r.isChord,
            chordGroup: r.chordGroup,
          ),
        )
        .toList();
  }

  // ---------------- Mapeo ----------------

  CachedLessonsCompanion _toCompanion(LessonModel l) {
    // downloadedAt y cachedAt quedan ausentes a propósito: en un upsert eso
    // preserva el valor existente (no pisa la marca de descarga).
    return CachedLessonsCompanion.insert(
      id: l.id,
      categoryId: l.categoryId,
      title: l.title,
      difficulty: l.difficulty,
      instrument: Value(l.instrument),
      description: Value(l.description),
      tempoBpm: Value(l.tempoBpm),
      timeSignature: Value(l.timeSignature),
      keySignature: Value(l.keySignature),
      thumbnailUrl: Value(l.thumbnailUrl),
      audioPreviewUrl: Value(l.audioPreviewUrl),
      durationSeconds: Value(l.durationSeconds),
      sortOrder: Value(l.order),
      isPremium: Value(l.isPremium),
      totalPlays: Value(l.totalPlays),
      averageScore: Value(l.averageScore),
      categoryName: Value(l.categoryName),
      notesCount: Value(l.notesCount),
      userBestScore: Value(l.userBestScore),
    );
  }

  LessonModel _toModel(CachedLesson r) {
    return LessonModel(
      id: r.id,
      categoryId: r.categoryId,
      title: r.title,
      description: r.description,
      instrument: r.instrument,
      difficulty: r.difficulty,
      tempoBpm: r.tempoBpm,
      timeSignature: r.timeSignature ?? '4/4',
      keySignature: r.keySignature ?? 'C',
      thumbnailUrl: r.thumbnailUrl,
      audioPreviewUrl: r.audioPreviewUrl,
      durationSeconds: r.durationSeconds,
      order: r.sortOrder,
      isPremium: r.isPremium,
      totalPlays: r.totalPlays,
      averageScore: r.averageScore,
      categoryName: r.categoryName,
      notesCount: r.notesCount,
      userBestScore: r.userBestScore,
    );
  }
}
