/// Modelo de entrada en el leaderboard (global/semanal).
class RankingEntryModel {
  final int rank;
  final String userId;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final int totalXp;
  final int weeklyXp;
  final int level;
  final int totalLessonsCompleted;

  const RankingEntryModel({
    required this.rank,
    required this.userId,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.totalXp = 0,
    this.weeklyXp = 0,
    this.level = 1,
    this.totalLessonsCompleted = 0,
  });

  factory RankingEntryModel.fromJson(Map<String, dynamic> json) {
    return RankingEntryModel(
      rank: json['rank'] as int? ?? 0,
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      totalXp: json['total_xp'] as int? ?? 0,
      weeklyXp: json['weekly_xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      totalLessonsCompleted: json['total_lessons_completed'] as int? ?? 0,
    );
  }
}

/// Modelo de entrada de ranking de rachas.
class StreakRankingEntryModel {
  final int rank;
  final String userId;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final int currentStreak;
  final int longestStreak;

  const StreakRankingEntryModel({
    required this.rank,
    required this.userId,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  factory StreakRankingEntryModel.fromJson(Map<String, dynamic> json) {
    return StreakRankingEntryModel(
      rank: json['rank'] as int? ?? 0,
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
    );
  }
}
