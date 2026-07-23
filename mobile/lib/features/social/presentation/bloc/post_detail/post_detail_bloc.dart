import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/repositories/social_repository.dart';
import 'post_detail_event.dart';
import 'post_detail_state.dart';

class PostDetailBloc extends Bloc<PostDetailEvent, PostDetailState> {
  final SocialRepository _socialRepository;
  late String _postId;

  PostDetailBloc({required SocialRepository socialRepository})
    : _socialRepository = socialRepository,
      super(const PostDetailInitial()) {
    on<PostDetailLoad>(_onLoad);
    on<PostDetailToggleLike>(_onToggleLike);
    on<PostDetailAddComment>(_onAddComment);
    on<PostDetailLoadMoreComments>(_onLoadMoreComments);
    on<PostDetailDeleteComment>(_onDeleteComment);
    on<PostDetailToggleSave>(_onToggleSave);
    on<PostDetailEditPost>(_onEditPost);
    on<PostDetailToggleCommentLike>(_onToggleCommentLike);
    on<PostDetailEditComment>(_onEditComment);
  }

  Future<void> _onLoad(
    PostDetailLoad event,
    Emitter<PostDetailState> emit,
  ) async {
    _postId = event.postId;
    emit(const PostDetailLoading());
    try {
      final post = await _socialRepository.getPostDetail(_postId);
      final commentsResult = await _socialRepository.getComments(_postId);
      final comments = commentsResult['items'] as List<CommentModel>;

      emit(
        PostDetailLoaded(
          post: post,
          comments: comments,
          commentsTotal: commentsResult['total'] as int,
          commentsPage: 1,
          hasMoreComments:
              (commentsResult['page'] as int) <
              (commentsResult['pages'] as int),
        ),
      );
    } catch (e) {
      emit(PostDetailError(e.toString()));
    }
  }

  Future<void> _onToggleLike(
    PostDetailToggleLike event,
    Emitter<PostDetailState> emit,
  ) async {
    final s = state;
    if (s is! PostDetailLoaded) return;

    final newIsLiked = !s.post.isLikedByMe;
    final optimistic = s.post.copyWith(
      isLikedByMe: newIsLiked,
      likesCount: s.post.likesCount + (newIsLiked ? 1 : -1),
    );
    emit(s.copyWith(post: optimistic));

    try {
      await _socialRepository.toggleLike(_postId);
    } catch (_) {
      emit(s);
    }
  }

  Future<void> _onAddComment(
    PostDetailAddComment event,
    Emitter<PostDetailState> emit,
  ) async {
    final s = state;
    if (s is! PostDetailLoaded) return;

    emit(s.copyWith(isSubmittingComment: true));
    try {
      final comment = await _socialRepository.createComment(
        _postId,
        event.content,
        parentCommentId: event.parentCommentId,
      );

      // Si es un reply, no agregar a la lista principal — solo incrementar
      // el counter de replies del parent (la UI lo cargará al expandir).
      if (event.parentCommentId != null) {
        final updatedComments = s.comments.map((c) {
          if (c.id == event.parentCommentId) {
            return CommentModel(
              id: c.id,
              postId: c.postId,
              parentCommentId: c.parentCommentId,
              repliesCount: c.repliesCount + 1,
              likesCount: c.likesCount,
              isLikedByMe: c.isLikedByMe,
              user: c.user,
              content: c.content,
              createdAt: c.createdAt,
            );
          }
          return c;
        }).toList();
        final updatedPost = s.post.copyWith(
          commentsCount: s.post.commentsCount + 1,
        );
        emit(
          s.copyWith(
            post: updatedPost,
            comments: updatedComments,
            commentsTotal: s.commentsTotal + 1,
            isSubmittingComment: false,
          ),
        );
        return;
      }

      // Comentario raíz: prepend a la lista
      final updatedPost = s.post.copyWith(
        commentsCount: s.post.commentsCount + 1,
      );
      emit(
        s.copyWith(
          post: updatedPost,
          comments: [comment, ...s.comments],
          commentsTotal: s.commentsTotal + 1,
          isSubmittingComment: false,
        ),
      );
    } catch (e) {
      emit(s.copyWith(isSubmittingComment: false));
    }
  }

  Future<void> _onLoadMoreComments(
    PostDetailLoadMoreComments event,
    Emitter<PostDetailState> emit,
  ) async {
    final s = state;
    if (s is! PostDetailLoaded || !s.hasMoreComments) return;

    try {
      final nextPage = s.commentsPage + 1;
      final result = await _socialRepository.getComments(
        _postId,
        page: nextPage,
      );
      final newComments = result['items'] as List<CommentModel>;

      emit(
        s.copyWith(
          comments: [...s.comments, ...newComments],
          commentsPage: nextPage,
          hasMoreComments: nextPage < (result['pages'] as int),
        ),
      );
    } catch (_) {
      // No-op
    }
  }

  Future<void> _onDeleteComment(
    PostDetailDeleteComment event,
    Emitter<PostDetailState> emit,
  ) async {
    final s = state;
    if (s is! PostDetailLoaded) return;

    try {
      await _socialRepository.deleteComment(_postId, event.commentId);
      final updatedComments = s.comments
          .where((c) => c.id != event.commentId)
          .toList();
      final updatedPost = s.post.copyWith(
        commentsCount: s.post.commentsCount - 1,
      );
      emit(
        s.copyWith(
          post: updatedPost,
          comments: updatedComments,
          commentsTotal: s.commentsTotal - 1,
        ),
      );
    } catch (_) {
      // No-op
    }
  }

  Future<void> _onToggleSave(
    PostDetailToggleSave event,
    Emitter<PostDetailState> emit,
  ) async {
    final s = state;
    if (s is! PostDetailLoaded) return;

    final optimistic = s.post.copyWith(isSavedByMe: !s.post.isSavedByMe);
    emit(s.copyWith(post: optimistic));

    try {
      await _socialRepository.toggleSave(_postId);
    } catch (_) {
      emit(s);
    }
  }

  Future<void> _onEditPost(
    PostDetailEditPost event,
    Emitter<PostDetailState> emit,
  ) async {
    final s = state;
    if (s is! PostDetailLoaded) return;

    final previous = s.post;
    emit(s.copyWith(post: previous.copyWith(content: event.content)));

    try {
      await _socialRepository.updatePost(_postId, event.content);
    } catch (_) {
      emit(s.copyWith(post: previous));
    }
  }

  Future<void> _onToggleCommentLike(
    PostDetailToggleCommentLike event,
    Emitter<PostDetailState> emit,
  ) async {
    final s = state;
    if (s is! PostDetailLoaded) return;

    final updatedComments = s.comments.map((c) {
      if (c.id == event.commentId) {
        final liked = !c.isLikedByMe;
        return c.copyWith(
          isLikedByMe: liked,
          likesCount: c.likesCount + (liked ? 1 : -1),
        );
      }
      return c;
    }).toList();
    emit(s.copyWith(comments: updatedComments));

    try {
      await _socialRepository.toggleCommentLike(event.commentId);
    } catch (_) {
      emit(s);
    }
  }

  Future<void> _onEditComment(
    PostDetailEditComment event,
    Emitter<PostDetailState> emit,
  ) async {
    final s = state;
    if (s is! PostDetailLoaded) return;

    final updatedComments = s.comments.map((c) {
      if (c.id == event.commentId) {
        return c.copyWith(content: event.content);
      }
      return c;
    }).toList();
    emit(s.copyWith(comments: updatedComments));

    try {
      await _socialRepository.updateComment(event.commentId, event.content);
    } catch (_) {
      emit(s);
    }
  }
}
