import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lessons/presentation/widgets/piano_guide_widget.dart';

void main() {
  group('computeWhiteKeyRange', () {
    test('siempre empieza y termina en un C (octavas completas)', () {
      final keys = computeWhiteKeyRange(['C4', 'G4', 'A4'], 2);
      expect(keys.first, startsWith('C'));
      expect(keys.last, startsWith('C'));
    });

    test('principiante (Twinkle C4–A4, min 2 oct) → C3..C5, 15 blancas', () {
      final keys = computeWhiteKeyRange([
        'C4',
        'D4',
        'E4',
        'F4',
        'G4',
        'A4',
      ], 2);
      expect(keys.first, 'C3');
      expect(keys.last, 'C5');
      expect(keys.length, 15); // 2 octavas = 15 teclas blancas (25 totales)
    });

    test('respeta el mínimo de octavas aunque la lección sea de 1 nota', () {
      final keys = computeWhiteKeyRange(['E4'], 2);
      final octaves = (keys.length - 1) ~/ 7;
      expect(octaves, greaterThanOrEqualTo(2));
      expect(keys.first, startsWith('C'));
      expect(keys.last, startsWith('C'));
    });

    test('avanzado (cromática C4–C5, min 3 oct) → 3 octavas, 22 blancas', () {
      final notes = [
        'C4',
        'C#4',
        'D4',
        'D#4',
        'E4',
        'F4',
        'F#4',
        'G4',
        'G#4',
        'A4',
        'A#4',
        'B4',
        'C5',
      ];
      final keys = computeWhiteKeyRange(notes, 3);
      expect((keys.length - 1) ~/ 7, 3); // 3 octavas completas
      expect(keys.length, 22);
      expect(keys.first, startsWith('C'));
      expect(keys.last, startsWith('C'));
    });

    test('lección multi-octava (C3–C6) ya cubre el mínimo: no se expande', () {
      final keys = computeWhiteKeyRange(['C3', 'C6'], 3);
      expect(keys.first, 'C3');
      expect(keys.last, 'C6');
      expect((keys.length - 1) ~/ 7, 3);
    });

    test('no incluye teclas negras', () {
      final keys = computeWhiteKeyRange(['C4', 'F#4', 'A#4'], 2);
      expect(keys.every((k) => !k.contains('#')), isTrue);
    });
  });
}
