/// Modelo completo de XP del usuario.
class UserXPModel {
  final int totalXp;
  final int weeklyXp;
  final int level;
  final int xpForCurrentLevel;
  final int xpForNextLevel;
  final double xpProgressPercentage;
  final int currentStreak;
  final int longestStreak;
  final int streakFreezes;
  final int totalSessions;
  final double totalMinutes;
  final int totalCompleted;
  final int totalPerfect;
  final double averageScore;
  final int globalRank;
  final int weeklyRank;

  const UserXPModel({
    this.totalXp = 0,
    this.weeklyXp = 0,
    this.level = 1,
    this.xpForCurrentLevel = 0,
    this.xpForNextLevel = 100,
    this.xpProgressPercentage = 0.0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.streakFreezes = 0,
    this.totalSessions = 0,
    this.totalMinutes = 0.0,
    this.totalCompleted = 0,
    this.totalPerfect = 0,
    this.averageScore = 0.0,
    this.globalRank = 0,
    this.weeklyRank = 0,
  });

  factory UserXPModel.fromJson(Map<String, dynamic> json) {
    return UserXPModel(
      totalXp: json['total_xp'] as int? ?? 0,
      weeklyXp: json['weekly_xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      xpForCurrentLevel: json['xp_for_current_level'] as int? ?? 0,
      xpForNextLevel: json['xp_for_next_level'] as int? ?? 100,
      xpProgressPercentage:
          (json['xp_progress_percentage'] as num?)?.toDouble() ?? 0.0,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      streakFreezes: json['streak_freezes'] as int? ?? 0,
      totalSessions: json['total_sessions'] as int? ?? 0,
      totalMinutes: (json['total_minutes'] as num?)?.toDouble() ?? 0.0,
      totalCompleted: json['total_completed'] as int? ?? 0,
      totalPerfect: json['total_perfect'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      globalRank: json['global_rank'] as int? ?? 0,
      weeklyRank: json['weekly_rank'] as int? ?? 0,
    );
  }
}
