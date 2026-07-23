/// Modelo de estadísticas de progreso del usuario.
class ProgressStatsModel {
  final int totalSessions;
  final int totalLessonsPlayed;
  final double averageScore;
  final double bestScore;
  final double totalPracticeTime;
  final int lessonsCompleted;
  final int currentStreak;
  final String? favoriteCategory;

  const ProgressStatsModel({
    this.totalSessions = 0,
    this.totalLessonsPlayed = 0,
    this.averageScore = 0.0,
    this.bestScore = 0.0,
    this.totalPracticeTime = 0.0,
    this.lessonsCompleted = 0,
    this.currentStreak = 0,
    this.favoriteCategory,
  });

  factory ProgressStatsModel.fromJson(Map<String, dynamic> json) {
    return ProgressStatsModel(
      totalSessions: json['total_sessions'] as int? ?? 0,
      totalLessonsPlayed: json['total_lessons_played'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      bestScore: (json['best_score'] as num?)?.toDouble() ?? 0.0,
      totalPracticeTime:
          (json['total_practice_time'] as num?)?.toDouble() ?? 0.0,
      lessonsCompleted: json['lessons_completed'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
      favoriteCategory: json['favorite_category'] as String?,
    );
  }
}

/// Un desafío semanal con el progreso del usuario.
class WeeklyChallengeModel {
  final String key;
  final String title;
  final String description;
  final int target;
  final int progress;
  final bool completed;

  const WeeklyChallengeModel({
    required this.key,
    required this.title,
    required this.description,
    required this.target,
    required this.progress,
    required this.completed,
  });

  double get fraction => target <= 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);

  factory WeeklyChallengeModel.fromJson(Map<String, dynamic> json) {
    return WeeklyChallengeModel(
      key: (json['key'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      target: json['target'] as int? ?? 0,
      progress: json['progress'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

/// Punto de datos semanal para gráfico de progreso.
class WeeklyDataPoint {
  final String date;
  final int sessionsCount;
  final double averageScore;
  final double practiceMinutes;

  const WeeklyDataPoint({
    required this.date,
    this.sessionsCount = 0,
    this.averageScore = 0.0,
    this.practiceMinutes = 0.0,
  });

  factory WeeklyDataPoint.fromJson(Map<String, dynamic> json) {
    return WeeklyDataPoint(
      date: (json['date'] as String?) ?? '',
      sessionsCount: json['sessions_count'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      practiceMinutes: (json['practice_minutes'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
