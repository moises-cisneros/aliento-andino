import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Categorías de lecciones cacheadas para navegación offline.
@DataClassName('CachedCategory')
class CachedCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get lessonsCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Metadatos de lecciones cacheadas. `downloadedAt != null` indica que la
/// lección (con sus notas) está disponible para practicar sin conexión.
@DataClassName('CachedLesson')
class CachedLessons extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get difficulty => text()();
  IntColumn get tempoBpm => integer().withDefault(const Constant(0))();
  TextColumn get timeSignature => text().nullable()();
  TextColumn get keySignature => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get audioPreviewUrl => text().nullable()();
  // Ruta del archivo de audio descargado para reproducir el preview offline.
  TextColumn get audioLocalPath => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  IntColumn get totalPlays => integer().withDefault(const Constant(0))();
  RealColumn get averageScore => real().withDefault(const Constant(0))();
  TextColumn get categoryName => text().nullable()();
  IntColumn get notesCount => integer().withDefault(const Constant(0))();
  RealColumn get userBestScore => real().nullable()();
  DateTimeColumn get downloadedAt => dateTime().nullable()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Secuencia de notas de una lección descargada (lo único que se necesita para
/// practicar offline; el scoring ya corre en el dispositivo).
@DataClassName('CachedNote')
class CachedNotes extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get lessonId => text()();
  IntColumn get position => integer()();
  TextColumn get note => text()();
  RealColumn get duration => real()();
  BoolColumn get isRest => boolean().withDefault(const Constant(false))();
  IntColumn get finger => integer().nullable()();
  TextColumn get hand => text().nullable()();
  IntColumn get velocity => integer().withDefault(const Constant(80))();
  BoolColumn get isChord => boolean().withDefault(const Constant(false))();
  IntColumn get chordGroup => integer().nullable()();
}

/// Cola "outbox": prácticas realizadas sin conexión, pendientes de enviar al
/// backend. `clientId` (UUID) se manda al server para deduplicar reintentos.
@DataClassName('PendingPracticeRow')
class PendingPractice extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get clientId => text()();
  TextColumn get lessonId => text()();
  RealColumn get score => real()();
  IntColumn get correctNotes => integer()();
  IntColumn get totalNotes => integer()();
  IntColumn get wrongNotes => integer()();
  IntColumn get missedNotes => integer()();
  RealColumn get averageTempo => real()();
  RealColumn get totalTimeSeconds => real()();
  TextColumn get errorsDetailJson => text().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// `false` mientras la práctica espera ser enviada; `true` cuando el backend
  /// ya la aceptó (la fila queda como registro local).
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

/// Cache genérico de snapshots JSON (progreso, perfil) para mostrarlos offline.
@DataClassName('CachedSnapshot')
class CachedSnapshots extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    CachedCategories,
    CachedLessons,
    CachedNotes,
    PendingPractice,
    CachedSnapshots,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'aliento_andino'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(cachedLessons, cachedLessons.audioLocalPath);
        await m.createTable(cachedSnapshots);
      }
      if (from < 3) {
        await m.addColumn(pendingPractice, pendingPractice.isSynced);
      }
    },
  );

  // ---------------- Categorías ----------------

  Future<void> upsertCategories(List<CachedCategoriesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(cachedCategories, rows);
    });
  }

  Future<List<CachedCategory>> getCachedCategories() {
    return (select(
      cachedCategories,
    )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();
  }

  // ---------------- Lecciones ----------------

  Future<void> upsertLessons(List<CachedLessonsCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(cachedLessons, rows);
    });
  }

  Future<List<CachedLesson>> getCachedLessons({
    String? categoryId,
    String? difficulty,
    bool onlyDownloaded = false,
  }) {
    final q = select(cachedLessons);
    if (categoryId != null) {
      q.where((t) => t.categoryId.equals(categoryId));
    }
    if (difficulty != null) {
      q.where((t) => t.difficulty.equals(difficulty));
    }
    if (onlyDownloaded) {
      q.where((t) => t.downloadedAt.isNotNull());
    }
    q.orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    return q.get();
  }

  Future<CachedLesson?> getCachedLesson(String id) {
    return (select(
      cachedLessons,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> markLessonDownloaded(String lessonId, DateTime when) async {
    await (update(cachedLessons)..where((t) => t.id.equals(lessonId))).write(
      CachedLessonsCompanion(downloadedAt: Value(when)),
    );
  }

  // ---------------- Notas ----------------

  /// Reemplaza la secuencia de notas de una lección (idempotente).
  Future<void> replaceLessonNotes(
    String lessonId,
    List<CachedNotesCompanion> notes,
  ) async {
    await transaction(() async {
      await (delete(
        cachedNotes,
      )..where((t) => t.lessonId.equals(lessonId))).go();
      await batch((b) => b.insertAll(cachedNotes, notes));
    });
  }

  Future<List<CachedNote>> getCachedNotes(String lessonId) {
    return (select(cachedNotes)
          ..where((t) => t.lessonId.equals(lessonId))
          ..orderBy([(t) => OrderingTerm(expression: t.position)]))
        .get();
  }

  // ---------------- Outbox de prácticas ----------------

  Future<int> enqueuePractice(PendingPracticeCompanion row) {
    return into(pendingPractice).insert(row);
  }

  /// Prácticas aún no aceptadas por el backend (`is_synced = false`).
  Future<List<PendingPracticeRow>> getPendingPractices() {
    return (select(pendingPractice)
          ..where((t) => t.isSynced.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Future<void> deletePending(int localId) async {
    await (delete(
      pendingPractice,
    )..where((t) => t.localId.equals(localId))).go();
  }

  /// Marca una práctica como aceptada por el backend (`is_synced = true`).
  Future<void> markPracticeSynced(int localId) async {
    await (update(pendingPractice)..where((t) => t.localId.equals(localId)))
        .write(const PendingPracticeCompanion(isSynced: Value(true)));
  }

  Future<int> pendingCount() async {
    final count = countAll();
    final row =
        await (selectOnly(pendingPractice)
              ..addColumns([count])
              ..where(pendingPractice.isSynced.equals(false)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Stream del número de prácticas pendientes (para badges en la UI).
  Stream<int> watchPendingCount() {
    final count = countAll();
    return (selectOnly(pendingPractice)
          ..addColumns([count])
          ..where(pendingPractice.isSynced.equals(false)))
        .map((row) => row.read(count) ?? 0)
        .watchSingle();
  }

  // ---------------- Snapshots JSON (progreso/perfil offline) ----------------

  Future<void> putSnapshot(String key, String json) async {
    await into(cachedSnapshots).insertOnConflictUpdate(
      CachedSnapshotsCompanion.insert(
        key: key,
        json: json,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<String?> getSnapshot(String key) async {
    final row = await (select(
      cachedSnapshots,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.json;
  }

  // ---------------- Audio offline ----------------

  Future<void> setAudioLocalPath(String lessonId, String path) async {
    await (update(cachedLessons)..where((t) => t.id.equals(lessonId))).write(
      CachedLessonsCompanion(audioLocalPath: Value(path)),
    );
  }

  Future<String?> getAudioLocalPath(String lessonId) async {
    final row = await getCachedLesson(lessonId);
    return row?.audioLocalPath;
  }
}
