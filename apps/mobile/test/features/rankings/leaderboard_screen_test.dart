import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/rankings/data/models/leaderboard_model.dart';
import 'package:mobile/features/rankings/data/repositories/ranking_repository.dart';
import 'package:mobile/features/rankings/presentation/screens/leaderboard_screen.dart';
import 'package:mobile/features/rankings/presentation/widgets/podium_widget.dart';
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

Widget _app(RankingRepository repo) => MaterialApp(
  home: RepositoryProvider<RankingRepository>.value(
    value: repo,
    child: const LeaderboardScreen(),
  ),
);

void main() {
  group('PodiumWidget [SUB-12-B]', () {
    testWidgets('muestra 3 columnas con medallas oficiales oro/plata/bronce', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodiumWidget(
              entries: [
                _entry(1, 'ana', 300),
                _entry(2, 'beto', 200),
                _entry(3, 'caro', 100),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Color colorOf(int position) {
        final box = tester.widget<Container>(
          find.byKey(Key('podium-bar-$position')),
        );
        return (box.decoration! as BoxDecoration).color!;
      }

      expect(colorOf(1), AppTheme.gold);
      expect(colorOf(2), AppTheme.silver);
      expect(colorOf(3), AppTheme.bronze);
      expect(AppTheme.gold, const Color(0xFFFFD700));
      expect(AppTheme.silver, const Color(0xFFC0C0C0));
      expect(AppTheme.bronze, const Color(0xFFCD7F32));
      expect(find.text('ana'), findsOneWidget);
      expect(find.text('300 XP'), findsOneWidget);
    });

    testWidgets('las columnas crecen animadas desde cero', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PodiumWidget(entries: [_entry(1, 'ana', 300)])),
        ),
      );
      Size goldSize() => tester.getSize(find.byKey(const Key('podium-bar-1')));

      final start = goldSize().height;
      await tester.pump(const Duration(milliseconds: 300));
      final mid = goldSize().height;
      await tester.pumpAndSettle();
      final end = goldSize().height;

      expect(start, lessThan(mid));
      expect(mid, lessThan(end));
    });

    testWidgets('con menos de 3 usuarios los puestos vacíos no rompen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PodiumWidget(entries: [_entry(1, 'ana', 50)])),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('podium-column-2')), findsOneWidget);
      expect(find.byKey(const Key('podium-column-3')), findsOneWidget);
      expect(find.text('ana'), findsOneWidget);
    });
  });

  group('LeaderboardScreen [SUB-12-B]', () {
    late _MockRankingRepository repo;

    setUp(() {
      repo = _MockRankingRepository();
      when(() => repo.getInstrumentLeaderboard('quena')).thenAnswer(
        (_) async => LeaderboardModel(
          items: [
            _entry(1, 'quenista', 300),
            _entry(2, 'q2', 200),
            _entry(3, 'q3', 100),
            _entry(4, 'q4', 50),
          ],
          userRank: 4,
        ),
      );
      when(() => repo.getInstrumentLeaderboard('zampona')).thenAnswer(
        (_) async => LeaderboardModel(
          items: [_entry(1, 'zampoñista', 999)],
          userRank: null,
        ),
      );
    });

    testWidgets('lista el resto desde el 4º y muestra la posición propia', (
      tester,
    ) async {
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('leaderboard-row-id-q4')), findsOneWidget);
      expect(find.byKey(const Key('leaderboard-row-id-q3')), findsNothing);
      expect(find.text('Tu posición: #4'), findsOneWidget);
    });

    testWidgets(
      'E2E: cambiar de tab Quena → Zampoña actualiza el podio y muestra '
      '"Sin clasificar" al pie',
      (tester) async {
        await tester.pumpWidget(_app(repo));
        await tester.pumpAndSettle();
        expect(find.text('quenista'), findsOneWidget);

        await tester.tap(find.byKey(const Key('leaderboard-tab-zampona')));
        await tester.pumpAndSettle();

        expect(find.text('quenista'), findsNothing);
        expect(find.text('zampoñista'), findsOneWidget);
        expect(find.text('999 XP'), findsOneWidget);
        expect(find.text('Tu posición: Sin clasificar'), findsOneWidget);
        verify(() => repo.getInstrumentLeaderboard('zampona')).called(1);
      },
    );

    testWidgets('sin datos muestra estado vacío, no ranking inventado', (
      tester,
    ) async {
      when(
        () => repo.getInstrumentLeaderboard('quena'),
      ).thenAnswer((_) async => const LeaderboardModel(items: []));
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('leaderboard-empty')), findsOneWidget);
      expect(find.byType(PodiumWidget), findsNothing);
    });

    testWidgets('error: muestra el mensaje y reintenta', (tester) async {
      when(
        () => repo.getInstrumentLeaderboard('quena'),
      ).thenThrow(Exception('boom'));
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('leaderboard-retry')), findsOneWidget);

      when(
        () => repo.getInstrumentLeaderboard('quena'),
      ).thenAnswer((_) async => LeaderboardModel(items: [_entry(1, 'ok', 1)]));
      await tester.tap(find.byKey(const Key('leaderboard-retry')));
      await tester.pumpAndSettle();

      expect(find.text('ok'), findsOneWidget);
    });
  });
}
