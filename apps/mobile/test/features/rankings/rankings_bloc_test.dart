import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/features/rankings/data/models/ranking_entry_model.dart';
import 'package:mobile/features/rankings/data/repositories/ranking_repository.dart';
import 'package:mobile/features/rankings/presentation/bloc/rankings/rankings_bloc.dart';
import 'package:mobile/features/rankings/presentation/bloc/rankings/rankings_event.dart';
import 'package:mobile/features/rankings/presentation/bloc/rankings/rankings_state.dart';

class MockRankingRepository extends Mock implements RankingRepository {}

RankingEntryModel _entry({
  required int rank,
  required String id,
  required String username,
  required int xp,
  String instrument = 'quena',
}) {
  return RankingEntryModel(
    rank: rank,
    userId: id,
    username: username,
    fullName: 'Usuario $username',
    xp: xp,
    weeklyXp: xp,
    totalXp: xp,
    level: 3,
    instrument: instrument,
  );
}

void main() {
  late MockRankingRepository repo;

  setUp(() {
    repo = MockRankingRepository();
  });

  group('RankingsBloc - Instrument Leaderboard (HU-12 / SUB-12-B)', () {
    test('Estado inicial es RankingsInitial', () {
      final bloc = RankingsBloc(rankingRepository: repo);
      expect(bloc.state, isA<RankingsInitial>());
      bloc.close();
    });

    blocTest<RankingsBloc, RankingsState>(
      'Carga leaderboard por instrumento exitosamente con userRank clasificado',
      setUp: () {
        when(
          () => repo.getInstrumentLeaderboard(
            instrument: 'quena',
            scope: 'weekly',
          ),
        ).thenAnswer(
          (_) async => LeaderboardModel(
            items: [
              _entry(rank: 1, id: 'u1', username: 'ana', xp: 500),
              _entry(rank: 2, id: 'u2', username: 'juan', xp: 400),
              _entry(rank: 3, id: 'u3', username: 'carlos', xp: 300),
            ],
            userRank: 2,
            instrument: 'quena',
            scope: 'weekly',
          ),
        );
      },
      build: () => RankingsBloc(rankingRepository: repo),
      act: (bloc) => bloc.add(
        RankingsLoadInstrumentLeaderboard(instrument: 'quena', scope: 'weekly'),
      ),
      expect: () => [
        isA<RankingsLoading>(),
        isA<InstrumentLeaderboardLoaded>()
            .having((s) => s.items.length, 'items.length', 3)
            .having((s) => s.userRank, 'userRank', 2)
            .having((s) => s.selectedInstrument, 'selectedInstrument', 'quena')
            .having((s) => s.scope, 'scope', 'weekly'),
      ],
      verify: (_) {
        verify(
          () => repo.getInstrumentLeaderboard(
            instrument: 'quena',
            scope: 'weekly',
          ),
        ).called(1);
      },
    );

    blocTest<RankingsBloc, RankingsState>(
      'Carga leaderboard con userRank == null cuando el usuario no tiene prácticas (Sin clasificar)',
      setUp: () {
        when(
          () => repo.getInstrumentLeaderboard(
            instrument: 'zampona',
            scope: 'weekly',
          ),
        ).thenAnswer(
          (_) async => LeaderboardModel(
            items: [
              _entry(
                rank: 1,
                id: 'u1',
                username: 'rosa',
                xp: 650,
                instrument: 'zampona',
              ),
            ],
            userRank: null,
            instrument: 'zampona',
            scope: 'weekly',
          ),
        );
      },
      build: () => RankingsBloc(rankingRepository: repo),
      act: (bloc) => bloc.add(
        RankingsLoadInstrumentLeaderboard(
          instrument: 'zampona',
          scope: 'weekly',
        ),
      ),
      expect: () => [
        isA<RankingsLoading>(),
        isA<InstrumentLeaderboardLoaded>()
            .having((s) => s.items.length, 'items.length', 1)
            .having((s) => s.userRank, 'userRank', isNull)
            .having(
              (s) => s.selectedInstrument,
              'selectedInstrument',
              'zampona',
            ),
      ],
      verify: (_) {
        verify(
          () => repo.getInstrumentLeaderboard(
            instrument: 'zampona',
            scope: 'weekly',
          ),
        ).called(1);
      },
    );

    blocTest<RankingsBloc, RankingsState>(
      'Emite RankingsError cuando la solicitud a la API falla',
      setUp: () {
        when(
          () => repo.getInstrumentLeaderboard(
            instrument: any(named: 'instrument'),
            scope: any(named: 'scope'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/v1/rankings/leaderboard'),
            type: DioExceptionType.badResponse,
          ),
        );
      },
      build: () => RankingsBloc(rankingRepository: repo),
      act: (bloc) => bloc.add(
        RankingsLoadInstrumentLeaderboard(instrument: 'tarka', scope: 'weekly'),
      ),
      expect: () => [
        isA<RankingsLoading>(),
        isA<RankingsError>().having(
          (s) => s.message,
          'message',
          'Error al cargar leaderboard por instrumento',
        ),
      ],
    );

    blocTest<RankingsBloc, RankingsState>(
      'Carga ranking semanal general exitosamente',
      setUp: () {
        when(() => repo.getWeeklyLeaderboard()).thenAnswer(
          (_) async => {
            'leaderboard': [
              _entry(rank: 1, id: 'u1', username: 'ana', xp: 400),
            ],
            'my_rank': 1,
            'my_weekly_xp': 400,
            'days_remaining': 4,
          },
        );
      },
      build: () => RankingsBloc(rankingRepository: repo),
      act: (bloc) => bloc.add(RankingsLoadWeekly()),
      expect: () => [
        isA<RankingsLoading>(),
        isA<RankingsLoaded>()
            .having((s) => s.leaderboard.length, 'leaderboard.length', 1)
            .having((s) => s.myRank, 'myRank', 1)
            .having((s) => s.daysRemaining, 'daysRemaining', 4),
      ],
    );
  });
}
