import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/rankings/data/models/leaderboard_model.dart';
import 'package:mobile/features/rankings/data/repositories/ranking_repository.dart';
import 'package:mobile/features/rankings/presentation/bloc/leaderboard/leaderboard_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockRankingRepository extends Mock implements RankingRepository {}

LeaderboardEntryModel _entry(int rank, String name, int xp) =>
    LeaderboardEntryModel(
      rank: rank,
      userId: 'id-$name',
      username: name,
      fullName: name,
      xp: xp,
    );

void main() {
  late _MockRankingRepository repo;

  setUp(() => repo = _MockRankingRepository());

  group('LeaderboardModel.fromJson [SUB-12-B]', () {
    test('parsea items y user_rank nulo', () {
      final model = LeaderboardModel.fromJson({
        'items': [
          {
            'rank': 1,
            'user_id': 'u1',
            'username': 'ana',
            'full_name': 'Ana',
            'avatar_url': null,
            'xp': 75,
          },
        ],
        'user_rank': null,
      });

      expect(model.items.single.xp, 75);
      expect(model.userRank, isNull);
    });
  });

  group('LeaderboardBloc [SUB-12-B]', () {
    blocTest<LeaderboardBloc, LeaderboardState>(
      'carga el ranking del instrumento seleccionado',
      build: () {
        when(() => repo.getInstrumentLeaderboard('quena')).thenAnswer(
          (_) async =>
              LeaderboardModel(items: [_entry(1, 'ana', 75)], userRank: 1),
        );
        return LeaderboardBloc(rankingRepository: repo);
      },
      act: (bloc) =>
          bloc.add(const LeaderboardInstrumentSelected(InstrumentType.quena)),
      expect: () => [
        const LeaderboardState(
          status: LeaderboardStatus.loading,
          instrument: InstrumentType.quena,
        ),
        LeaderboardState(
          status: LeaderboardStatus.success,
          instrument: InstrumentType.quena,
          items: [_entry(1, 'ana', 75)],
          userRank: 1,
        ),
      ],
    );

    blocTest<LeaderboardBloc, LeaderboardState>(
      'usuario sin prácticas: userRank null ("Sin clasificar")',
      build: () {
        when(
          () => repo.getInstrumentLeaderboard('tarka'),
        ).thenAnswer((_) async => const LeaderboardModel(items: []));
        return LeaderboardBloc(rankingRepository: repo);
      },
      act: (bloc) =>
          bloc.add(const LeaderboardInstrumentSelected(InstrumentType.tarka)),
      verify: (bloc) {
        expect(bloc.state.status, LeaderboardStatus.success);
        expect(bloc.state.userRank, isNull);
      },
    );

    blocTest<LeaderboardBloc, LeaderboardState>(
      'error de red: failure con el mensaje real, sin datos inventados',
      build: () {
        when(() => repo.getInstrumentLeaderboard('quena')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.badResponse,
          ),
        );
        return LeaderboardBloc(rankingRepository: repo);
      },
      act: (bloc) =>
          bloc.add(const LeaderboardInstrumentSelected(InstrumentType.quena)),
      verify: (bloc) {
        expect(bloc.state.status, LeaderboardStatus.failure);
        expect(bloc.state.items, isEmpty);
        expect(bloc.state.message, contains('Quena'));
      },
    );

    test('descarta la respuesta tardía del instrumento anterior', () async {
      final slowQuena = Completer<LeaderboardModel>();
      when(
        () => repo.getInstrumentLeaderboard('quena'),
      ).thenAnswer((_) => slowQuena.future);
      when(() => repo.getInstrumentLeaderboard('zampona')).thenAnswer(
        (_) async =>
            LeaderboardModel(items: [_entry(1, 'zamp', 10)], userRank: 1),
      );
      final bloc = LeaderboardBloc(rankingRepository: repo);
      addTearDown(bloc.close);

      bloc.add(const LeaderboardInstrumentSelected(InstrumentType.quena));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LeaderboardInstrumentSelected(InstrumentType.zampona));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      slowQuena.complete(
        LeaderboardModel(items: [_entry(1, 'quena-user', 99)], userRank: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.instrument, InstrumentType.zampona);
      expect(bloc.state.items.single.username, 'zamp');
    });

    blocTest<LeaderboardBloc, LeaderboardState>(
      'refrescar recarga el instrumento actual',
      build: () {
        when(
          () => repo.getInstrumentLeaderboard('zampona'),
        ).thenAnswer((_) async => const LeaderboardModel(items: []));
        return LeaderboardBloc(
          rankingRepository: repo,
          initialInstrument: InstrumentType.zampona,
        );
      },
      act: (bloc) => bloc.add(const LeaderboardRefreshed()),
      verify: (_) =>
          verify(() => repo.getInstrumentLeaderboard('zampona')).called(1),
    );
  });
}
