import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';

void main() {
  test(
    'migración v4 a v5 elimina columnas de acordes y conserva las notas',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''
              CREATE TABLE cached_notes (
                local_id INTEGER PRIMARY KEY AUTOINCREMENT,
                lesson_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                note TEXT NOT NULL,
                duration REAL NOT NULL,
                is_rest INTEGER NOT NULL DEFAULT 0,
                finger INTEGER NULL,
                hand TEXT NULL,
                velocity INTEGER NOT NULL DEFAULT 80,
                is_chord INTEGER NOT NULL DEFAULT 0,
                chord_group INTEGER NULL
              )
            ''');
            raw.execute(
              "INSERT INTO cached_notes (lesson_id, position, note, duration, is_chord, chord_group) VALUES ('l1', 0, 'G4', 1.0, 1, 2)",
            );
            raw.execute('PRAGMA user_version = 4');
          },
        ),
      );
      addTearDown(db.close);

      final notes = await db.getCachedNotes('l1');
      expect(notes, hasLength(1));
      expect(notes.single.note, 'G4');

      final cols = await db
          .customSelect('PRAGMA table_info(cached_notes)')
          .get();
      final names = cols.map((r) => r.read<String>('name')).toList();
      expect(names, isNot(contains('is_chord')));
      expect(names, isNot(contains('chord_group')));
    },
  );
}
