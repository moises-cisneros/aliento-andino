/// Modelo de una nota en la secuencia musical.
class NoteSequenceModel {
  final String id;
  final int position;
  final String note;
  final double duration;
  final bool isRest;
  final int? finger;
  final String? hand;
  final int velocity;
  final bool isChord;
  final int? chordGroup;

  const NoteSequenceModel({
    required this.id,
    required this.position,
    required this.note,
    required this.duration,
    this.isRest = false,
    this.finger,
    this.hand,
    this.velocity = 80,
    this.isChord = false,
    this.chordGroup,
  });

  factory NoteSequenceModel.fromJson(Map<String, dynamic> json) {
    return NoteSequenceModel(
      id: json['id'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      note: (json['note'] as String?) ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 1.0,
      isRest: json['is_rest'] as bool? ?? false,
      finger: json['finger'] as int?,
      hand: json['hand'] as String?,
      velocity: json['velocity'] as int? ?? 80,
      isChord: json['is_chord'] as bool? ?? false,
      chordGroup: json['chord_group'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'position': position,
    'note': note,
    'duration': duration,
    'is_rest': isRest,
    'finger': finger,
    'hand': hand,
    'velocity': velocity,
    'is_chord': isChord,
    'chord_group': chordGroup,
  };
}
