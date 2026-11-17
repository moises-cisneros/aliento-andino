import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/fingering_models.dart';
import 'package:mobile/features/lessons/presentation/widgets/instruments/zampona_fingering_widget.dart';

void main() {
  group('ZamponaFingering', () {
    test('maps diatonic notes to ira and arca tubes', () {
      final g4 = ZamponaFingering.forNote('G4')!;
      expect([g4.activeRow, g4.tubeIndex], ['ira', 1]);
      final a4 = ZamponaFingering.forNote('La4')!;
      expect([a4.activeRow, a4.tubeIndex], ['arca', 1]);
      final fs6 = ZamponaFingering.forNote('F#6')!;
      expect([fs6.activeRow, fs6.tubeIndex], ['arca', 7]);
    });

    test('returns null for notes the zampoña cannot play', () {
      expect(ZamponaFingering.forNote('C3'), isNull);
    });

    test('throws ArgumentError for out-of-range tube or invalid row', () {
      expect(() => ZamponaFingering('ira', 0, 'G4'), throwsArgumentError);
      expect(() => ZamponaFingering('ira', 7, 'G4'), throwsArgumentError);
      expect(() => ZamponaFingering('arca', 8, 'A4'), throwsArgumentError);
      expect(() => ZamponaFingering('x', 1, 'A4'), throwsArgumentError);
    });

    test('safe falls back to the first tube', () {
      final f = ZamponaFingering.safe('arca', 9, 'A4');
      expect([f.activeRow, f.tubeIndex], ['arca', 1]);
      expect(() => ZamponaFingering.safe('x', 1, 'A4'), throwsArgumentError);
    });
  });

  group('ZamponaFingeringWidget', () {
    testWidgets('renders 7 arca and 6 ira tubes, highlighting the active one', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ZamponaFingeringWidget(note: 'A4')),
        ),
      );
      for (var i = 1; i <= 7; i++) {
        expect(find.byKey(Key('zampona-arca-$i')), findsOneWidget);
      }
      for (var i = 1; i <= 6; i++) {
        expect(find.byKey(Key('zampona-ira-$i')), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Active tube'), findsOneWidget);
    });

    testWidgets('tubes meet the 48px width target', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ZamponaFingeringWidget(note: 'G4')),
        ),
      );
      final size = tester.getSize(find.byKey(const Key('zampona-ira-1')));
      expect(size.width, greaterThanOrEqualTo(48));
    });
  });
}
