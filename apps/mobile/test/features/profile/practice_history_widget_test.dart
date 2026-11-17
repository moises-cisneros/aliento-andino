import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/connectivity/connectivity_service.dart';
import 'package:mobile/features/lessons/data/repositories/practice_repository.dart';
import 'package:mobile/features/profile/presentation/screens/practice_history_screen.dart';
import 'package:mobile/features/profile/presentation/widgets/accuracy_trend_chart.dart';
import 'package:mocktail/mocktail.dart';

import 'practice_history_test_helpers.dart';

class MockPracticeRepository extends Mock implements PracticeRepository {}

Widget _app(PracticeRepository repo) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const PracticeHistoryScreen()),
      GoRoute(
        path: '/lessons',
        builder: (_, _) => const Scaffold(body: Text('LECCIONES')),
      ),
    ],
  );
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<PracticeRepository>.value(value: repo),
      RepositoryProvider<ConnectivityService>.value(
        value: _OnlineConnectivity(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _OnlineConnectivity extends Fake implements ConnectivityService {
  @override
  Stream<bool> get statusStream => Stream<bool>.value(true);
}

void main() {
  late MockPracticeRepository repo;

  setUp(() {
    repo = MockPracticeRepository();
  });

  void stubFirstPage(Map<String, dynamic> result) {
    when(
      () => repo.getPracticeHistory(page: 1, size: 20, offlineFallback: false),
    ).thenAnswer((_) async => result);
  }

  group('buildWeeklyAccuracy', () {
    test('agrupa por semana (lunes) y promedia, en orden cronologico', () {
      final points = buildWeeklyAccuracy([
        historySession('a', score: 60, createdAt: '2026-11-12T12:00:00'),
        historySession('b', score: 100, createdAt: '2026-11-10T12:00:00'),
        historySession('c', score: 90, createdAt: '2026-11-01T12:00:00'),
      ]);

      expect(points.length, 2);
      expect(points[0].weekStart, DateTime(2026, 10, 26));
      expect(points[0].average, 90);
      expect(points[1].weekStart, DateTime(2026, 11, 9));
      expect(points[1].average, 80);
      expect(points[1].sessions, 2);
    });

    test('ignora sesiones sin fecha valida', () {
      final points = buildWeeklyAccuracy([
        historySession('a', createdAt: null),
        historySession('b', createdAt: 'no-es-fecha'),
      ]);
      expect(points, isEmpty);
    });
  });

  group('PracticeHistoryScreen [SUB-10-A]', () {
    testWidgets('renderiza lista (fecha, %, badge) y la grafica', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      stubFirstPage(
        historyPage([
          historySession(
            'a',
            score: 92.4,
            createdAt: '2026-11-12T12:00:00',
            instrument: 'zampona',
            title: 'Marcha Andina',
          ),
          historySession(
            'b',
            score: 55,
            createdAt: '2026-11-02T12:00:00',
            instrument: 'quena',
          ),
        ]),
      );

      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.text('Marcha Andina'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('55%'), findsOneWidget);
      expect(find.text('12/11/2026'), findsOneWidget);
      expect(find.text('Zampoña'), findsOneWidget);
      expect(find.text('Quena'), findsOneWidget);
      expect(find.byType(AccuracyTrendChart), findsOneWidget);
      expect(find.byKey(const Key('accuracy_chart_canvas')), findsOneWidget);
    });

    testWidgets('historial vacio muestra estado pedagogico con CTA', (
      tester,
    ) async {
      stubFirstPage(historyPage([]));

      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Aún no has completado prácticas. ¡Comienza hoy con tu Quena!',
        ),
        findsOneWidget,
      );
      expect(find.byType(AccuracyTrendChart), findsNothing);

      await tester.tap(find.byKey(const Key('history_empty_cta')));
      await tester.pumpAndSettle();
      expect(find.text('LECCIONES'), findsOneWidget);
    });

    testWidgets('con una sola semana la grafica pide mas datos', (
      tester,
    ) async {
      stubFirstPage(historyPage([historySession('a')]));

      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('accuracy_chart_placeholder')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('accuracy_chart_canvas')), findsNothing);
    });

    testWidgets('error muestra la causa y permite reintentar', (tester) async {
      var calls = 0;
      when(
        () =>
            repo.getPracticeHistory(page: 1, size: 20, offlineFallback: false),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('Servidor caído');
        return historyPage([historySession('a')]);
      });

      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(find.text('Servidor caído'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Escala de Re'), findsOneWidget);
    });
  });
}
