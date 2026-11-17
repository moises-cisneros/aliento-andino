import 'user_summary_model.dart';

/// Modelo de comentario en una publicación.
class CommentModel {
  final String id;
  final String postId;
  final String? parentCommentId;
  final int repliesCount;
  final int likesCount;
  final bool isLikedByMe;
  final UserSummaryModel user;
  final String content;
  final String createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    this.parentCommentId,
    this.repliesCount = 0,
    this.likesCount = 0,
    this.isLikedByMe = false,
    required this.user,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: (json['id'] as String?) ?? '',
      postId: (json['post_id'] as String?) ?? '',
      parentCommentId: json['parent_comment_id'] as String?,
      repliesCount: (json['replies_count'] as int?) ?? 0,
      likesCount: (json['likes_count'] as int?) ?? 0,
      isLikedByMe: (json['is_liked_by_me'] as bool?) ?? false,
      user: UserSummaryModel.fromJson(json['user'] as Map<String, dynamic>),
      content: (json['content'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }

  CommentModel copyWith({int? likesCount, bool? isLikedByMe, String? content}) {
    return CommentModel(
      id: id,
      postId: postId,
      parentCommentId: parentCommentId,
      repliesCount: repliesCount,
      likesCount: likesCount ?? this.likesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      user: user,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }
}
