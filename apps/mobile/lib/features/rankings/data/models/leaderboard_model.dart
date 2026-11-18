import 'package:equatable/equatable.dart';

/// Posición de un usuario en el leaderboard por instrumento (HU-12).
///
/// Espejo de `UserRankingResponse` del backend.
class LeaderboardEntryModel extends Equatable {
  final int rank;
  final String userId;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final int xp;

  const LeaderboardEntryModel({
    required this.rank,
    required this.userId,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.xp = 0,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      rank: json['rank'] as int? ?? 0,
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      xp: json['xp'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [rank, userId, username, fullName, avatarUrl, xp];
}

/// Espejo de `LeaderboardResponse`: `user_rank` es null si el usuario no tiene
/// prácticas en el periodo (se muestra como "Sin clasificar").
class LeaderboardModel extends Equatable {
  final List<LeaderboardEntryModel> items;
  final int? userRank;

  const LeaderboardModel({required this.items, this.userRank});

  factory LeaderboardModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardModel(
      items: (json['items'] as List? ?? const [])
          .map((e) => LeaderboardEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      userRank: json['user_rank'] as int?,
    );
  }

  @override
  List<Object?> get props => [items, userRank];
}
