import 'user_summary_model.dart';

/// Modelo de publicación en la red social.
class PostModel {
  final String id;
  final UserSummaryModel user;
  final String content;
  final String postType;
  final String? mediaUrl;
  final String? mediaThumbnailUrl;
  final PracticeSessionSummary? practiceSession;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final bool isSavedByMe;
  final String createdAt;
  final String? updatedAt;

  const PostModel({
    required this.id,
    required this.user,
    required this.content,
    required this.postType,
    this.mediaUrl,
    this.mediaThumbnailUrl,
    this.practiceSession,
    required this.likesCount,
    required this.commentsCount,
    required this.isLikedByMe,
    this.isSavedByMe = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: (json['id'] as String?) ?? '',
      user: UserSummaryModel.fromJson(json['user'] as Map<String, dynamic>),
      content: (json['content'] as String?) ?? '',
      postType: (json['post_type'] as String?) ?? 'text',
      mediaUrl: json['media_url'] as String?,
      mediaThumbnailUrl: json['media_thumbnail_url'] as String?,
      practiceSession: json['practice_session'] != null
          ? PracticeSessionSummary.fromJson(
              json['practice_session'] as Map<String, dynamic>,
            )
          : null,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      isLikedByMe: json['is_liked_by_me'] as bool? ?? false,
      isSavedByMe: json['is_saved_by_me'] as bool? ?? false,
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: json['updated_at'] as String?,
    );
  }

  PostModel copyWith({
    bool? isLikedByMe,
    bool? isSavedByMe,
    int? likesCount,
    int? commentsCount,
    String? content,
    String? updatedAt,
  }) {
    return PostModel(
      id: id,
      user: user,
      content: content ?? this.content,
      postType: postType,
      mediaUrl: mediaUrl,
      mediaThumbnailUrl: mediaThumbnailUrl,
      practiceSession: practiceSession,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Resumen de sesión de práctica vinculada a un post.
class PracticeSessionSummary {
  final String id;
  final double score;
  final int correctNotes;
  final int totalNotes;
  final double totalTimeSeconds;
  final String? lessonTitle;

  const PracticeSessionSummary({
    required this.id,
    required this.score,
    required this.correctNotes,
    required this.totalNotes,
    required this.totalTimeSeconds,
    this.lessonTitle,
  });

  factory PracticeSessionSummary.fromJson(Map<String, dynamic> json) {
    return PracticeSessionSummary(
      id: (json['id'] as String?) ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      correctNotes: json['correct_notes'] as int? ?? 0,
      totalNotes: json['total_notes'] as int? ?? 0,
      totalTimeSeconds: (json['total_time_seconds'] as num?)?.toDouble() ?? 0.0,
      lessonTitle: json['lesson_title'] as String?,
    );
  }
}
