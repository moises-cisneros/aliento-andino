import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/repositories/social_repository.dart';
import '../bloc/post_detail/post_detail_bloc.dart';
import '../bloc/post_detail/post_detail_event.dart';
import '../bloc/post_detail/post_detail_state.dart';
import '../widgets/comment_tile.dart';
import '../widgets/edit_content_dialog.dart';
import '../widgets/social_post_card.dart';
import '../widgets/report_dialog.dart';

/// Pantalla de detalle de un post con comentarios.
class PostDetailScreen extends StatelessWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          PostDetailBloc(socialRepository: ctx.read<SocialRepository>())
            ..add(PostDetailLoad(postId)),
      child: const _PostDetailView(),
    );
  }
}

class _PostDetailView extends StatefulWidget {
  const _PostDetailView();

  @override
  State<_PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<_PostDetailView> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  String? _replyingToCommentId;
  String? _replyingToUsername;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String username) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUsername = username;
    });
    _commentFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
  }

  Future<void> _sharePost(
    String postId,
    String? content,
    String username,
  ) async {
    final url = 'https://alientoandino.com/post/$postId';
    final text = content == null || content.isEmpty
        ? 'Mirá esta publicación de @$username en Aliento Andino 🎹\n$url'
        : '$content\n\n— @$username en Aliento Andino 🎹\n$url';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Publicación'),
        actions: [
          BlocBuilder<PostDetailBloc, PostDetailState>(
            builder: (context, state) {
              if (state is! PostDetailLoaded) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Compartir',
                onPressed: () => _sharePost(
                  state.post.id,
                  state.post.content,
                  state.post.user.username,
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<PostDetailBloc, PostDetailState>(
        builder: (context, state) {
          if (state is PostDetailLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }
          if (state is PostDetailError) {
            return Center(
              child: Text(
                state.message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          if (state is PostDetailLoaded) {
            return Column(
              children: [
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (scroll) {
                      if (scroll.metrics.pixels >=
                          scroll.metrics.maxScrollExtent - 200) {
                        context.read<PostDetailBloc>().add(
                          const PostDetailLoadMoreComments(),
                        );
                      }
                      return false;
                    },
                    child: ListView(
                      children: [
                        // Post
                        Builder(
                          builder: (context) {
                            final authState = context.read<AuthBloc>().state;
                            final currentUserId = authState is AuthAuthenticated
                                ? authState.user.id
                                : null;
                            final isOwnPost =
                                currentUserId != null &&
                                state.post.user.id == currentUserId;
                            return SocialPostCard(
                              post: state.post,
                              contentMaxLines: null,
                              onTap: () {},
                              onLike: () => context.read<PostDetailBloc>().add(
                                PostDetailToggleLike(),
                              ),
                              onComment: () {},
                              onUserTap: () => context.push(
                                '/social/user/${state.post.user.id}',
                              ),
                              onSave: () => context.read<PostDetailBloc>().add(
                                const PostDetailToggleSave(),
                              ),
                              onEdit: isOwnPost
                                  ? () => _editPost(context, state.post.content)
                                  : null,
                              onReport: isOwnPost
                                  ? null
                                  : () => _showReportDialog(
                                      context,
                                      postId: state.post.id,
                                    ),
                            );
                          },
                        ),
                        // Separador
                        Divider(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          height: 1,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Comentarios (${state.commentsTotal})',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        // Comentarios
                        ...state.comments.map((c) {
                          final authState = context.read<AuthBloc>().state;
                          final currentUserId = authState is AuthAuthenticated
                              ? authState.user.id
                              : null;
                          final isOwn =
                              currentUserId != null &&
                              c.user.id == currentUserId;
                          return CommentTile(
                            comment: c,
                            onUserTap: () =>
                                context.push('/social/user/${c.user.id}'),
                            onLike: () => context.read<PostDetailBloc>().add(
                              PostDetailToggleCommentLike(c.id),
                            ),
                            onEdit: isOwn
                                ? () => _editComment(context, c.id, c.content)
                                : null,
                            onDelete: isOwn
                                ? () => context.read<PostDetailBloc>().add(
                                    PostDetailDeleteComment(c.id),
                                  )
                                : null,
                            onReply: _startReply,
                          );
                        }),
                        if (state.hasMoreComments)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Input de comentario
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pill "Respondiendo a @user" si está en reply mode
                        if (_replyingToUsername != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Respondiendo a @$_replyingToUsername',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: _cancelReply,
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocus,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: _replyingToUsername != null
                                      ? 'Escribí tu respuesta…'
                                      : 'Escribe un comentario...',
                                  hintStyle: TextStyle(
                                    color: Theme.of(context).hintColor,
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BlocBuilder<PostDetailBloc, PostDetailState>(
                              builder: (context, s) {
                                final submitting =
                                    s is PostDetailLoaded &&
                                    s.isSubmittingComment;
                                return IconButton(
                                  onPressed: submitting
                                      ? null
                                      : () {
                                          final text = _commentController.text
                                              .trim();
                                          if (text.isEmpty) return;
                                          context.read<PostDetailBloc>().add(
                                            PostDetailAddComment(
                                              text,
                                              parentCommentId:
                                                  _replyingToCommentId,
                                            ),
                                          );
                                          _commentController.clear();
                                          _cancelReply();
                                        },
                                  icon: submitting
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        )
                                      : Icon(
                                          Icons.send,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future<void> _editPost(BuildContext context, String content) async {
    final bloc = context.read<PostDetailBloc>();
    final newContent = await showEditContentDialog(
      context,
      title: 'Editar publicación',
      initialText: content,
    );
    if (newContent != null) {
      bloc.add(PostDetailEditPost(newContent));
    }
  }

  Future<void> _editComment(
    BuildContext context,
    String commentId,
    String content,
  ) async {
    final bloc = context.read<PostDetailBloc>();
    final newContent = await showEditContentDialog(
      context,
      title: 'Editar comentario',
      initialText: content,
      maxLength: 500,
    );
    if (newContent != null) {
      bloc.add(PostDetailEditComment(commentId, newContent));
    }
  }

  void _showReportDialog(BuildContext context, {required String postId}) {
    showDialog(
      context: context,
      builder: (_) => ReportDialog(
        postId: postId,
        onSubmit: (reason, description) {
          context.read<SocialRepository>().createReport(
            postId: postId,
            reason: reason,
            description: description,
          );
        },
      ),
    );
  }
}
