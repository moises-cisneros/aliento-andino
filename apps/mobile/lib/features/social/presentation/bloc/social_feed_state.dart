import 'package:equatable/equatable.dart';
import '../../data/models/post_model.dart';
import 'social_feed_event.dart';

abstract class FeedState extends Equatable {
  const FeedState();

  @override
  List<Object?> get props => [];
}

class FeedInitial extends FeedState {
  const FeedInitial();
}

class FeedLoading extends FeedState {
  /// Pestaña que se está cargando (para mantener la TabBar seleccionada).
  final FeedMode mode;
  const FeedLoading({this.mode = FeedMode.following});

  @override
  List<Object?> get props => [mode];
}

class FeedLoaded extends FeedState {
  final List<PostModel> posts;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final FeedMode mode;

  /// Causa real del último fallo de una acción (p. ej. aplauso); transitoria.
  final String? actionError;

  const FeedLoaded({
    required this.posts,
    this.nextCursor,
    required this.hasMore,
    this.isLoadingMore = false,
    this.mode = FeedMode.following,
    this.actionError,
  });

  FeedLoaded copyWith({
    List<PostModel>? posts,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
    FeedMode? mode,
    String? actionError,
  }) {
    return FeedLoaded(
      posts: posts ?? this.posts,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      mode: mode ?? this.mode,
      actionError: actionError,
    );
  }

  @override
  List<Object?> get props => [
    posts,
    nextCursor,
    hasMore,
    isLoadingMore,
    mode,
    actionError,
  ];
}

class FeedError extends FeedState {
  final String message;
  final FeedMode mode;
  const FeedError(this.message, {this.mode = FeedMode.following});

  @override
  List<Object?> get props => [message, mode];
}
