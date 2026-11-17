import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/instrument_select/bloc/active_instrument_bloc.dart';
import 'package:mobile/features/instrument_select/presentation/widgets/instrument_selector_appbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActiveInstrument Integration [SUB-17-A]', () {
    testWidgets(
      'Re-renderizado reactivo de widget de digitación al conmutar estado de BLoC',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final activeBloc = ActiveInstrumentBloc(prefs: prefs);
        addTearDown(activeBloc.close);

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<ActiveInstrumentBloc>.value(
              value: activeBloc,
              child: const Scaffold(
                appBar: InstrumentSelectorAppBar(
                  title: Text('Digitación Interactiva'),
                ),
                body: Center(
                  child: ActiveInstrumentFingeringWidget(note: 'Sol4'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Estado inicial por defecto: Quena
        expect(find.byKey(const Key('active-quena-fingering')), findsOneWidget);
        expect(find.byKey(const Key('active-zampona-fingering')), findsNothing);
        expect(find.byKey(const Key('active-tarka-fingering')), findsNothing);

        // 2. Conmutar a Zampoña vía BLoC
        activeBloc.add(const SelectInstrumentEvent(InstrumentType.zampona));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('active-quena-fingering')), findsNothing);
        expect(
          find.byKey(const Key('active-zampona-fingering')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('active-tarka-fingering')), findsNothing);

        // 3. Conmutar a Tarka vía BLoC
        activeBloc.add(const SelectInstrumentEvent(InstrumentType.tarka));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('active-quena-fingering')), findsNothing);
        expect(find.byKey(const Key('active-zampona-fingering')), findsNothing);
        expect(find.byKey(const Key('active-tarka-fingering')), findsOneWidget);

        // 4. Conmutar de regreso a Quena vía BLoC
        activeBloc.add(const SelectInstrumentEvent(InstrumentType.quena));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('active-quena-fingering')), findsOneWidget);
        expect(find.byKey(const Key('active-zampona-fingering')), findsNothing);
        expect(find.byKey(const Key('active-tarka-fingering')), findsNothing);
      },
    );
  });
}
