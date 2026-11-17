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
