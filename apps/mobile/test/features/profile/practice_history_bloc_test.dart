import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lessons/data/repositories/practice_repository.dart';
import 'package:mobile/features/profile/presentation/bloc/practice_history_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'practice_history_test_helpers.dart';

class MockPracticeRepository extends Mock implements PracticeRepository {}

void main() {
  late MockPracticeRepository repo;

  setUp(() {
    repo = MockPracticeRepository();
  });

  void stubPage(int page, Map<String, dynamic> result) {
    when(
      () => repo.getPracticeHistory(
        page: page,
        size: PracticeHistoryBloc.pageSize,
        offlineFallback: false,
      ),
    ).thenAnswer((_) async => result);
  }

  Future<void> loadThenNext(PracticeHistoryBloc b) async {
    b.add(const PracticeHistoryLoadRequested());
    await b.stream.firstWhere((s) => s.status == PracticeHistoryStatus.loaded);
    b.add(const PracticeHistoryNextPageRequested());
  }

  group('PracticeHistoryBloc [SUB-10-A]', () {
    blocTest<PracticeHistoryBloc, PracticeHistoryState>(
      'carga la primera pagina y marca hasMore',
      build: () {
        stubPage(1, historyPage([historySession('a')], pages: 2));
        return PracticeHistoryBloc(practiceRepository: repo);
      },
      act: (b) => b.add(const PracticeHistoryLoadRequested()),
      expect: () => [
        const PracticeHistoryState(status: PracticeHistoryStatus.loading),
        isA<PracticeHistoryState>()
            .having((s) => s.status, 'status', PracticeHistoryStatus.loaded)
            .having((s) => s.items.single.id, 'item', 'a')
            .having((s) => s.page, 'page', 1)
            .having((s) => s.hasMore, 'hasMore', true),
      ],
      verify: (_) => verify(
        () =>
            repo.getPracticeHistory(page: 1, size: 20, offlineFallback: false),
      ).called(1),
    );

    blocTest<PracticeHistoryBloc, PracticeHistoryState>(
      'historial vacio queda en loaded con isEmpty',
      build: () {
        stubPage(1, historyPage([]));
        return PracticeHistoryBloc(practiceRepository: repo);
      },
      act: (b) => b.add(const PracticeHistoryLoadRequested()),
      verify: (b) {
        expect(b.state.status, PracticeHistoryStatus.loaded);
        expect(b.state.isEmpty, isTrue);
        expect(b.state.hasMore, isFalse);
      },
    );

    blocTest<PracticeHistoryBloc, PracticeHistoryState>(
      'siguiente pagina agrega al final y conserva el orden',
      build: () {
        stubPage(1, historyPage([historySession('a')], pages: 2));
        stubPage(2, historyPage([historySession('b')], page: 2, pages: 2));
        return PracticeHistoryBloc(practiceRepository: repo);
      },
      act: loadThenNext,
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.items.map((e) => e.id), ['a', 'b']);
        expect(b.state.page, 2);
        expect(b.state.hasMore, isFalse);
        expect(b.state.loadingMore, isFalse);
      },
    );

    blocTest<PracticeHistoryBloc, PracticeHistoryState>(
      'no pide mas paginas cuando ya no hay',
      build: () {
        stubPage(1, historyPage([historySession('a')]));
        return PracticeHistoryBloc(practiceRepository: repo);
      },
      act: loadThenNext,
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verifyNever(
          () => repo.getPracticeHistory(
            page: 2,
            size: any(named: 'size'),
            offlineFallback: any(named: 'offlineFallback'),
          ),
        );
      },
    );

    blocTest<PracticeHistoryBloc, PracticeHistoryState>(
      'error de red muestra la causa real y no un historial vacio',
      build: () {
        when(
          () => repo.getPracticeHistory(
            page: 1,
            size: 20,
            offlineFallback: false,
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/v1/practice/history'),
            type: DioExceptionType.connectionError,
          ),
        );
        return PracticeHistoryBloc(practiceRepository: repo);
      },
      act: (b) => b.add(const PracticeHistoryLoadRequested()),
      verify: (b) {
        expect(b.state.status, PracticeHistoryStatus.failure);
        expect(b.state.error, isNotNull);
        expect(b.state.isEmpty, isFalse);
      },
    );

    blocTest<PracticeHistoryBloc, PracticeHistoryState>(
      'fallo al paginar conserva lo ya cargado',
      build: () {
        stubPage(1, historyPage([historySession('a')], pages: 2));
        when(
          () => repo.getPracticeHistory(
            page: 2,
            size: 20,
            offlineFallback: false,
          ),
        ).thenThrow(Exception('boom'));
        return PracticeHistoryBloc(practiceRepository: repo);
      },
      act: loadThenNext,
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.status, PracticeHistoryStatus.loaded);
        expect(b.state.items.map((e) => e.id), ['a']);
        expect(b.state.error, 'boom');
        expect(b.state.loadingMore, isFalse);
      },
    );
  });
}
