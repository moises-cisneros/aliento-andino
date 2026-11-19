import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/fingering_models.dart';
import 'package:mobile/features/lessons/presentation/widgets/instruments/quena_fingering_widget.dart';

void main() {
  group('QuenaFingering.forNote', () {
    test('maps Sol4 to all holes covered', () {
      final f = QuenaFingering.forNote('G4')!;
      expect([
        f.thumb,
        f.hole1,
        f.hole2,
        f.hole3,
        f.hole4,
        f.hole5,
        f.hole6,
      ], everyElement(isTrue));
    });

    test('maps La4, Si4, Do5 by opening holes from the bottom', () {
      final la = QuenaFingering.forNote('La4')!;
      expect([la.hole5, la.hole6], [true, false]);
      final si = QuenaFingering.forNote('B4')!;
      expect([si.hole4, si.hole5, si.hole6], [true, false, false]);
      final doo = QuenaFingering.forNote('C5')!;
      expect([doo.hole3, doo.hole4], [true, false]);
    });

    test('returns null below Sol4 and above Sol6', () {
      expect(QuenaFingering.forNote('F#4'), isNull);
      expect(QuenaFingering.forNote('G#6'), isNull);
      expect(QuenaFingering.forNote('nonsense'), isNull);
    });

    test('second octave half covers the thumb', () {
      final f = QuenaFingering.forNote('G5')!;
      expect(f.states[0], HoleState.half);
    });

    test(
      'second octave preserves half holes on altered notes (Issue #149)',
      () {
        // Sol#4 (G#4) has half hole on hole 6 (index 6)
        final gSharp4 = QuenaFingering.forNote('G#4')!;
        expect(gSharp4.halfHoles, contains(6));

        // Sol#5 (G#5) in 2nd octave must preserve hole 6 and include thumb (0)
        final gSharp5 = QuenaFingering.forNote('G#5')!;
        expect(gSharp5.halfHoles, containsAll({0, 6}));
        expect(gSharp5.states[0], HoleState.half);
        expect(gSharp5.states[6], HoleState.half);
      },
    );

    test('Sol6 maps to cross-fingering (T 0 2 3 0 0 0) (Issue #149)', () {
      final sol6 = QuenaFingering.forNote('Sol6')!;
      // Pulgar medio cubierto
      expect(sol6.states[0], HoleState.half);
      // Agujero 1 abierto
      expect(sol6.states[1], HoleState.open);
      // Agujeros 2 y 3 tapados
      expect(sol6.states[2], HoleState.covered);
      expect(sol6.states[3], HoleState.covered);
      // Agujeros 4, 5 y 6 abiertos
      expect(sol6.states[4], HoleState.open);
      expect(sol6.states[5], HoleState.open);
      expect(sol6.states[6], HoleState.open);
    });
  });

  group('QuenaFingeringWidget', () {
    testWidgets('renders 7 holes with at least 48px touch targets', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QuenaFingeringWidget(note: 'G4')),
        ),
      );
      for (var i = 1; i <= 6; i++) {
        final size = tester.getSize(find.byKey(Key('quena-hole-$i')));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(find.byKey(const Key('quena-hole-thumb')), findsOneWidget);
    });

    testWidgets('shows a notice for out-of-range notes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QuenaFingeringWidget(note: 'C3')),
        ),
      );
      expect(find.byKey(const Key('quena-out-of-range')), findsOneWidget);
    });
  });
}
