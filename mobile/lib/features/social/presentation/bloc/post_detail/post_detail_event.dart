import 'package:equatable/equatable.dart';

abstract class PostDetailEvent extends Equatable {
  const PostDetailEvent();

  @override
  List<Object?> get props => [];
}

class PostDetailLoad extends PostDetailEvent {
  final String postId;
  const PostDetailLoad(this.postId);

  @override
  List<Object?> get props => [postId];
}

class PostDetailToggleLike extends PostDetailEvent {
  const PostDetailToggleLike();
}

class PostDetailAddComment extends PostDetailEvent {
  final String content;
  final String? parentCommentId;
  const PostDetailAddComment(this.content, {this.parentCommentId});

  @override
  List<Object?> get props => [content, parentCommentId];
}

class PostDetailLoadMoreComments extends PostDetailEvent {
  const PostDetailLoadMoreComments();
}

class PostDetailDeleteComment extends PostDetailEvent {
  final String commentId;
  const PostDetailDeleteComment(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

/// Toggle guardar/bookmark el post mostrado.
class PostDetailToggleSave extends PostDetailEvent {
  const PostDetailToggleSave();
}

/// Editar el contenido del post mostrado (solo el autor).
class PostDetailEditPost extends PostDetailEvent {
  final String content;
  const PostDetailEditPost(this.content);

  @override
  List<Object?> get props => [content];
}

/// Toggle like en un comentario.
class PostDetailToggleCommentLike extends PostDetailEvent {
  final String commentId;
  const PostDetailToggleCommentLike(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

/// Editar el contenido de un comentario (solo el autor).
class PostDetailEditComment extends PostDetailEvent {
  final String commentId;
  final String content;
  const PostDetailEditComment(this.commentId, this.content);

  @override
  List<Object?> get props => [commentId, content];
}
