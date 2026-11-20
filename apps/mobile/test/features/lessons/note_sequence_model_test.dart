import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lessons/data/models/note_sequence_model.dart';

void main() {
  group('NoteSequenceModel monofónico [REFACTOR-150]', () {
    test('fromJson ignora campos polifónicos heredados del backend', () {
      final n = NoteSequenceModel.fromJson({
        'id': 'a',
        'position': 1,
        'note': 'G4',
        'duration': 1.0,
        'is_chord': true,
        'chord_group': 3,
      });
      expect(n.note, 'G4');
      expect(n.toJson().containsKey('is_chord'), isFalse);
      expect(n.toJson().containsKey('chord_group'), isFalse);
    });

    test('toJson conserva los campos monofónicos', () {
      const n = NoteSequenceModel(
        id: 'a',
        position: 2,
        note: 'A4',
        duration: 0.5,
        isRest: false,
        finger: 1,
        hand: 'right',
        velocity: 90,
      );
      expect(n.toJson(), {
        'position': 2,
        'note': 'A4',
        'duration': 0.5,
        'is_rest': false,
        'finger': 1,
        'hand': 'right',
        'velocity': 90,
      });
    });
  });
}
