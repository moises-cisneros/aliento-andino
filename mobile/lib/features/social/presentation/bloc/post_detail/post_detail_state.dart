import 'package:equatable/equatable.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/models/post_model.dart';

abstract class PostDetailState extends Equatable {
  const PostDetailState();

  @override
  List<Object?> get props => [];
}

class PostDetailInitial extends PostDetailState {
  const PostDetailInitial();
}

class PostDetailLoading extends PostDetailState {
  const PostDetailLoading();
}

class PostDetailLoaded extends PostDetailState {
  final PostModel post;
  final List<CommentModel> comments;
  final int commentsTotal;
  final int commentsPage;
  final bool hasMoreComments;
  final bool isSubmittingComment;

  const PostDetailLoaded({
    required this.post,
    required this.comments,
    required this.commentsTotal,
    required this.commentsPage,
    required this.hasMoreComments,
    this.isSubmittingComment = false,
  });

  PostDetailLoaded copyWith({
    PostModel? post,
    List<CommentModel>? comments,
    int? commentsTotal,
    int? commentsPage,
    bool? hasMoreComments,
    bool? isSubmittingComment,
  }) {
    return PostDetailLoaded(
      post: post ?? this.post,
      comments: comments ?? this.comments,
      commentsTotal: commentsTotal ?? this.commentsTotal,
      commentsPage: commentsPage ?? this.commentsPage,
      hasMoreComments: hasMoreComments ?? this.hasMoreComments,
      isSubmittingComment: isSubmittingComment ?? this.isSubmittingComment,
    );
  }

  @override
  List<Object?> get props => [
    post,
    comments,
    commentsTotal,
    commentsPage,
    hasMoreComments,
    isSubmittingComment,
  ];
}

class PostDetailError extends PostDetailState {
  final String message;
  const PostDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
