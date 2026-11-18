import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/core/connectivity/connectivity_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/rankings/data/models/ranking_entry_model.dart';
import 'package:mobile/features/rankings/data/repositories/ranking_repository.dart';
import 'package:mobile/features/rankings/presentation/screens/leaderboard_screen.dart';

class MockRankingRepository extends Mock implements RankingRepository {}

class _OnlineConnectivity extends Fake implements ConnectivityService {
  @override
  Stream<bool> get statusStream => Stream<bool>.value(true);
}

RankingEntryModel _entry({
  required int rank,
  required String id,
  required String username,
  required String fullName,
  required int xp,
  required String instrument,
}) {
  return RankingEntryModel(
    rank: rank,
    userId: id,
    username: username,
    fullName: fullName,
    xp: xp,
    weeklyXp: xp,
    totalXp: xp,
    level: 4,
    instrument: instrument,
  );
}

void main() {
  late MockRankingRepository repo;

  setUp(() {
    repo = MockRankingRepository();
  });

  group('LeaderboardScreen E2E - Tabs por Instrumento y Podio Reactivo (SUB-12-B)', () {
    testWidgets(
      'Cambio de tab de Quena a Zampoña actualiza el podio reactivamente y maneja "Sin clasificar"',
      (tester) async {
        tester.view.physicalSize = const Size(440 * 3, 950 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        // Mock data para Quena: usuario clasificado en puesto 2
        final quenaLeaderboard = LeaderboardModel(
          items: [
            _entry(
              rank: 1,
              id: 'q1',
              username: 'elena_quena',
              fullName: 'Elena Quena',
              xp: 900,
              instrument: 'quena',
            ),
            _entry(
              rank: 2,
              id: 'q2',
              username: 'mi_usuario',
              fullName: 'Mi Usuario',
              xp: 750,
              instrument: 'quena',
            ),
            _entry(
              rank: 3,
              id: 'q3',
              username: 'marco_q',
              fullName: 'Marco Quenista',
              xp: 500,
              instrument: 'quena',
            ),
            _entry(
              rank: 4,
              id: 'q4',
              username: 'pedro_q',
              fullName: 'Pedro Quenista',
              xp: 350,
              instrument: 'quena',
            ),
          ],
          userRank: 2,
          instrument: 'quena',
          scope: 'weekly',
        );

        // Mock data para Zampoña: podio distinto, y usuario sin prácticas (userRank == null)
        final zamponaLeaderboard = LeaderboardModel(
          items: [
            _entry(
              rank: 1,
              id: 'z1',
              username: 'walter_zam',
              fullName: 'Walter Zampoñista',
              xp: 1200,
              instrument: 'zampona',
            ),
            _entry(
              rank: 2,
              id: 'z2',
              username: 'sofia_zam',
              fullName: 'Sofía Zampoña',
              xp: 980,
              instrument: 'zampona',
            ),
            _entry(
              rank: 3,
              id: 'z3',
              username: 'raul_zam',
              fullName: 'Raúl Siku',
              xp: 800,
              instrument: 'zampona',
            ),
          ],
          userRank: null, // Sin clasificar en Zampoña
          instrument: 'zampona',
          scope: 'weekly',
        );

        when(
          () => repo.getInstrumentLeaderboard(
            instrument: 'quena',
            scope: 'weekly',
          ),
        ).thenAnswer((_) async => quenaLeaderboard);

        when(
          () => repo.getInstrumentLeaderboard(
            instrument: 'zampona',
            scope: 'weekly',
          ),
        ).thenAnswer((_) async => zamponaLeaderboard);

        // Renderizar la pantalla dentro de MultiRepositoryProvider y MaterialApp
        await tester.pumpWidget(
          MultiRepositoryProvider(
            providers: [
              RepositoryProvider<RankingRepository>.value(value: repo),
              RepositoryProvider<ConnectivityService>.value(
                value: _OnlineConnectivity(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const LeaderboardScreen(initialInstrument: 'quena'),
            ),
          ),
        );

        // Esperar la carga inicial de Quena
        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Verificar datos iniciales de Quena en el podio
        expect(find.text('Elena Quena'), findsOneWidget);
        expect(find.text('Marco Quenista'), findsOneWidget);
        expect(find.text('900 XP'), findsOneWidget);

        // Verificar 4ta posición en la lista
        expect(find.text('Pedro Quenista'), findsOneWidget);

        // Verificar el footer fijo con posición del usuario clasificado (#2)
        expect(find.text('Tu posición: #2'), findsOneWidget);
        expect(find.text('750 XP esta semana'), findsOneWidget);

        // 2. Tocar la pestaña "Zampoña" (E2E cambio interactivo)
        final zamponaTab = find.byKey(const Key('tab_instrument_zampona'));
        expect(zamponaTab, findsOneWidget);
        await tester.tap(zamponaTab);

        // Avanzar el reloj para completar la carga y animaciones
        await tester.pump();
        await tester.pumpAndSettle();

        // 3. Verificar que el podio se actualizó reactivamente con intérpretes de Zampoña
        expect(find.text('Walter Zampoñista'), findsOneWidget);
        expect(find.text('Sofía Zampoña'), findsOneWidget);
        expect(find.text('Raúl Siku'), findsOneWidget);
        expect(find.text('1200 XP'), findsOneWidget);

        // Elena Quena ya no debe estar en el podio
        expect(find.text('Elena Quena'), findsNothing);

        // 4. Verificar manejo de usuario sin prácticas en Zampoña:
        // Debe mostrar "Tu posición: Sin clasificar" en el footer fijo
        expect(find.text('Tu posición: Sin clasificar'), findsOneWidget);
        expect(
          find.text('Sin prácticas esta semana en Zampoña'),
          findsOneWidget,
        );

        // Verificar que el repositorio fue consultado para ambos instrumentos
        verify(
          () => repo.getInstrumentLeaderboard(
            instrument: 'quena',
            scope: 'weekly',
          ),
        ).called(1);
        verify(
          () => repo.getInstrumentLeaderboard(
            instrument: 'zampona',
            scope: 'weekly',
          ),
        ).called(1);
      },
    );
  });
}
