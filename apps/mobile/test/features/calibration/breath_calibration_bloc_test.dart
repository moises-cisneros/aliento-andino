import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/core/audio/audio_capture_service.dart';
import 'package:mobile/core/audio/breath_calibrator.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/calibration/presentation/bloc/breath_calibration_bloc.dart';

class MockAudioCaptureService extends Mock implements AudioCaptureService {}

class MockBreathCalibrator extends Mock implements BreathCalibrator {}

Float32List _chunk(double amplitude, [int length = 1024]) {
  final c = Float32List(length);
  c.fillRange(0, length, amplitude);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioCaptureService capture;
  late MockBreathCalibrator calibrator;

  setUpAll(() => registerFallbackValue(<double>[]));

  setUp(() {
    capture = MockAudioCaptureService();
    calibrator = MockBreathCalibrator();
    when(() => capture.startCapture()).thenAnswer((_) async {});
    when(() => capture.stopCapture()).thenAnswer((_) async {});
    when(() => calibrator.calculateThreshold(any())).thenReturn(0.05);
    when(() => calibrator.saveThreshold(any())).thenAnswer((_) async {});
  });

  // sampleRate = 1024 y chunks de 1024 muestras → cada chunk equivale a 1 s.

  blocTest<BreathCalibrationBloc, BreathCalibrationState>(
    'completa la calibración tras 3 s de soplo continuo y guarda el umbral',
    build: () {
      when(() => capture.pcmAudioStream).thenAnswer(
        (_) => Stream.fromIterable([_chunk(0.1), _chunk(0.1), _chunk(0.1)]),
      );
      return BreathCalibrationBloc(
        captureService: capture,
        calibrator: calibrator,
        sampleRate: 1024,
        requiredSeconds: 3.0,
      );
    },
    act: (bloc) =>
        bloc.add(const StartBreathCalibrationEvent(InstrumentType.quena)),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<BreathCalibrationProgress>(),
      isA<BreathCalibrationProgress>(),
      isA<BreathCalibrationProgress>(),
      const BreathCalibrationCompleted(0.05),
    ],
    verify: (_) {
      verify(() => calibrator.saveThreshold(0.05)).called(1);
      verify(() => capture.stopCapture()).called(greaterThanOrEqualTo(1));
    },
  );

  blocTest<BreathCalibrationBloc, BreathCalibrationState>(
    'falla si el soplo se interrumpe antes de los 3 s',
    build: () {
      when(
        () => capture.pcmAudioStream,
      ).thenAnswer((_) => Stream.fromIterable([_chunk(0.1), _chunk(0.0)]));
      return BreathCalibrationBloc(
        captureService: capture,
        calibrator: calibrator,
        sampleRate: 1024,
        requiredSeconds: 3.0,
      );
    },
    act: (bloc) =>
        bloc.add(const StartBreathCalibrationEvent(InstrumentType.quena)),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<BreathCalibrationProgress>(),
      isA<BreathCalibrationProgress>(),
      isA<BreathCalibrationFailed>(),
    ],
    verify: (_) {
      verifyNever(() => calibrator.saveThreshold(any()));
      verify(() => capture.stopCapture()).called(greaterThanOrEqualTo(1));
    },
  );

  blocTest<BreathCalibrationBloc, BreathCalibrationState>(
    'permite cancelar y vuelve al estado inicial',
    build: () {
      when(
        () => capture.pcmAudioStream,
      ).thenAnswer((_) => const Stream<Float32List>.empty());
      return BreathCalibrationBloc(
        captureService: capture,
        calibrator: calibrator,
        sampleRate: 1024,
      );
    },
    act: (bloc) async {
      bloc.add(const StartBreathCalibrationEvent(InstrumentType.tarka));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const CancelBreathCalibrationEvent());
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<BreathCalibrationProgress>(),
      const BreathCalibrationInitial(),
    ],
  );
}
