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

/// Zampoña (siku) fingering: the active tube on the `ira` (6 tubes) or
/// `arca` (7 tubes) row. [tubeIndex] is 1-based.
class ZamponaFingering {
  final String activeRow;
  final int tubeIndex;
  final String noteName;

  /// Throws [ArgumentError] when [activeRow] is not `'ira'`/`'arca'` or
  /// [tubeIndex] is outside the row (1..6 for ira, 1..7 for arca).
  ZamponaFingering(this.activeRow, this.tubeIndex, this.noteName) {
    final max = tubeCounts[activeRow];
    if (max == null) {
      throw ArgumentError.value(
        activeRow,
        'activeRow',
        "must be 'ira' or 'arca'",
      );
    }
    if (tubeIndex < 1 || tubeIndex > max) {
      throw ArgumentError.value(
        tubeIndex,
        'tubeIndex',
        'must be within 1..$max',
      );
    }
  }

  /// Like the constructor, but an out-of-range [tubeIndex] falls back to the
  /// first tube instead of throwing. An invalid [activeRow] still throws.
  factory ZamponaFingering.safe(
    String activeRow,
    int tubeIndex,
    String noteName,
  ) {
    try {
      return ZamponaFingering(activeRow, tubeIndex, noteName);
    } on ArgumentError {
      if (!tubeCounts.containsKey(activeRow)) rethrow;
      return ZamponaFingering(activeRow, 1, noteName);
    }
  }

  static const Map<String, int> tubeCounts = {'ira': 6, 'arca': 7};

  // Andean diatonic G-major layout: the two rows alternate scale degrees.
  static const List<String> iraNotes = ['G4', 'B4', 'D5', 'F#5', 'A5', 'C6'];
  static const List<String> arcaNotes = [
    'A4',
    'C5',
    'E5',
    'G5',
    'B5',
    'D6',
    'F#6',
  ];

  /// Returns the tube that plays [note], or null if the zampoña cannot play it.
  static ZamponaFingering? forNote(String note) {
    final midi = parseNoteToMidi(note);
    if (midi == null) return null;
    for (var i = 0; i < iraNotes.length; i++) {
      if (parseNoteToMidi(iraNotes[i]) == midi) {
        return ZamponaFingering('ira', i + 1, iraNotes[i]);
      }
    }
    for (var i = 0; i < arcaNotes.length; i++) {
      if (parseNoteToMidi(arcaNotes[i]) == midi) {
        return ZamponaFingering('arca', i + 1, arcaNotes[i]);
      }
    }
    return null;
  }
}

/// Tarka fingering: six front rectangular holes, `true` = covered.
class TarkaFingering {
  final List<bool> holesCovered;

  /// Asserts (debug mode) that [holesCovered] has exactly 6 entries.
  TarkaFingering(List<bool> holesCovered)
    : assert(
        holesCovered.length == holeCount,
        'holesCovered must have exactly $holeCount entries',
      ),
      holesCovered = List.unmodifiable(holesCovered);

  static const int holeCount = 6;

  // Diatonic scale from Do5, uncovering one hole at a time from the bottom.
  static const Map<int, List<bool>> _byMidi = {
    72: [true, true, true, true, true, true], // Do5
    74: [true, true, true, true, true, false], // Re5
    76: [true, true, true, true, false, false], // Mi5
    77: [true, true, true, false, false, false], // Fa5
    79: [true, true, false, false, false, false], // Sol5
    81: [true, false, false, false, false, false], // La5
    83: [false, false, false, false, false, false], // Si5
  };

  /// Returns the fingering for [note], or null when the tarka scale does not
  /// include it.
  static TarkaFingering? forNote(String note) {
    final midi = parseNoteToMidi(note);
    final holes = midi == null ? null : _byMidi[midi];
    return holes == null ? null : TarkaFingering(holes);
  }
}
