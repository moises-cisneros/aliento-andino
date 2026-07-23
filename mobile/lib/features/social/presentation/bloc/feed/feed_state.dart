import 'package:equatable/equatable.dart';
import '../../../data/models/post_model.dart';
import 'feed_event.dart';

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

  const FeedLoaded({
    required this.posts,
    this.nextCursor,
    required this.hasMore,
    this.isLoadingMore = false,
    this.mode = FeedMode.following,
  });

  FeedLoaded copyWith({
    List<PostModel>? posts,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
    FeedMode? mode,
  }) {
    return FeedLoaded(
      posts: posts ?? this.posts,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      mode: mode ?? this.mode,
    );
  }

  @override
  List<Object?> get props => [posts, nextCursor, hasMore, isLoadingMore, mode];
}

class FeedError extends FeedState {
  final String message;
  final FeedMode mode;
  const FeedError(this.message, {this.mode = FeedMode.following});

  @override
  List<Object?> get props => [message, mode];
}
