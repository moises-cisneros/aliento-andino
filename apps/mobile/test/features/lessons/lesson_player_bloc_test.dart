import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/lessons/data/models/lesson_model.dart';
import 'package:mobile/features/lessons/data/models/note_sequence_model.dart';
import 'package:mobile/features/lessons/data/repositories/lesson_repository.dart';
import 'package:mobile/features/lessons/presentation/bloc/lesson_player_bloc.dart';

class MockLessonRepository extends Mock implements LessonRepository {}

void main() {
  const testLesson = LessonModel(
    id: 'lesson-123',
    categoryId: 'cat-456',
    title: 'Escala de Sol Mayor en Quena',
    description: 'Digitación básica para Quena andina',
    instrument: 'quena',
    difficulty: 'principiante',
    tempoBpm: 80,
    timeSignature: '4/4',
    keySignature: 'G',
    notesCount: 4,
  );

  const testNotes = [
    NoteSequenceModel(id: 'note-1', position: 1, note: 'G4', duration: 1.0),
    NoteSequenceModel(id: 'note-2', position: 2, note: 'A4', duration: 1.0),
    NoteSequenceModel(id: 'note-3', position: 3, note: 'B4', duration: 1.0),
    NoteSequenceModel(id: 'note-4', position: 4, note: 'C5', duration: 1.0),
  ];

  late MockLessonRepository mockRepo;

  setUp(() {
    mockRepo = MockLessonRepository();
  });

  group('LessonPlayerBloc Unit Tests [SUB-04-B]', () {
    test('Estado inicial es LessonPlayerInitial', () {
      final bloc = LessonPlayerBloc(lessonRepository: mockRepo);
      expect(bloc.state, isA<LessonPlayerInitial>());
      bloc.close();
    });

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'StartPlayback activa isPlaying en true',
      build: () => LessonPlayerBloc(lessonRepository: mockRepo),
      seed: () => const LessonPlayerLoaded(
        lesson: testLesson,
        notes: testNotes,
        isPlaying: false,
      ),
      act: (bloc) => bloc.add(const StartPlayback()),
      expect: () => [
        const LessonPlayerLoaded(
          lesson: testLesson,
          notes: testNotes,
          isPlaying: true,
        ),
      ],
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'PausePlayback desactiva isPlaying a false',
      build: () => LessonPlayerBloc(lessonRepository: mockRepo),
      seed: () => const LessonPlayerLoaded(
        lesson: testLesson,
        notes: testNotes,
        isPlaying: true,
      ),
      act: (bloc) => bloc.add(const PausePlayback()),
      expect: () => [
        const LessonPlayerLoaded(
          lesson: testLesson,
          notes: testNotes,
          isPlaying: false,
        ),
      ],
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'NoteEvaluated incrementa notas correctas y avanza de posición',
      build: () => LessonPlayerBloc(lessonRepository: mockRepo),
      seed: () => const LessonPlayerLoaded(
        lesson: testLesson,
        notes: testNotes,
        isPlaying: true,
        currentNoteIndex: 0,
        currentMeasure: 1,
        correctNotesCount: 0,
        wrongNotesCount: 0,
        score: 100.0,
      ),
      act: (bloc) => bloc.add(
        const NoteEvaluated(noteIndex: 0, isCorrect: true, centsDeviation: 2.5),
      ),
      expect: () => [
        const LessonPlayerLoaded(
          lesson: testLesson,
          notes: testNotes,
          isPlaying: true,
          currentNoteIndex: 1,
          currentMeasure: 1,
          correctNotesCount: 1,
          wrongNotesCount: 0,
          score: 100.0,
          isCompleted: false,
        ),
      ],
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'NoteEvaluated con nota errónea recalcula el puntaje acumulado',
      build: () => LessonPlayerBloc(lessonRepository: mockRepo),
      seed: () => const LessonPlayerLoaded(
        lesson: testLesson,
        notes: testNotes,
        isPlaying: true,
        currentNoteIndex: 1,
        correctNotesCount: 1,
        wrongNotesCount: 0,
        score: 100.0,
      ),
      act: (bloc) => bloc.add(
        const NoteEvaluated(
          noteIndex: 1,
          isCorrect: false,
          centsDeviation: 25.0,
        ),
      ),
      expect: () => [
        const LessonPlayerLoaded(
          lesson: testLesson,
          notes: testNotes,
          isPlaying: true,
          currentNoteIndex: 2,
          correctNotesCount: 1,
          wrongNotesCount: 1,
          score: 50.0,
          isCompleted: false,
        ),
      ],
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'RestartPlayback reinicia contadores a cero y pausa la reproducción',
      build: () => LessonPlayerBloc(lessonRepository: mockRepo),
      seed: () => const LessonPlayerLoaded(
        lesson: testLesson,
        notes: testNotes,
        isPlaying: true,
        currentNoteIndex: 3,
        currentMeasure: 2,
        correctNotesCount: 2,
        wrongNotesCount: 1,
        score: 66.6,
      ),
      act: (bloc) => bloc.add(const RestartPlayback()),
      expect: () => [
        const LessonPlayerLoaded(
          lesson: testLesson,
          notes: testNotes,
          isPlaying: false,
          currentNoteIndex: 0,
          currentMeasure: 1,
          correctNotesCount: 0,
          wrongNotesCount: 0,
          score: 100.0,
          isCompleted: false,
        ),
      ],
    );
  });

  group('LessonRepository & LessonPlayerBloc Integration Tests', () {
    test(
      'Carga exitosa desde LessonRepository emite LessonPlayerLoaded',
      () async {
        when(
          () => mockRepo.getLessonDetail('lesson-123'),
        ).thenAnswer((_) async => {'lesson': testLesson, 'notes': testNotes});

        final bloc = LessonPlayerBloc(lessonRepository: mockRepo);
        bloc.add(const LoadLessonPlayer('lesson-123'));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            const LessonPlayerLoading(),
            const LessonPlayerLoaded(
              lesson: testLesson,
              notes: testNotes,
              isPlaying: false,
              currentNoteIndex: 0,
              currentMeasure: 1,
              correctNotesCount: 0,
              wrongNotesCount: 0,
              score: 100.0,
              isCompleted: false,
              isOffline: false,
            ),
          ]),
        );
        bloc.close();
      },
    );

    test('Falla de red sin caché emite LessonPlayerError offline', () async {
      when(
        () => mockRepo.getLessonDetail('bad-id'),
      ).thenThrow(Exception('Network failure connection refused'));
      when(
        () => mockRepo.getLessonById('bad-id'),
      ).thenThrow(Exception('No cached item found'));

      final bloc = LessonPlayerBloc(lessonRepository: mockRepo);
      bloc.add(const LoadLessonPlayer('bad-id'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          const LessonPlayerLoading(),
          isA<LessonPlayerError>().having(
            (e) => e.isOffline,
            'isOffline',
            isTrue,
          ),
        ]),
      );
      bloc.close();
    });
  });

  group('Lesson Interactive Playback E2E Flow', () {
    test(
      'Flujo E2E completo: catálogo -> inicio de práctica -> evaluación de notas -> fin de lección',
      () async {
        // 1. Simular consulta de catálogo filtrado por Quena
        when(
          () => mockRepo.getLessons(
            instrument: InstrumentType.quena,
            difficulty: 'principiante',
          ),
        ).thenAnswer((_) async => [testLesson]);

        final catalog = await mockRepo.getLessons(
          instrument: InstrumentType.quena,
          difficulty: 'principiante',
        );
        expect(catalog.length, 1);
        final selected = catalog.first;
        expect(selected.instrument, 'quena');

        // 2. Inicializar el reproductor con la lección seleccionada
        when(
          () => mockRepo.getLessonDetail(selected.id),
        ).thenAnswer((_) async => {'lesson': selected, 'notes': testNotes});

        final bloc = LessonPlayerBloc(lessonRepository: mockRepo);
        bloc.add(LoadLessonPlayer(selected.id));

        await bloc.stream.firstWhere((s) => s is LessonPlayerLoaded);
        expect(bloc.state, isA<LessonPlayerLoaded>());

        // 3. Comenzar la práctica
        bloc.add(const StartPlayback());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect((bloc.state as LessonPlayerLoaded).isPlaying, isTrue);

        // 4. Evaluar notas compás a compás
        for (int i = 0; i < testNotes.length; i++) {
          bloc.add(NoteEvaluated(noteIndex: i, isCorrect: true));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        // 5. Verificar que la lección finaliza con éxito
        final finalState = bloc.state as LessonPlayerLoaded;
        expect(finalState.isCompleted, isTrue);
        expect(finalState.isPlaying, isFalse);
        expect(finalState.correctNotesCount, 4);
        expect(finalState.score, 100.0);
        expect(finalState.progress, 1.0);

        bloc.close();
      },
    );
  });
}
