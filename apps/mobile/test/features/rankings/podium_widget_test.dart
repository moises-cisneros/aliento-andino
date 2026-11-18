import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/rankings/data/models/ranking_entry_model.dart';
import 'package:mobile/features/rankings/presentation/widgets/podium_widget.dart';

RankingEntryModel _mockEntry({
  required int rank,
  required String username,
  required String fullName,
  required int xp,
}) {
  return RankingEntryModel(
    rank: rank,
    userId: 'user_$rank',
    username: username,
    fullName: fullName,
    xp: xp,
    weeklyXp: xp,
    totalXp: xp,
    level: 5,
  );
}

void main() {
  group(
    'PodiumWidget - Integración y Visualización de Medallas (SUB-12-B)',
    () {
      testWidgets(
        'Muestra podio de 3 columnas con medallas oficiales 1°, 2° y 3°',
        (tester) async {
          final entries = [
            _mockEntry(
              rank: 1,
              username: 'ana_quena',
              fullName: 'Ana Quena',
              xp: 850,
            ),
            _mockEntry(
              rank: 2,
              username: 'carlos_zam',
              fullName: 'Carlos Zampoña',
              xp: 620,
            ),
            _mockEntry(
              rank: 3,
              username: 'elena_tar',
              fullName: 'Elena Tarka',
              xp: 410,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(body: PodiumWidget(entries: entries)),
            ),
          );

          // Esperar a que la animación de altura concluya
          await tester.pumpAndSettle();

          // Verificar que se rendericen los nombres
          expect(find.text('Ana Quena'), findsOneWidget);
          expect(find.text('Carlos Zampoña'), findsOneWidget);
          expect(find.text('Elena Tarka'), findsOneWidget);

          // Verificar las etiquetas de medalla oficial
          expect(find.text('1°'), findsOneWidget);
          expect(find.text('2°'), findsOneWidget);
          expect(find.text('3°'), findsOneWidget);

          // Verificar los números de pedestal
          expect(find.text('#1'), findsOneWidget);
          expect(find.text('#2'), findsOneWidget);
          expect(find.text('#3'), findsOneWidget);

          // Verificar los XP de cada posición
          expect(find.text('850 XP'), findsOneWidget);
          expect(find.text('620 XP'), findsOneWidget);
          expect(find.text('410 XP'), findsOneWidget);

          // Verificar presencia de la corona para el ganador #1
          expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
        },
      );

      testWidgets('Maneja lista vacía mostrando mensaje amigable', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: PodiumWidget(entries: [])),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Sin intérpretes en el podio aún esta semana'),
          findsOneWidget,
        );
      });

      testWidgets('Maneja 1 solo intérprete posicionándolo en el centro (1°)', (
        tester,
      ) async {
        final entries = [
          _mockEntry(
            rank: 1,
            username: 'solista',
            fullName: 'Solista Andino',
            xp: 300,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: PodiumWidget(entries: entries)),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Solista Andino'), findsOneWidget);
        expect(find.text('1°'), findsOneWidget);
        expect(find.text('300 XP'), findsOneWidget);
        // Las otras dos columnas deben mostrar placeholder '—'
        expect(find.text('—'), findsNWidgets(2));
      });
    },
  );
}
