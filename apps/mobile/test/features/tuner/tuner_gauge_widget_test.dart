import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/tuner/presentation/widgets/tuner_gauge_widget.dart';

void main() {
  group('TunerGaugeWidget [SUB-01-B]', () {
    testWidgets('renderiza nota, estado AFINADO y frecuencia en Hz', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TunerGaugeWidget(
              cents: 2.5,
              frequencyHz: 392.5,
              noteName: 'Sol4',
              isTuned: true,
              isSilent: false,
              toleranceCents: 15.0,
            ),
          ),
        ),
      );

      expect(find.text('Sol4'), findsOneWidget);
      expect(find.text('AFINADO'), findsOneWidget);
      expect(find.textContaining('392.5 Hz'), findsOneWidget);
    });

    testWidgets('muestra CALADO (GRAVE) cuando cents < -15', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TunerGaugeWidget(
              cents: -30.0,
              frequencyHz: 385.0,
              noteName: 'Sol4',
              isTuned: false,
              isSilent: false,
              toleranceCents: 15.0,
            ),
          ),
        ),
      );

      expect(find.text('CALADO (GRAVE)'), findsOneWidget);
    });

    testWidgets('muestra ALTO (AGUDO) cuando cents > +15', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TunerGaugeWidget(
              cents: 28.0,
              frequencyHz: 398.0,
              noteName: 'Sol4',
              isTuned: false,
              isSilent: false,
              toleranceCents: 15.0,
            ),
          ),
        ),
      );

      expect(find.text('ALTO (AGUDO)'), findsOneWidget);
    });

    testWidgets('muestra ESCUCHANDO... en estado de silencio', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TunerGaugeWidget(
              cents: 0.0,
              frequencyHz: 0.0,
              noteName: '--',
              isTuned: false,
              isSilent: true,
            ),
          ),
        ),
      );

      expect(find.text('--'), findsOneWidget);
      expect(find.text('ESCUCHANDO...'), findsOneWidget);
    });
  });
}
