import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/instrument_select/bloc/active_instrument_bloc.dart';
import 'package:mobile/features/lessons/data/models/note_sequence_model.dart';
import 'package:mobile/features/lessons/presentation/widgets/cascade_fingering_panel.dart';
import 'package:mobile/features/lessons/presentation/widgets/falling_notes_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _notes = [
  NoteSequenceModel(id: 'n1', position: 0, note: 'G4', duration: 1.0),
  NoteSequenceModel(id: 'n2', position: 1, note: 'A4', duration: 1.0),
];

Future<ActiveInstrumentBloc> _pump(
  WidgetTester tester, {
  String expected = 'G4',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final bloc = ActiveInstrumentBloc(prefs: prefs);
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<ActiveInstrumentBloc>.value(
        value: bloc,
        child: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: CascadeFingeringPanel(
              notes: _notes,
              currentPosition: 0,
              currentExpectedNote: expected,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

void main() {
  group('CascadeFingeringPanel [REFACTOR-150]', () {
    testWidgets('muestra los orificios de Quena junto a la cascada', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(FallingNotesView), findsOneWidget);
      expect(find.byKey(const Key('active-quena-fingering')), findsOneWidget);
      expect(find.byKey(const Key('quena-hole-thumb')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reacciona al instrumento activo y a su tolerancia en cents', (
      tester,
    ) async {
      final bloc = await _pump(tester);

      FallingNotesView view() =>
          tester.widget<FallingNotesView>(find.byType(FallingNotesView));
      expect(view().toleranceCents, InstrumentType.quena.defaultToleranceCents);

      bloc.add(const SelectInstrumentEvent(InstrumentType.zampona));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('active-zampona-fingering')), findsOneWidget);
      expect(find.byKey(const Key('active-quena-fingering')), findsNothing);
      expect(
        view().toleranceCents,
        InstrumentType.zampona.defaultToleranceCents,
      );

      bloc.add(const SelectInstrumentEvent(InstrumentType.tarka));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('active-tarka-fingering')), findsOneWidget);
      expect(view().toleranceCents, InstrumentType.tarka.defaultToleranceCents);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la digitación sigue a la nota esperada', (tester) async {
      await _pump(tester, expected: 'A4');

      final widget = tester.widget(
        find.byKey(const Key('active-quena-fingering')),
      );
      expect((widget as dynamic).note, 'A4');
    });
  });
}
