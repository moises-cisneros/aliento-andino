/// Modelo de entrada en el leaderboard (global/semanal/por instrumento).
class RankingEntryModel {
  final int rank;
  final String userId;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final int xp;
  final int totalXp;
  final int weeklyXp;
  final int level;
  final int totalLessonsCompleted;
  final String? instrument;

  const RankingEntryModel({
    required this.rank,
    required this.userId,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.xp = 0,
    this.totalXp = 0,
    this.weeklyXp = 0,
    this.level = 1,
    this.totalLessonsCompleted = 0,
    this.instrument,
  });

  factory RankingEntryModel.fromJson(Map<String, dynamic> json) {
    final rawXp = json['xp'] as int?;
    final rawWeekly = json['weekly_xp'] as int? ?? 0;
    final rawTotal = json['total_xp'] as int? ?? 0;
    final effectiveXp = rawXp ?? (rawWeekly > 0 ? rawWeekly : rawTotal);

    return RankingEntryModel(
      rank: json['rank'] as int? ?? 0,
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      xp: effectiveXp,
      totalXp: rawTotal,
      weeklyXp: rawWeekly > 0 ? rawWeekly : effectiveXp,
      level: json['level'] as int? ?? 1,
      totalLessonsCompleted: json['total_lessons_completed'] as int? ?? 0,
      instrument: json['instrument'] as String?,
    );
  }
}

/// Modelo de respuesta del leaderboard filtrable por instrumento (HU-12 / SUB-12-B).
class LeaderboardModel {
  final List<RankingEntryModel> items;
  final int? userRank;
  final String? instrument;
  final String scope;

  const LeaderboardModel({
    required this.items,
    this.userRank,
    this.instrument,
    this.scope = 'weekly',
  });

  factory LeaderboardModel.fromJson(Map<String, dynamic> json) {
    final list =
        (json['items'] as List<dynamic>?) ??
        (json['leaderboard'] as List<dynamic>?) ??
        [];
    return LeaderboardModel(
      items: list
          .map((e) => RankingEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      userRank: json['user_rank'] as int?,
      instrument: json['instrument'] as String?,
      scope: (json['scope'] as String?) ?? 'weekly',
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
