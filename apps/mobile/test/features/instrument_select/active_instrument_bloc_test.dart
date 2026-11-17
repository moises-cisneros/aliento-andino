import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/instrument_select/bloc/active_instrument_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActiveInstrumentBloc [SUB-17-A Unit]', () {
    test(
      'Estado inicial es quena por defecto cuando no hay SharedPreferences',
      () {
        final bloc = ActiveInstrumentBloc();
        expect(bloc.state.activeInstrument, equals(InstrumentType.quena));
        bloc.close();
      },
    );

    test(
      'Estado inicial hace fallback a quena ante almacenamiento corrupto o desconocido',
      () async {
        SharedPreferences.setMockInitialValues({
          ActiveInstrumentBloc.prefsKey: 'instrumento_desconocido_123',
        });
        final prefs = await SharedPreferences.getInstance();

        final bloc = ActiveInstrumentBloc(prefs: prefs);
        expect(bloc.state.activeInstrument, equals(InstrumentType.quena));
        bloc.close();
      },
    );

    test(
      'Estado inicial se restaura correctamente desde SharedPreferences (zampona)',
      () async {
        SharedPreferences.setMockInitialValues({
          ActiveInstrumentBloc.prefsKey: 'zampona',
        });
        final prefs = await SharedPreferences.getInstance();

        final bloc = ActiveInstrumentBloc(prefs: prefs);
        expect(bloc.state.activeInstrument, equals(InstrumentType.zampona));
        bloc.close();
      },
    );

    test(
      'Estado inicial respeta initialInstrument provisto explícitamente',
      () {
        final bloc = ActiveInstrumentBloc(
          initialInstrument: InstrumentType.tarka,
        );
        expect(bloc.state.activeInstrument, equals(InstrumentType.tarka));
        bloc.close();
      },
    );

    test(
      'Transiciones reactivas quena -> zampona -> tarka y persistencia en SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final bloc = ActiveInstrumentBloc(prefs: prefs);
        expect(bloc.state.activeInstrument, equals(InstrumentType.quena));

        // 1. Conmutar a Zampoña
        bloc.add(const SelectInstrumentEvent(InstrumentType.zampona));
        await expectLater(
          bloc.stream,
          emits(const ActiveInstrumentState(InstrumentType.zampona)),
        );
        expect(
          prefs.getString(ActiveInstrumentBloc.prefsKey),
          equals('zampona'),
        );

        // 2. Conmutar a Tarka
        bloc.add(const SelectInstrumentEvent(InstrumentType.tarka));
        await expectLater(
          bloc.stream,
          emits(const ActiveInstrumentState(InstrumentType.tarka)),
        );
        expect(prefs.getString(ActiveInstrumentBloc.prefsKey), equals('tarka'));

        // 3. Conmutar de vuelta a Quena
        bloc.add(const SelectInstrumentEvent(InstrumentType.quena));
        await expectLater(
          bloc.stream,
          emits(const ActiveInstrumentState(InstrumentType.quena)),
        );
        expect(prefs.getString(ActiveInstrumentBloc.prefsKey), equals('quena'));

        bloc.close();
      },
    );

    test('Ignora evento repetido si el instrumento ya está activo', () async {
      final bloc = ActiveInstrumentBloc(
        initialInstrument: InstrumentType.quena,
      );

      var emitted = false;
      final sub = bloc.stream.listen((_) => emitted = true);

      bloc.add(const SelectInstrumentEvent(InstrumentType.quena));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isFalse);
      expect(bloc.state.activeInstrument, equals(InstrumentType.quena));

      await sub.cancel();
      bloc.close();
    });

    test(
      'LoadActiveInstrumentEvent recarga el instrumento almacenado',
      () async {
        SharedPreferences.setMockInitialValues({
          ActiveInstrumentBloc.prefsKey: 'quena',
        });
        final prefs = await SharedPreferences.getInstance();

        final bloc = ActiveInstrumentBloc(prefs: prefs);
        expect(bloc.state.activeInstrument, equals(InstrumentType.quena));

        // Modificar directamente en disco/mock
        await prefs.setString(ActiveInstrumentBloc.prefsKey, 'tarka');

        bloc.add(const LoadActiveInstrumentEvent());
        await expectLater(
          bloc.stream,
          emits(const ActiveInstrumentState(InstrumentType.tarka)),
        );

        bloc.close();
      },
    );
  });
}
