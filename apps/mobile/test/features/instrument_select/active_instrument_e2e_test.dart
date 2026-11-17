import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/instrument_select/bloc/active_instrument_bloc.dart';
import 'package:mobile/features/tuner/presentation/bloc/tuner_bloc.dart';
import 'package:mobile/features/tuner/presentation/screens/tuner_screen.dart';
import 'package:mobile/features/tuner/presentation/widgets/tuner_gauge_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActiveInstrument E2E [SUB-17-A]', () {
    testWidgets(
      'Cambio de instrumento en AppBar reconfigura afinador y sus frecuencias esperadas',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final activeBloc = ActiveInstrumentBloc(prefs: prefs);
        addTearDown(activeBloc.close);

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<ActiveInstrumentBloc>.value(
              value: activeBloc,
              child: const TunerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Estado inicial es Quena
        expect(activeBloc.state.activeInstrument, equals(InstrumentType.quena));

        // 2. Abrir selector de instrumento en el AppBar
        final appBarSelector = find.byKey(
          const Key('instrument-selector-appbar-button'),
        );
        expect(appBarSelector, findsOneWidget);
        await tester.tap(appBarSelector);
        await tester.pumpAndSettle();

        // 3. Seleccionar 'Tarka' en el PopupMenu
        final tarkaOption = find.byKey(const Key('instrument-option-tarka'));
        expect(tarkaOption, findsOneWidget);
        await tester.tap(tarkaOption);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        // 4. Verificar que ActiveInstrumentBloc y SharedPreferences tienen Tarka
        expect(activeBloc.state.activeInstrument, equals(InstrumentType.tarka));
        expect(prefs.getString(ActiveInstrumentBloc.prefsKey), equals('tarka'));

        // 5. Verificar que el TunerBloc interno recibió el cambio a Tarka
        final tunerBloc = tester
            .element(find.byType(TunerGaugeWidget))
            .read<TunerBloc>();
        expect(
          (tunerBloc.state as TunerActiveState).instrument,
          equals(InstrumentType.tarka),
        );

        // 6. Verificar reconfiguración de frecuencias esperadas en afinador:
        // En Tarka, 520 Hz debe afinarse contra Do5 (523.25 Hz)
        tunerBloc.add(
          const TunerPitchSampleReceived(
            detectedHz: 520.0,
            targetNote: 'Do5',
            targetHz: 523.25,
          ),
        );
        await tester.pumpAndSettle();

        final activeState = tunerBloc.state as TunerActiveState;
        expect(activeState.noteName, equals('Do5'));
        expect(activeState.targetFrequencyHz, equals(523.25));
        expect(activeState.instrument, equals(InstrumentType.tarka));

        // 7. Conmutar mediante el SegmentedButton a Zampoña y comprobar sincronización global
        final zamponaSegment = find.text('Zampoña');
        expect(zamponaSegment, findsOneWidget);
        await tester.tap(zamponaSegment);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(
          activeBloc.state.activeInstrument,
          equals(InstrumentType.zampona),
        );
        expect(
          prefs.getString(ActiveInstrumentBloc.prefsKey),
          equals('zampona'),
        );
        expect(
          (tunerBloc.state as TunerActiveState).instrument,
          equals(InstrumentType.zampona),
        );
      },
    );
  });
}
