/// Resumen de usuario reutilizable en posts, comentarios, listas de follows.
class UserSummaryModel {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;

  /// Presente en listas de seguidores/siguiendo y sugerencias (null en otros usos).
  final bool? isFollowedByMe;
  final int? followersCount;

  const UserSummaryModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.isFollowedByMe,
    this.followersCount,
  });

  factory UserSummaryModel.fromJson(Map<String, dynamic> json) {
    return UserSummaryModel(
      id: (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      isFollowedByMe: json['is_followed_by_me'] as bool?,
      followersCount: json['followers_count'] as int?,
    );
  }

  UserSummaryModel copyWith({bool? isFollowedByMe}) {
    return UserSummaryModel(
      id: id,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
      followersCount: followersCount,
    );
  }
}
