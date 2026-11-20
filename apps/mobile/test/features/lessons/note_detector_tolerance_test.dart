import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lessons/presentation/services/note_detector.dart';

double _hz(double midi) => 440.0 * math.pow(2.0, (midi - 69) / 12.0);

void main() {
  group('NoteDetector - tolerancia en cents [REFACTOR-150]', () {
    test('centsFromNearestNote: nota exacta = 0', () {
      expect(NoteDetector.centsFromNearestNote(440.0), closeTo(0.0, 1e-6));
      expect(NoteDetector.centsFromNearestNote(_hz(67)), closeTo(0.0, 1e-6));
    });

    test('centsFromNearestNote: signo y magnitud', () {
      expect(
        NoteDetector.centsFromNearestNote(_hz(69.20)),
        closeTo(20.0, 1e-6),
      );
      expect(
        NoteDetector.centsFromNearestNote(_hz(68.80)),
        closeTo(-20.0, 1e-6),
      );
    });

    test(
      'una desviación de 20 cents cae fuera de Quena y dentro de Zampoña',
      () {
        final cents = NoteDetector.centsFromNearestNote(_hz(69.20)).abs();
        expect(cents > 15.0, isTrue); // Quena
        expect(cents <= 20.0 + 1e-6, isTrue); // Zampoña
      },
    );

    test('frecuencia no positiva devuelve 0', () {
      expect(NoteDetector.centsFromNearestNote(0), 0.0);
      expect(NoteDetector.centsFromNearestNote(-5), 0.0);
    });
  });
}
