import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/tuner/presentation/bloc/tuner_bloc.dart';

void main() {
  group('TunerBloc [SUB-01-B]', () {
    late TunerBloc bloc;

    setUp(() {
      bloc = TunerBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('estado inicial es TunerInitial', () {
      expect(bloc.state, isA<TunerInitial>());
    });

    test(
      'TunerPitchSampleReceived con 390 Hz vs 392 Hz (-8.8 cents) emite isTuned = true',
      () async {
        // Activar afinador primero
        bloc.emit(
          const TunerActiveState(
            centsDeviation: 0.0,
            noteName: '--',
            isTuned: false,
            frequencyHz: 0.0,
            targetFrequencyHz: 0.0,
            instrument: InstrumentType.quena,
            toleranceCents: 15.0,
            isSilent: true,
          ),
        );

        bloc.add(
          const TunerPitchSampleReceived(
            detectedHz: 390.0,
            targetNote: 'Sol4',
            targetHz: 392.0,
          ),
        );

        await expectLater(
          bloc.stream,
          emits(
            isA<TunerActiveState>()
                .having((s) => s.noteName, 'noteName', 'Sol4')
                .having((s) => s.isTuned, 'isTuned', isTrue)
                .having(
                  (s) => s.centsDeviation,
                  'centsDeviation',
                  closeTo(-8.85, 0.5),
                )
                .having((s) => s.isSilent, 'isSilent', isFalse),
          ),
        );
      },
    );

    test(
      'TunerPitchSampleReceived con 380 Hz vs 392 Hz (-53.7 cents) emite isTuned = false (desafinado)',
      () async {
        bloc.emit(
          const TunerActiveState(
            centsDeviation: 0.0,
            noteName: '--',
            isTuned: false,
            frequencyHz: 0.0,
            targetFrequencyHz: 0.0,
            instrument: InstrumentType.quena,
            toleranceCents: 15.0,
            isSilent: true,
          ),
        );

        bloc.add(
          const TunerPitchSampleReceived(
            detectedHz: 380.0,
            targetNote: 'Sol4',
            targetHz: 392.0,
          ),
        );

        await expectLater(
          bloc.stream,
          emits(
            isA<TunerActiveState>()
                .having((s) => s.noteName, 'noteName', 'Sol4')
                .having((s) => s.isTuned, 'isTuned', isFalse)
                .having(
                  (s) => s.centsDeviation,
                  'centsDeviation',
                  -50.0,
                ) // clampeado a -50
                .having((s) => s.isSilent, 'isSilent', isFalse),
          ),
        );
      },
    );

    test(
      'TunerPitchSampleReceived con detectedHz = 0.0 activa isSilent = true',
      () async {
        bloc.emit(
          const TunerActiveState(
            centsDeviation: 10.0,
            noteName: 'Sol4',
            isTuned: true,
            frequencyHz: 392.0,
            targetFrequencyHz: 392.0,
            instrument: InstrumentType.quena,
            toleranceCents: 15.0,
            isSilent: false,
          ),
        );

        bloc.add(
          const TunerPitchSampleReceived(
            detectedHz: 0.0,
            targetNote: '--',
            targetHz: 0.0,
          ),
        );

        await expectLater(
          bloc.stream,
          emits(
            isA<TunerActiveState>()
                .having((s) => s.isSilent, 'isSilent', isTrue)
                .having((s) => s.frequencyHz, 'frequencyHz', 0.0),
          ),
        );
      },
    );

    test('TunerInstrumentChanged actualiza el instrumento activo', () async {
      bloc.emit(
        const TunerActiveState(
          centsDeviation: 0.0,
          noteName: '--',
          isTuned: false,
          frequencyHz: 0.0,
          targetFrequencyHz: 0.0,
          instrument: InstrumentType.quena,
          toleranceCents: 15.0,
        ),
      );

      bloc.add(const TunerInstrumentChanged(InstrumentType.zampona));

      await expectLater(
        bloc.stream,
        emits(
          isA<TunerActiveState>().having(
            (s) => s.instrument,
            'instrument',
            InstrumentType.zampona,
          ),
        ),
      );
    });
  });
}
