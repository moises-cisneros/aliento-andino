import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Relative weight of each component in the unified session score.
///
/// Defaults follow HU-09: tuning 50%, rhythm 30%, posture 20%.
@immutable
class PracticeScoreWeights {
  final double tuning;
  final double rhythm;
  final double posture;

  const PracticeScoreWeights({
    this.tuning = 0.5,
    this.rhythm = 0.3,
    this.posture = 0.2,
  });

  /// Throws [ArgumentError] unless the weights are non-negative and sum to 1.
  void validate() {
    final sum = tuning + rhythm + posture;
    if (tuning < 0 || rhythm < 0 || posture < 0 || (sum - 1.0).abs() > 1e-9) {
      throw ArgumentError(
        'Score weights must be non-negative and add up to 1.0 (got $sum).',
      );
    }
  }
}

/// Compact telemetry of one practice session, ready to be sent to
/// `POST /api/v1/practice/session` (or queued offline).
@immutable
class PracticeSessionModel {
  static const _uuid = Uuid();

  final String lessonId;

  /// UUID that makes retries idempotent on the backend.
  final String clientId;

  /// Unified score in the 0..100 range.
  final double score;
  final int correctNotes;
  final int totalNotes;
  final int wrongNotes;
  final int missedNotes;
  final double averageTempo;
  final double totalTimeSeconds;
  final List<Map<String, dynamic>>? errorsDetail;
  final bool completed;

  const PracticeSessionModel({
    required this.lessonId,
    required this.clientId,
    required this.score,
    required this.correctNotes,
    required this.totalNotes,
    required this.wrongNotes,
    required this.missedNotes,
    required this.averageTempo,
    required this.totalTimeSeconds,
    this.errorsDetail,
    this.completed = true,
  });

  /// Builds a session from per-dimension scores (each 0..100), computing the
  /// weighted unified score and generating a fresh UUID `client_id`.
  factory PracticeSessionModel.fromTelemetry({
    required String lessonId,
    required double tuningScore,
    required double rhythmScore,
    required double postureScore,
    required int correctNotes,
    required int totalNotes,
    required int wrongNotes,
    required int missedNotes,
    required double averageTempo,
    required double totalTimeSeconds,
    List<Map<String, dynamic>>? errorsDetail,
    bool completed = true,
    PracticeScoreWeights weights = const PracticeScoreWeights(),
    String? clientId,
  }) {
    weights.validate();
    double clamp(double v) => v.clamp(0.0, 100.0).toDouble();
    final score =
        clamp(tuningScore) * weights.tuning +
        clamp(rhythmScore) * weights.rhythm +
        clamp(postureScore) * weights.posture;
    return PracticeSessionModel(
      lessonId: lessonId,
      clientId: clientId ?? _uuid.v4(),
      score: clamp(score),
      correctNotes: correctNotes,
      totalNotes: totalNotes,
      wrongNotes: wrongNotes,
      missedNotes: missedNotes,
      averageTempo: averageTempo,
      totalTimeSeconds: totalTimeSeconds,
      errorsDetail: errorsDetail,
      completed: completed,
    );
  }

  factory PracticeSessionModel.fromJson(Map<String, dynamic> json) {
    return PracticeSessionModel(
      lessonId: json['lesson_id'] as String,
      clientId: json['client_id'] as String,
      score: (json['score'] as num).toDouble(),
      correctNotes: json['correct_notes'] as int,
      totalNotes: json['total_notes'] as int,
      wrongNotes: json['wrong_notes'] as int,
      missedNotes: json['missed_notes'] as int,
      averageTempo: (json['average_tempo'] as num).toDouble(),
      totalTimeSeconds: (json['total_time_seconds'] as num).toDouble(),
      errorsDetail: (json['errors_detail'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      completed: json['completed'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'lesson_id': lessonId,
    'client_id': clientId,
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

  @override
  bool operator ==(Object other) =>
      other is PracticeSessionModel &&
      other.lessonId == lessonId &&
      other.clientId == clientId &&
      other.score == score &&
      other.correctNotes == correctNotes &&
      other.totalNotes == totalNotes &&
      other.wrongNotes == wrongNotes &&
      other.missedNotes == missedNotes &&
      other.averageTempo == averageTempo &&
      other.totalTimeSeconds == totalTimeSeconds &&
      other.completed == completed &&
      listEquals(
        errorsDetail?.map((e) => e.toString()).toList(),
        other.errorsDetail?.map((e) => e.toString()).toList(),
      );

  @override
  int get hashCode => Object.hash(
    lessonId,
    clientId,
    score,
    correctNotes,
    totalNotes,
    wrongNotes,
    missedNotes,
    averageTempo,
    totalTimeSeconds,
    completed,
  );
}
