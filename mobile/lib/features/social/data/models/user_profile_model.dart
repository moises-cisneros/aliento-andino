/// Perfil público de usuario con contadores sociales.
class UserProfileModel {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool isFollowedByMe;
  final String createdAt;

  const UserProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.isFollowedByMe,
    required this.createdAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      isFollowedByMe: json['is_followed_by_me'] as bool? ?? false,
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }

  UserProfileModel copyWith({bool? isFollowedByMe, int? followersCount}) {
    return UserProfileModel(
      id: id,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      bio: bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      postsCount: postsCount,
      isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
      createdAt: createdAt,
    );
  }
}
