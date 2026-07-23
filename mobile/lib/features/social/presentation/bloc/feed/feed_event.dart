import 'package:equatable/equatable.dart';

/// Pestañas del feed.
enum FeedMode { following, popular, recent }

abstract class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar feed inicial.
class FeedLoad extends FeedEvent {
  const FeedLoad();
}

/// Cambiar de pestaña (Siguiendo / Populares / Reciente).
class FeedSwitchMode extends FeedEvent {
  final FeedMode mode;
  const FeedSwitchMode(this.mode);

  @override
  List<Object?> get props => [mode];
}

/// Cargar más posts (paginación cursor).
class FeedLoadMore extends FeedEvent {
  const FeedLoadMore();
}

/// Refrescar feed (pull-to-refresh).
class FeedRefresh extends FeedEvent {
  const FeedRefresh();
}

/// Toggle like en un post del feed.
class FeedToggleLike extends FeedEvent {
  final String postId;
  const FeedToggleLike(this.postId);

  @override
  List<Object?> get props => [postId];
}

/// Eliminar un post del feed.
class FeedDeletePost extends FeedEvent {
  final String postId;
  const FeedDeletePost(this.postId);

  @override
  List<Object?> get props => [postId];
}

/// Toggle guardar/bookmark un post del feed.
class FeedToggleSave extends FeedEvent {
  final String postId;
  const FeedToggleSave(this.postId);

  @override
  List<Object?> get props => [postId];
}

/// Reflejar la edición de un post en el feed (tras editar en otra pantalla).
class FeedPostEdited extends FeedEvent {
  final String postId;
  final String content;
  const FeedPostEdited(this.postId, this.content);

  @override
  List<Object?> get props => [postId, content];
}
