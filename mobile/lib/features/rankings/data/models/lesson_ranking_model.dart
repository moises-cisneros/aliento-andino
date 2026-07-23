/// Modelo de entrada en ranking por lección.
class LessonRankingModel {
  final int rank;
  final String userId;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final double score;
  final double tempoAccuracy;
  final String? createdAt;

  const LessonRankingModel({
    required this.rank,
    required this.userId,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    required this.score,
    this.tempoAccuracy = 0.0,
    this.createdAt,
  });

  factory LessonRankingModel.fromJson(Map<String, dynamic> json) {
    return LessonRankingModel(
      rank: json['rank'] as int? ?? 0,
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      tempoAccuracy: (json['tempo_accuracy'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String?,
    );
  }
}
