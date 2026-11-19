import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/fingering_models.dart';
import 'package:mobile/features/lessons/presentation/widgets/instruments/zampona_fingering_widget.dart';

void main() {
  group('ZamponaFingering', () {
    test(
      'maps diatonic notes to ira and arca tubes (Malta tradicional 13 tubos F#4..D6)',
      () {
        final fs4 = ZamponaFingering.forNote('F#4')!;
        expect([fs4.activeRow, fs4.tubeIndex], ['arca', 1]);
        final g4 = ZamponaFingering.forNote('G4')!;
        expect([g4.activeRow, g4.tubeIndex], ['ira', 1]);
        final a4 = ZamponaFingering.forNote('La4')!;
        expect([a4.activeRow, a4.tubeIndex], ['arca', 2]);
        final c6 = ZamponaFingering.forNote('C6')!;
        expect([c6.activeRow, c6.tubeIndex], ['ira', 6]);
        final d6 = ZamponaFingering.forNote('D6')!;
        expect([d6.activeRow, d6.tubeIndex], ['arca', 7]);
      },
    );

    test('returns null for notes the zampoña cannot play', () {
      expect(ZamponaFingering.forNote('C3'), isNull);
      expect(
        ZamponaFingering.forNote('F#6'),
        isNull,
      ); // fuera de Malta 13 tubos
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

    testWidgets(
      'inverts tube heights (graves longer, agudos shorter) and uses FittedBox',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ZamponaFingeringWidget(note: 'G4')),
          ),
        );
        expect(find.byType(FittedBox), findsOneWidget);

        final tube1Size = tester.getSize(
          find.byKey(const Key('zampona-arca-1')),
        );
        final tube7Size = tester.getSize(
          find.byKey(const Key('zampona-arca-7')),
        );
        // Tubo 1 (grave F#4) debe ser más largo que tubo 7 (agudo D6)
        expect(tube1Size.height, greaterThan(tube7Size.height));
      },
    );
  });
}
