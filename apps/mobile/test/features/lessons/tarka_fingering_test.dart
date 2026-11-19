import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/fingering_models.dart';
import 'package:mobile/features/lessons/presentation/widgets/instruments/tarka_fingering_widget.dart';

void main() {
  group('TarkaFingering', () {
    test('maps Do5, Re5, Mi5, Sol5 to covered holes', () {
      expect(
        TarkaFingering.forNote('C5')!.holesCovered.where((c) => c).length,
        6,
      );
      expect(
        TarkaFingering.forNote('Re5')!.holesCovered.where((c) => c).length,
        5,
      );
      expect(
        TarkaFingering.forNote('E5')!.holesCovered.where((c) => c).length,
        4,
      );
      expect(
        TarkaFingering.forNote('Sol5')!.holesCovered.where((c) => c).length,
        2,
      );
    });

    test('supports Do6 (tara) and Re6 overblown harmonics (Issue #149)', () {
      // Do6: sobre-soplo tara con los 6 orificios cubiertos
      final do6 = TarkaFingering.forNote('Do6')!;
      expect(do6.holesCovered.every((h) => h), isTrue);

      final c6 = TarkaFingering.forNote('C6')!;
      expect(c6.holesCovered.every((h) => h), isTrue);

      // Re6: sobre-soplo con 5 orificios cubiertos
      final re6 = TarkaFingering.forNote('Re6')!;
      expect(re6.holesCovered.where((h) => h).length, 5);

      final d6 = TarkaFingering.forNote('D6')!;
      expect(d6.holesCovered.where((h) => h).length, 5);
    });

    test('returns null for notes outside the scale', () {
      expect(TarkaFingering.forNote('C#5'), isNull);
      expect(TarkaFingering.forNote('C3'), isNull);
    });

    test('asserts a list length of exactly 6', () {
      expect(() => TarkaFingering([true, false]), throwsAssertionError);
      expect(() => TarkaFingering(List.filled(7, true)), throwsAssertionError);
    });
  });

  group('TarkaFingeringWidget', () {
    testWidgets(
      'renders 6 holes with 48px targets and covered ones highlighted',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: TarkaFingeringWidget(note: 'Re5')),
          ),
        );
        for (var i = 1; i <= 6; i++) {
          final size = tester.getSize(find.byKey(Key('tarka-hole-$i')));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        expect(find.bySemanticsLabel('Hole covered'), findsNWidgets(5));
        expect(find.bySemanticsLabel('Hole open'), findsOneWidget);
      },
    );

    testWidgets('shows a notice for notes outside the scale', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TarkaFingeringWidget(note: 'C3')),
        ),
      );
      expect(find.byKey(const Key('tarka-out-of-range')), findsOneWidget);
    });
  });
}
