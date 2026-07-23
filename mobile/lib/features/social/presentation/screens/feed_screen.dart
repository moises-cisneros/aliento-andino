import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/connectivity/offline_banner.dart';
import '../../../../core/network/network_error.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/social_repository.dart';
import '../bloc/feed/feed_bloc.dart';
import '../bloc/feed/feed_event.dart';
import '../bloc/feed/feed_state.dart';
import '../widgets/create_post_fab.dart';
import '../widgets/edit_content_dialog.dart';
import '../widgets/post_card.dart';
import '../widgets/suggested_users_row.dart';
import '../widgets/report_dialog.dart';
import '../../../tutor/presentation/tutor_targets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/auto_refresh_mixin.dart';

/// Pantalla de feed principal con posts de seguidores.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          FeedBloc(socialRepository: ctx.read<SocialRepository>())
            ..add(const FeedLoad()),
      child: const _FeedView(),
    );
  }
}

class _FeedView extends StatefulWidget {
  const _FeedView();

  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView> with AutoRefreshOnResume {
  @override
  void onAutoRefresh() =>
      context.read<FeedBloc>().add(const FeedRefresh());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Feed'),
          actions: [
            IconButton(
              key: TutorTargets.keyFor('search_button'),
              icon: Icon(Icons.search, color: cs.onSurface),
              onPressed: () => context.push('/social/search'),
            ),
            const NotificationBell(),
          ],
          bottom: TabBar(
            key: TutorTargets.keyFor('feed_tabs'),
            // El orden de las tabs coincide con FeedMode.values.
            onTap: (index) => context.read<FeedBloc>().add(
              FeedSwitchMode(FeedMode.values[index]),
            ),
            labelColor: cs.primary,
            unselectedLabelColor: Theme.of(context).hintColor,
            indicatorColor: cs.primary,
            tabs: const [
              Tab(text: 'Siguiendo'),
              Tab(text: 'Populares'),
              Tab(text: 'Reciente'),
            ],
          ),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: _buildFeedBody(context)),
          ],
        ),
        floatingActionButton: CreatePostFab(
          onPressed: () => context.push('/social/create-post'),
        ),
      ),
    );
  }

  Widget _buildFeedBody(BuildContext context) {
    return BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          if (state is FeedLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }
          if (state is FeedError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.message == offlineMessage) ...[
                    Icon(
                      Icons.wifi_off_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    state.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<FeedBloc>().add(const FeedLoad()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is FeedLoaded) {
            if (state.posts.isEmpty) {
              // En "Siguiendo" mostramos sugerencias + CTA; en las otras pestañas
              // un vacío simple (no aplica "seguí a alguien").
              if (state.mode != FeedMode.following) {
                return ListView(
                  padding: const EdgeInsets.only(top: 64),
                  children: [
                    Icon(
                      Icons.feed_outlined,
                      color: Theme.of(context).hintColor,
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay publicaciones aún',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                children: [
                  const SuggestedUsersRow(),
                  const SizedBox(height: 32),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.feed_outlined,
                        color: Theme.of(context).hintColor,
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tu feed está vacío',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Seguí a otros usuarios para ver sus publicaciones',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/social/explore'),
                        icon: const Icon(Icons.explore),
                        label: const Text('Explorar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: () async {
                context.read<FeedBloc>().add(const FeedRefresh());
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (scroll) {
                  if (scroll.metrics.pixels >=
                      scroll.metrics.maxScrollExtent - 200) {
                    context.read<FeedBloc>().add(const FeedLoadMore());
                  }
                  return false;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.posts.length) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    }
                    final post = state.posts[index];
                    final authState = context.read<AuthBloc>().state;
                    final currentUserId = authState is AuthAuthenticated
                        ? authState.user.id
                        : null;
                    final isOwn =
                        currentUserId != null && post.user.id == currentUserId;
                    return PostCard(
                      post: post,
                      onTap: () => context.push('/social/post/${post.id}'),
                      onLike: () =>
                          context.read<FeedBloc>().add(FeedToggleLike(post.id)),
                      onComment: () => context.push('/social/post/${post.id}'),
                      onUserTap: () =>
                          context.push('/social/user/${post.user.id}'),
                      onSave: () =>
                          context.read<FeedBloc>().add(FeedToggleSave(post.id)),
                      saveButtonKey: index == 0
                          ? TutorTargets.keyFor('save_post_button')
                          : null,
                      onEdit: isOwn
                          ? () => _showEditPostDialog(context, post)
                          : null,
                      onDelete: isOwn
                          ? () => _confirmDeletePost(context, post.id)
                          : null,
                      onReport: isOwn
                          ? null
                          : () => _showReportDialog(context, postId: post.id),
                    );
                  },
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );
  }

  Future<void> _showEditPostDialog(BuildContext context, PostModel post) async {
    final feedBloc = context.read<FeedBloc>();
    final repo = context.read<SocialRepository>();
    final messenger = ScaffoldMessenger.of(context);

    final newContent = await showEditContentDialog(
      context,
      title: 'Editar publicación',
      initialText: post.content,
    );
    if (newContent == null) return;

    // Optimista: reflejar el cambio en el feed antes de la respuesta.
    feedBloc.add(FeedPostEdited(post.id, newContent));
    try {
      await repo.updatePost(post.id, newContent);
    } catch (_) {
      feedBloc.add(FeedPostEdited(post.id, post.content));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo editar la publicación'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showReportDialog(BuildContext context, {String? postId}) {
    final repo = context.read<SocialRepository>();
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (_) => ReportDialog(
        postId: postId,
        onSubmit: (reason, description) async {
          try {
            await repo.createReport(
              postId: postId,
              reason: reason,
              description: description,
            );
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Reporte enviado correctamente'),
                backgroundColor: AppTheme.success,
              ),
            );
          } catch (_) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Error al enviar el reporte'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDeletePost(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: Text(
          '¿Eliminar publicación?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Esta acción no se puede deshacer.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<FeedBloc>().add(FeedDeletePost(postId));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
