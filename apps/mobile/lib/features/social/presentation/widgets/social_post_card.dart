import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/post_model.dart';
import 'applause_button.dart';
import 'social_audio_preview.dart';
import 'practice_result_card.dart';
import 'rich_post_text.dart';
import 'user_avatar.dart';

/// Tarjeta de publicación para el feed.
class SocialPostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onUserTap;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onSave;
  final VoidCallback? onEdit;

  /// Líneas máximas del contenido antes de "Ver más" (null = sin límite).
  final int? contentMaxLines;

  /// Key opcional sobre el botón de guardar, para que el tutor IA lo resalte.
  final Key? saveButtonKey;

  const SocialPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onComment,
    required this.onUserTap,
    this.onDelete,
    this.onReport,
    this.onSave,
    this.onEdit,
    this.contentMaxLines = 6,
    this.saveButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(post.createdAt);
    final timeAgo = createdAt != null
        ? timeago.format(createdAt, locale: 'es')
        : '';

    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: avatar + nombre + tiempo + menú
              Row(
                children: [
                  GestureDetector(
                    onTap: onUserTap,
                    child: UserAvatar(user: post.user, radius: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onUserTap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.user.fullName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '@${post.user.username} · $timeAgo',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onDelete != null || onReport != null || onEdit != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Theme.of(context).hintColor,
                        size: 20,
                      ),
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                        if (value == 'report') onReport?.call();
                      },
                      itemBuilder: (_) => [
                        if (onEdit != null)
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(
                              'Editar',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        if (onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Eliminar',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        if (onReport != null)
                          PopupMenuItem(
                            value: 'report',
                            child: Text(
                              'Reportar',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Contenido (con @menciones y #hashtags clickeables)
              RichPostText(text: post.content, maxLines: contentMaxLines),
              // Resultado de práctica
              if (post.practiceSession != null) ...[
                const SizedBox(height: 10),
                PracticeResultCard(session: post.practiceSession!),
              ],
              // Audio preview (falla sin interrumpir la lectura)
              if (SocialAudioPreview.isAudioUrl(post.mediaUrl)) ...[
                const SizedBox(height: 10),
                SocialAudioPreview(url: post.mediaUrl!),
              ],
              // Imagen
              if (post.mediaUrl != null &&
                  !SocialAudioPreview.isAudioUrl(post.mediaUrl)) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    post.mediaUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // Acciones
              Row(
                children: [
                  ApplauseButton(
                    isApplauded: post.isLikedByMe,
                    count: post.likesCount,
                    onPressed: onLike,
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: onComment,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Theme.of(context).hintColor,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${post.commentsCount}',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onSave != null) ...[
                    const Spacer(),
                    InkWell(
                      key: saveButtonKey,
                      onTap: onSave,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Icon(
                          post.isSavedByMe
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: post.isSavedByMe
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).hintColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
