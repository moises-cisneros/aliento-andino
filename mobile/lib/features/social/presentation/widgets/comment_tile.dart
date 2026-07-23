import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../data/models/comment_model.dart';
import '../../data/repositories/social_repository.dart';
import 'rich_post_text.dart';
import 'user_avatar.dart';

/// Tile de un comentario en la lista, con botón Reply y replies anidados expandibles.
class CommentTile extends StatefulWidget {
  final CommentModel comment;
  final VoidCallback? onUserTap;
  final VoidCallback? onDelete;
  /// Toggle like del comentario (bloc-backed para comentarios raíz). Si es null,
  /// el tile maneja el like localmente (caso de los replies cargados aparte).
  final VoidCallback? onLike;
  /// Editar el comentario (solo el dueño). Si es null no se muestra la opción.
  final VoidCallback? onEdit;
  /// Callback para crear un reply. Recibe el parentId.
  final void Function(String parentCommentId, String parentUsername)? onReply;
  /// Si es true, el tile se renderea como reply (indentado, avatar más chico).
  final bool isReply;

  const CommentTile({
    super.key,
    required this.comment,
    this.onUserTap,
    this.onDelete,
    this.onLike,
    this.onEdit,
    this.onReply,
    this.isReply = false,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  List<CommentModel>? _replies;
  bool _loadingReplies = false;
  bool _expanded = false;

  // Estado local del like (solo se usa cuando no hay onLike, p.ej. en replies).
  bool? _localLiked;
  int? _localLikesCount;

  Future<void> _handleLike() async {
    if (widget.onLike != null) {
      widget.onLike!();
      return;
    }
    // Reply: toggle optimista local contra el repositorio.
    final prevLiked = _localLiked ?? widget.comment.isLikedByMe;
    final prevCount = _localLikesCount ?? widget.comment.likesCount;
    setState(() {
      _localLiked = !prevLiked;
      _localLikesCount = prevCount + (!prevLiked ? 1 : -1);
    });
    try {
      await context.read<SocialRepository>().toggleCommentLike(
        widget.comment.id,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _localLiked = prevLiked;
          _localLikesCount = prevCount;
        });
      }
    }
  }

  Future<void> _toggleReplies() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    if (_replies == null) {
      setState(() => _loadingReplies = true);
      try {
        final replies = await context
            .read<SocialRepository>()
            .getReplies(widget.comment.id);
        if (!mounted) return;
        setState(() {
          _replies = replies;
          _loadingReplies = false;
          _expanded = true;
        });
      } catch (_) {
        if (mounted) setState(() => _loadingReplies = false);
      }
    } else {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final createdAt = DateTime.tryParse(widget.comment.createdAt);
    final timeAgo =
        createdAt != null ? timeago.format(createdAt, locale: 'es') : '';
    final avatarRadius = widget.isReply ? 14.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(widget.isReply ? 44 : 14, 6, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onUserTap,
                child: UserAvatar(user: widget.comment.user, radius: avatarRadius),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: widget.onUserTap,
                            child: Text(
                              widget.comment.user.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeAgo,
                          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11),
                        ),
                        const Spacer(),
                        _likeButton(cs),
                      ],
                    ),
                    const SizedBox(height: 3),
                    RichPostText(
                      text: widget.comment.content,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    // Acciones: Reply + ver replies
                    if (!widget.isReply) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (widget.onReply != null)
                            InkWell(
                              onTap: () => widget.onReply!(
                                widget.comment.id,
                                widget.comment.user.username,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                child: Text(
                                  'Responder',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          if (widget.onEdit != null) ...[
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: widget.onEdit,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                child: Text(
                                  'Editar',
                                  style: TextStyle(
                                    color: Theme.of(context).hintColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (widget.comment.repliesCount > 0) ...[
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: _toggleReplies,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      _expanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      size: 14,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      _expanded
                                          ? 'Ocultar'
                                          : '${widget.comment.repliesCount} ${widget.comment.repliesCount == 1 ? "respuesta" : "respuestas"}',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.onDelete != null)
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: Theme.of(context).hintColor),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (_loadingReplies)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_expanded && _replies != null)
            ..._replies!.map(
              (r) => CommentTile(
                comment: r,
                isReply: true,
                onUserTap: widget.onUserTap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _likeButton(ColorScheme cs) {
    final liked = _localLiked ?? widget.comment.isLikedByMe;
    final count = _localLikesCount ?? widget.comment.likesCount;
    return InkWell(
      onTap: _handleLike,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              size: 14,
              color: liked ? cs.primary : Theme.of(context).hintColor,
            ),
            if (count > 0) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
