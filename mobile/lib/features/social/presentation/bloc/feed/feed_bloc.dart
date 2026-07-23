import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/network/network_error.dart';
import '../../../data/models/post_model.dart';
import '../../../data/repositories/social_repository.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final SocialRepository _socialRepository;

  FeedMode _mode = FeedMode.following;
  // Paginación por página para "Populares" (explore es page-based).
  int _explorePage = 1;
  int _explorePages = 1;

  FeedBloc({required SocialRepository socialRepository})
    : _socialRepository = socialRepository,
      super(const FeedInitial()) {
    on<FeedLoad>(_onLoad);
    on<FeedSwitchMode>(_onSwitchMode);
    on<FeedLoadMore>(_onLoadMore);
    on<FeedRefresh>(_onRefresh);
    on<FeedToggleLike>(_onToggleLike);
    on<FeedDeletePost>(_onDeletePost);
    on<FeedToggleSave>(_onToggleSave);
    on<FeedPostEdited>(_onPostEdited);
  }

  /// Carga la primera página del modo actual.
  Future<Map<String, dynamic>> _fetchFirstPage() async {
    switch (_mode) {
      case FeedMode.following:
        return _socialRepository.getFeed();
      case FeedMode.recent:
        return _socialRepository.getRecentFeed();
      case FeedMode.popular:
        _explorePage = 1;
        final result = await _socialRepository.getExplore(page: 1);
        _explorePages = result['pages'] as int? ?? 1;
        return {
          'items': result['items'],
          'next_cursor': null,
          'has_more': _explorePage < _explorePages,
        };
    }
  }

  Future<void> _onLoad(FeedLoad event, Emitter<FeedState> emit) async {
    emit(FeedLoading(mode: _mode));
    try {
      final result = await _fetchFirstPage();
      emit(
        FeedLoaded(
          posts: result['items'] as List<PostModel>,
          nextCursor: result['next_cursor'] as String?,
          hasMore: result['has_more'] as bool,
          mode: _mode,
        ),
      );
    } catch (e) {
      emit(
        FeedError(
          isConnectionError(e) ? offlineMessage : e.toString(),
          mode: _mode,
        ),
      );
    }
  }

  Future<void> _onSwitchMode(
    FeedSwitchMode event,
    Emitter<FeedState> emit,
  ) async {
    if (event.mode == _mode && state is FeedLoaded) return;
    _mode = event.mode;
    emit(FeedLoading(mode: _mode));
    try {
      final result = await _fetchFirstPage();
      emit(
        FeedLoaded(
          posts: result['items'] as List<PostModel>,
          nextCursor: result['next_cursor'] as String?,
          hasMore: result['has_more'] as bool,
          mode: _mode,
        ),
      );
    } catch (e) {
      emit(
        FeedError(
          isConnectionError(e) ? offlineMessage : e.toString(),
          mode: _mode,
        ),
      );
    }
  }

  Future<void> _onLoadMore(FeedLoadMore event, Emitter<FeedState> emit) async {
    final currentState = state;
    if (currentState is! FeedLoaded ||
        !currentState.hasMore ||
        currentState.isLoadingMore) {
      return;
    }

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      List<PostModel> newPosts;
      String? nextCursor;
      bool hasMore;
      switch (_mode) {
        case FeedMode.following:
          final result = await _socialRepository.getFeed(
            cursor: currentState.nextCursor,
          );
          newPosts = result['items'] as List<PostModel>;
          nextCursor = result['next_cursor'] as String?;
          hasMore = result['has_more'] as bool;
        case FeedMode.recent:
          final result = await _socialRepository.getRecentFeed(
            cursor: currentState.nextCursor,
          );
          newPosts = result['items'] as List<PostModel>;
          nextCursor = result['next_cursor'] as String?;
          hasMore = result['has_more'] as bool;
        case FeedMode.popular:
          _explorePage += 1;
          final result = await _socialRepository.getExplore(
            page: _explorePage,
          );
          newPosts = result['items'] as List<PostModel>;
          _explorePages = result['pages'] as int? ?? _explorePages;
          nextCursor = null;
          hasMore = _explorePage < _explorePages;
      }
      emit(
        FeedLoaded(
          posts: [...currentState.posts, ...newPosts],
          nextCursor: nextCursor,
          hasMore: hasMore,
          mode: _mode,
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onRefresh(FeedRefresh event, Emitter<FeedState> emit) async {
    try {
      final result = await _fetchFirstPage();
      emit(
        FeedLoaded(
          posts: result['items'] as List<PostModel>,
          nextCursor: result['next_cursor'] as String?,
          hasMore: result['has_more'] as bool,
          mode: _mode,
        ),
      );
    } catch (e) {
      emit(
        FeedError(
          isConnectionError(e) ? offlineMessage : e.toString(),
          mode: _mode,
        ),
      );
    }
  }

  Future<void> _onToggleLike(
    FeedToggleLike event,
    Emitter<FeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FeedLoaded) return;

    final updatedPosts = currentState.posts.map((post) {
      if (post.id == event.postId) {
        final newIsLiked = !post.isLikedByMe;
        return post.copyWith(
          isLikedByMe: newIsLiked,
          likesCount: post.likesCount + (newIsLiked ? 1 : -1),
        );
      }
      return post;
    }).toList();

    emit(currentState.copyWith(posts: updatedPosts));

    try {
      await _socialRepository.toggleLike(event.postId);
    } catch (_) {
      // Revertir en caso de error
      emit(currentState);
    }
  }

  Future<void> _onDeletePost(
    FeedDeletePost event,
    Emitter<FeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FeedLoaded) return;

    try {
      await _socialRepository.deletePost(event.postId);
      final updatedPosts = currentState.posts
          .where((p) => p.id != event.postId)
          .toList();
      emit(currentState.copyWith(posts: updatedPosts));
    } catch (e) {
      // No-op: mantener estado actual
    }
  }

  Future<void> _onToggleSave(
    FeedToggleSave event,
    Emitter<FeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FeedLoaded) return;

    final updatedPosts = currentState.posts.map((post) {
      if (post.id == event.postId) {
        return post.copyWith(isSavedByMe: !post.isSavedByMe);
      }
      return post;
    }).toList();

    emit(currentState.copyWith(posts: updatedPosts));

    try {
      await _socialRepository.toggleSave(event.postId);
    } catch (_) {
      emit(currentState);
    }
  }

  void _onPostEdited(FeedPostEdited event, Emitter<FeedState> emit) {
    final currentState = state;
    if (currentState is! FeedLoaded) return;

    final updatedPosts = currentState.posts.map((post) {
      if (post.id == event.postId) {
        return post.copyWith(content: event.content);
      }
      return post;
    }).toList();

    emit(currentState.copyWith(posts: updatedPosts));
  }
}
