import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/yin_pitch_detector.dart';

/// Genera un buffer PCM senoidal sintético para pruebas acústicas.
Float32List generateSineWave({
  required double frequency,
  required int sampleRate,
  required int numSamples,
  double amplitude = 0.8,
}) {
  final buffer = Float32List(numSamples);
  final angularFreq = 2.0 * math.pi * frequency / sampleRate;
  for (int i = 0; i < numSamples; i++) {
    buffer[i] = amplitude * math.sin(angularFreq * i);
  }
  return buffer;
}

void main() {
  group('YinPitchDetector [S0-04]', () {
    const detector = YinPitchDetector(sampleRate: 44100);

    test(
      'detecta con precisión Sol4 (392.0 Hz) para Quena con error <2 Hz',
      () {
        final buffer = generateSineWave(
          frequency: 392.0,
          sampleRate: 44100,
          numSamples: 2048,
        );

        final detected = detector.detectFundamentalFrequency(buffer);
        expect(detected, isNonZero);
        expect((detected - 392.0).abs(), lessThan(2.0));
      },
    );

    test(
      'detecta con precisión Do5 (523.25 Hz) para Tarka con error <2 Hz',
      () {
        final buffer = generateSineWave(
          frequency: 523.25,
          sampleRate: 44100,
          numSamples: 2048,
        );

        final detected = detector.detectFundamentalFrequency(buffer);
        expect(detected, isNonZero);
        expect((detected - 523.25).abs(), lessThan(2.0));
      },
    );

    test(
      'detecta con precisión Mi5 (659.25 Hz) para Zampoña con error <2 Hz',
      () {
        final buffer = generateSineWave(
          frequency: 659.25,
          sampleRate: 44100,
          numSamples: 2048,
        );

        final detected = detector.detectFundamentalFrequency(buffer);
        expect(detected, isNonZero);
        expect((detected - 659.25).abs(), lessThan(2.0));
      },
    );

    test(
      'retorna 0.0 Hz y silencio cuando el buffer está vacío o mudo (RMS < 0.01)',
      () {
        final emptyBuffer = Float32List(0);
        expect(detector.detectFundamentalFrequency(emptyBuffer), 0.0);

        final silentBuffer = Float32List(2048); // todo ceros
        expect(detector.detectFundamentalFrequency(silentBuffer), 0.0);

        final quietBuffer = generateSineWave(
          frequency: 440.0,
          sampleRate: 44100,
          numSamples: 2048,
          amplitude: 0.005, // RMS < 0.01
        );
        expect(detector.detectFundamentalFrequency(quietBuffer), 0.0);
      },
    );

    test(
      'calcula correctamente la desviación en cents y evalúa afinación dentro de +-15 cents',
      () {
        // 392 Hz exacto -> 0 cents
        final exact = detector.calculateCentsDeviation(392.0, 392.0);
        expect(exact.abs(), lessThan(0.01));

        // Ligeramente desviado: ~395 Hz vs 392 Hz (+13.2 cents -> afina <= 15)
        final evalTuned = detector.evaluateTuning(
          detectedHz: 395.0,
          targetHz: 392.0,
        );
        expect(evalTuned.isTuned, isTrue);
        expect(evalTuned.centsDeviation, closeTo(13.2, 0.5));

        // Muy desafinado: 410 Hz vs 392 Hz (+77 cents -> desafinado)
        final evalOut = detector.evaluateTuning(
          detectedHz: 410.0,
          targetHz: 392.0,
        );
        expect(evalOut.isTuned, isFalse);
        expect(evalOut.centsDeviation, greaterThan(15.0));
      },
    );

    test(
      'benchmark de latencia: procesamiento en isolate/loop ejecuta en <= 35ms por ventana',
      () {
        final buffer = generateSineWave(
          frequency: 440.0,
          sampleRate: 44100,
          numSamples: 2048,
        );

        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 5; i++) {
          detector.detectFundamentalFrequency(buffer);
        }
        stopwatch.stop();

        final averageMs = stopwatch.elapsedMilliseconds / 5.0;
        expect(averageMs, lessThanOrEqualTo(35.0));
      },
    );
  });
}
