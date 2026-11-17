/// Modelo de sesión de práctica.
class PracticeSessionModel {
  final String id;
  final String userId;
  final String lessonId;
  final double score;
  final int correctNotes;
  final int totalNotes;
  final int wrongNotes;
  final int missedNotes;
  final double averageTempo;
  final int expectedTempo;
  final double tempoAccuracy;
  final double totalTimeSeconds;
  final List<Map<String, dynamic>>? errorsDetail;
  final String? aiFeedback;
  final bool completed;
  final String? createdAt;
  final String? lessonTitle;
  final String? lessonInstrument;

  const PracticeSessionModel({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.score,
    required this.correctNotes,
    required this.totalNotes,
    required this.wrongNotes,
    required this.missedNotes,
    required this.averageTempo,
    required this.expectedTempo,
    required this.tempoAccuracy,
    required this.totalTimeSeconds,
    this.errorsDetail,
    this.aiFeedback,
    this.completed = true,
    this.createdAt,
    this.lessonTitle,
    this.lessonInstrument,
  });

  factory PracticeSessionModel.fromJson(Map<String, dynamic> json) {
    return PracticeSessionModel(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      lessonId: (json['lesson_id'] as String?) ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      correctNotes: json['correct_notes'] as int? ?? 0,
      totalNotes: json['total_notes'] as int? ?? 0,
      wrongNotes: json['wrong_notes'] as int? ?? 0,
      missedNotes: json['missed_notes'] as int? ?? 0,
      averageTempo: (json['average_tempo'] as num?)?.toDouble() ?? 0.0,
      expectedTempo: json['expected_tempo'] as int? ?? 60,
      tempoAccuracy: (json['tempo_accuracy'] as num?)?.toDouble() ?? 0.0,
      totalTimeSeconds: (json['total_time_seconds'] as num?)?.toDouble() ?? 0.0,
      errorsDetail: (json['errors_detail'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      aiFeedback: json['ai_feedback'] as String?,
      completed: json['completed'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      lessonTitle: json['lesson_title'] as String?,
      lessonInstrument: json['lesson_instrument'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'lesson_id': lessonId,
    'score': score,
    'correct_notes': correctNotes,
    'total_notes': totalNotes,
    'wrong_notes': wrongNotes,
    'missed_notes': missedNotes,
    'average_tempo': averageTempo,
    'total_time_seconds': totalTimeSeconds,
    'errors_detail': errorsDetail,
    'completed': completed,
  };
}
