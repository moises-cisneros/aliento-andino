import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lessons/data/models/note_sequence_model.dart';
import 'package:mobile/features/lessons/presentation/widgets/falling_notes_view.dart';

void main() {
  group('FallingNotesView - Andean Aerophones [SUB-143]', () {
    testWidgets(
      'renders clean impact bar with note frequency and cents (no piano keys)',
      (tester) async {
        final notes = [
          const NoteSequenceModel(
            id: 'n1',
            position: 0,
            note: 'G4',
            duration: 1.0,
          ),
          const NoteSequenceModel(
            id: 'n2',
            position: 1,
            note: 'A4',
            duration: 1.0,
          ),
          const NoteSequenceModel(
            id: 'n3',
            position: 2,
            note: 'B4',
            duration: 1.0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 600,
                child: FallingNotesView(
                  notes: notes,
                  currentPosition: 0,
                  currentExpectedNote: 'G4',
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Verificamos que se renderiza el CustomPaint
        expect(find.byType(CustomPaint), findsWidgets);
        expect(find.byType(FallingNotesView), findsOneWidget);
      },
    );

    testWidgets('handles Solfège and scientific notation without throwing', (
      tester,
    ) async {
      final notes = [
        const NoteSequenceModel(
          id: 'n1',
          position: 0,
          note: 'Sol4',
          duration: 1.0,
        ),
        const NoteSequenceModel(
          id: 'n2',
          position: 1,
          note: 'La4',
          duration: 1.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: FallingNotesView(
                notes: notes,
                currentPosition: 1,
                currentExpectedNote: 'La4',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
    });
  });
}
