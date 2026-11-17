import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lessons/data/services/midi_input_service.dart';

void main() {
  group('midiNumberToName', () {
    test('mapea números MIDI de referencia a nombre con octava', () {
      expect(midiNumberToName(60), 'C4'); // Do central
      expect(midiNumberToName(69), 'A4'); // La 440 Hz
      expect(midiNumberToName(21), 'A0'); // primera tecla del piano
      expect(midiNumberToName(108), 'C8'); // última tecla del piano
      expect(midiNumberToName(61), 'C#4'); // tecla negra
    });
  });

  group('noteNameToMidi', () {
    test('parsea notas con y sin alteración', () {
      expect(noteNameToMidi('C4'), 60);
      expect(noteNameToMidi('A4'), 69);
      expect(noteNameToMidi('F#5'), 78);
      expect(noteNameToMidi('Bb3'), 58);
    });

    test('los enarmónicos colapsan al mismo número MIDI', () {
      expect(noteNameToMidi('A#3'), noteNameToMidi('Bb3'));
    });

    test('retorna null para entradas inválidas', () {
      expect(noteNameToMidi('REST'), isNull);
      expect(noteNameToMidi('xyz'), isNull);
      expect(noteNameToMidi(''), isNull);
    });
  });

  group('round-trip nombre ↔ MIDI', () {
    test('cada número MIDI vuelve a sí mismo', () {
      for (var n = 21; n <= 108; n++) {
        expect(
          noteNameToMidi(midiNumberToName(n)),
          n,
          reason: 'falló en MIDI $n (${midiNumberToName(n)})',
        );
      }
    });
  });

  group('tolerancia de octava (pitch class)', () {
    test('misma nota en distinta octava comparte pitch class', () {
      final c4 = noteNameToMidi('C4')!;
      final c5 = noteNameToMidi('C5')!;
      expect(c4 % 12, c5 % 12);
      expect(c4, isNot(c5));
    });
  });
}
