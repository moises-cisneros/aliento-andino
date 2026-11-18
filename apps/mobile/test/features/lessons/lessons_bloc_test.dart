import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/lessons/data/models/category_model.dart';
import 'package:mobile/features/lessons/data/models/lesson_model.dart';
import 'package:mobile/features/lessons/data/repositories/lesson_repository.dart';
import 'package:mobile/features/lessons/presentation/bloc/lessons/lessons_bloc.dart';
import 'package:mobile/features/lessons/presentation/bloc/lessons/lessons_event.dart';
import 'package:mobile/features/lessons/presentation/bloc/lessons/lessons_state.dart';

class _FakeLessonRepository implements LessonRepository {
  final List<LessonModel> lessons;
  final List<CategoryModel> categories;
  String? lastRequestedInstrument;

  _FakeLessonRepository({required this.lessons, required this.categories});

  @override
  Future<List<CategoryModel>> getCategories() async => categories;

  @override
  Future<Map<String, dynamic>> getLessonsPaginated({
    String? categoryId,
    String? difficulty,
    String? genre,
    String? search,
    String? instrument,
    int page = 1,
    int limit = 100,
  }) async {
    lastRequestedInstrument = instrument;
    var filtered = lessons;
    if (instrument != null && instrument.isNotEmpty) {
      filtered = filtered
          .where((l) => l.instrument.toLowerCase() == instrument.toLowerCase())
          .toList();
    }
    return {
      'items': filtered,
      'total': filtered.length,
      'page': page,
      'pages': 1,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeLessonRepository fakeRepo;
  late LessonsBloc bloc;

  final cat1 = const CategoryModel(
    id: 'c1',
    name: 'Tradicional',
    lessonsCount: 3,
  );

  final lessonQuena = const LessonModel(
    id: 'l_quena_1',
    categoryId: 'c1',
    title: 'El Cóndor Pasa',
    description: 'Melodía tradicional en Quena',
    instrument: 'quena',
    difficulty: 'principiante',
    order: 1,
    tempoBpm: 80,
  );

  final lessonZampona = const LessonModel(
    id: 'l_zampona_1',
    categoryId: 'c1',
    title: 'Sikuris de Italaque',
    description: 'Melodía en Zampoña',
    instrument: 'zampona',
    difficulty: 'principiante',
    order: 1,
    tempoBpm: 80,
  );

  final lessonTarka = const LessonModel(
    id: 'l_tarka_1',
    categoryId: 'c1',
    title: 'Carnaval de Oruro',
    description: 'Melodía festiva en Tarka',
    instrument: 'tarka',
    difficulty: 'intermedio',
    order: 1,
    tempoBpm: 80,
  );

  setUp(() {
    fakeRepo = _FakeLessonRepository(
      categories: [cat1],
      lessons: [lessonQuena, lessonZampona, lessonTarka],
    );
    bloc = LessonsBloc(lessonRepository: fakeRepo);
  });

  tearDown(() {
    bloc.close();
  });

  group('LessonsBloc - ActiveInstrument Connection [SUB-143]', () {
    test(
      'emits LessonsLoaded with all lessons initially on LessonsLoadCategories',
      () async {
        bloc.add(const LessonsLoadCategories());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<LessonsLoading>(),
            predicate<LessonsLoaded>((state) {
              return state.categories.length == 1 &&
                  state.allLessons.length == 3 &&
                  state.lessons.length == 3;
            }),
          ]),
        );
      },
    );

    test(
      'filters lessons by instrument when LessonsFilterByInstrument is dispatched',
      () async {
        bloc.add(const LessonsLoadCategories());
        await bloc.stream.firstWhere((s) => s is LessonsLoaded);

        // Filtrar por Zampoña
        bloc.add(const LessonsFilterByInstrument(InstrumentType.zampona));

        final state =
            await bloc.stream.firstWhere(
                  (s) =>
                      s is LessonsLoaded &&
                      s.activeInstrument == InstrumentType.zampona,
                )
                as LessonsLoaded;

        expect(state.lessons.length, 1);
        expect(state.lessons.first.id, 'l_zampona_1');
        expect(state.lessons.first.instrument, 'zampona');
        expect(state.activeInstrument, InstrumentType.zampona);
        expect(state.nextLesson?.id, 'l_zampona_1');
      },
    );

    test(
      'switching to Quena updates filtered lessons and nextLesson path',
      () async {
        bloc.add(const LessonsLoadCategories());
        await bloc.stream.firstWhere((s) => s is LessonsLoaded);

        bloc.add(const LessonsFilterByInstrument(InstrumentType.quena));

        final state =
            await bloc.stream.firstWhere(
                  (s) =>
                      s is LessonsLoaded &&
                      s.activeInstrument == InstrumentType.quena,
                )
                as LessonsLoaded;

        expect(state.lessons.length, 1);
        expect(state.lessons.first.id, 'l_quena_1');
        expect(state.lessons.first.instrument, 'quena');
        expect(state.activeInstrument, InstrumentType.quena);
        expect(state.nextLesson?.id, 'l_quena_1');
      },
    );

    test('switching to Tarka updates filtered lessons', () async {
      bloc.add(const LessonsLoadCategories());
      await bloc.stream.firstWhere((s) => s is LessonsLoaded);

      bloc.add(const LessonsFilterByInstrument(InstrumentType.tarka));

      final state =
          await bloc.stream.firstWhere(
                (s) =>
                    s is LessonsLoaded &&
                    s.activeInstrument == InstrumentType.tarka,
              )
              as LessonsLoaded;

      expect(state.lessons.length, 1);
      expect(state.lessons.first.id, 'l_tarka_1');
      expect(state.lessons.first.instrument, 'tarka');
      expect(state.activeInstrument, InstrumentType.tarka);
    });

    test('reloading categories preserves active instrument filter', () async {
      bloc.add(const LessonsFilterByInstrument(InstrumentType.zampona));
      bloc.add(const LessonsLoadCategories());

      final state =
          await bloc.stream.firstWhere(
                (s) =>
                    s is LessonsLoaded &&
                    s.activeInstrument == InstrumentType.zampona,
              )
              as LessonsLoaded;

      expect(fakeRepo.lastRequestedInstrument, 'zampona');
      expect(state.lessons.length, 1);
      expect(state.lessons.first.instrument, 'zampona');
    });
  });
}
