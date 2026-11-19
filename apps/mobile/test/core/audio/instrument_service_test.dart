import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/audio/instrument_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InstrumentService [Issue #149]', () {
    late InstrumentService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = InstrumentService();
    });

    test(
      'get() retorna defaultInstrument (quena) cuando no hay preferencia guardada',
      () async {
        final instrument = await service.get();
        expect(instrument, equals(InstrumentType.quena));
      },
    );

    test(
      'set() guarda bajo la clave unificada active_instrument en formato String',
      () async {
        await service.set(InstrumentType.zampona);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(InstrumentService.key), equals('zampona'));

        final current = await service.get();
        expect(current, equals(InstrumentType.zampona));
      },
    );

    test('get() recupera correctamente tarka', () async {
      await service.set(InstrumentType.tarka);
      final current = await service.get();
      expect(current, equals(InstrumentType.tarka));
    });

    test(
      'get() soporta compatibilidad retroactiva con int guardado en active_instrument',
      () async {
        SharedPreferences.setMockInitialValues({
          InstrumentService.key: 1, // zampona index
        });
        final current = await service.get();
        expect(current, equals(InstrumentType.zampona));
      },
    );

    test(
      'get() soporta compatibilidad con la clave heredada synth_instrument',
      () async {
        SharedPreferences.setMockInitialValues({
          'synth_instrument': 2, // tarka index
        });
        final current = await service.get();
        expect(current, equals(InstrumentType.tarka));
      },
    );

    test('get() retorna defaultInstrument ante texto inválido', () async {
      SharedPreferences.setMockInitialValues({
        InstrumentService.key: 'instrumento_desconocido_xyz',
      });
      final current = await service.get();
      expect(current, equals(InstrumentType.quena));
    });
  });
}
