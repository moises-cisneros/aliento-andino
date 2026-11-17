// Fingering models for the Andean wind instruments (HU-03).

/// Coverage state of a single hole.
enum HoleState { open, half, covered }

/// Parses a note name such as `G4`, `F#5` or the Spanish form `Sol4` into a
/// MIDI number. Returns null when the input is not a valid note.
int? parseNoteToMidi(String note) {
  const spanish = {
    'Do': 'C',
    'Re': 'D',
    'Mi': 'E',
    'Fa': 'F',
    'Sol': 'G',
    'La': 'A',
    'Si': 'B',
  };
  var normalized = note.trim();
  for (final entry in spanish.entries) {
    if (normalized.startsWith(entry.key)) {
      normalized = entry.value + normalized.substring(entry.key.length);
      break;
    }
  }
  final m = RegExp(r'^([A-G])([#b]?)(\d+)$').firstMatch(normalized);
  if (m == null) return null;
  const semis = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
  var semi = semis[m.group(1)!]!;
  if (m.group(2) == '#') semi++;
  if (m.group(2) == 'b') semi--;
  return (int.parse(m.group(3)!) + 1) * 12 + semi;
}

/// Quena fingering: one rear thumb hole plus six front holes.
///
/// `true` means the hole is fully covered. [halfHoles] lists holes (0 = thumb,
/// 1..6 = front holes) that are half covered; they are reported as
/// [HoleState.half] and are not counted as covered.
class QuenaFingering {
  final bool thumb;
  final bool hole1;
  final bool hole2;
  final bool hole3;
  final bool hole4;
  final bool hole5;
  final bool hole6;
  final Set<int> halfHoles;

  const QuenaFingering(
    this.thumb,
    this.hole1,
    this.hole2,
    this.hole3,
    this.hole4,
    this.hole5,
    this.hole6, {
    this.halfHoles = const {},
  });

  /// Lowest and highest playable MIDI notes (Sol4 .. Sol6).
  static const int lowestMidi = 67;
  static const int highestMidi = 91;

  /// Hole states in drawing order: thumb first, then holes 1..6.
  List<HoleState> get states {
    final covered = [thumb, hole1, hole2, hole3, hole4, hole5, hole6];
    return List.generate(7, (i) {
      if (halfHoles.contains(i)) return HoleState.half;
      return covered[i] ? HoleState.covered : HoleState.open;
    });
  }

  // Semitone offset above Sol4 -> fingering (first octave, G-major quena).
  // Accidentals are approximated by half covering the first open hole.
  static const Map<int, QuenaFingering> _firstOctave = {
    0: QuenaFingering(true, true, true, true, true, true, true), // Sol4
    1: QuenaFingering(
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      halfHoles: {6},
    ), // Sol#4
    2: QuenaFingering(true, true, true, true, true, true, false), // La4
    3: QuenaFingering(
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      halfHoles: {5},
    ), // La#4
    4: QuenaFingering(true, true, true, true, true, false, false), // Si4
    5: QuenaFingering(true, true, true, true, false, false, false), // Do5
    6: QuenaFingering(
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      halfHoles: {4},
    ), // Do#5
    7: QuenaFingering(true, true, true, false, false, false, false), // Re5
    8: QuenaFingering(
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      halfHoles: {3},
    ), // Re#5
    9: QuenaFingering(true, true, false, false, false, false, false), // Mi5
    10: QuenaFingering(
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      halfHoles: {1},
    ), // Fa5
    11: QuenaFingering(true, false, false, false, false, false, false), // Fa#5
  };

  /// Returns the fingering for [note], or null when the note is outside the
  /// standard quena range (below Sol4 or above Sol6) or cannot be parsed.
  ///
  /// Notes in the second octave reuse the first-octave pattern with the thumb
  /// hole half covered (venting).
  static QuenaFingering? forNote(String note) {
    final midi = parseNoteToMidi(note);
    if (midi == null || midi < lowestMidi || midi > highestMidi) return null;
    final offset = midi - lowestMidi;
    if (offset < 12) return _firstOctave[offset];
    // Sol6 (offset 24) has no first-octave twin: fully open, half thumb.
    final base = _firstOctave[offset - 12];
    if (base == null) {
      return const QuenaFingering(
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        halfHoles: {0},
      );
    }
    return QuenaFingering(
      base.thumb,
      base.hole1,
      base.hole2,
      base.hole3,
      base.hole4,
      base.hole5,
      base.hole6,
      halfHoles: const {0},
    );
  }
}
