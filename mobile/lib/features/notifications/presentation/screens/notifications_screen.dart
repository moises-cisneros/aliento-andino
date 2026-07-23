import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../data/notification_model.dart';
import '../../data/notification_repository.dart';

/// Pantalla de campanita: lista de notificaciones del usuario con mark-as-read.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<NotificationListResult> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = context.read<NotificationRepository>().list();
    });
  }

  Future<void> _markAllRead() async {
    await context.read<NotificationRepository>().markAllRead();
    if (mounted) _reload();
  }

  Future<void> _onTap(NotificationModel n) async {
    if (!n.isRead) {
      await context.read<NotificationRepository>().markRead(n.id);
    }
    // Navegar según el tipo (best-effort)
    if (!mounted) return;
    final data = n.data ?? {};
    switch (n.type) {
      case 'like':
      case 'comment':
      case 'comment_reply':
      case 'mention':
        final postId = data['post_id'] as String?;
        if (postId != null) context.push('/social/post/$postId');
        break;
      case 'follow':
        final userId = data['user_id'] as String?;
        if (userId != null) context.push('/social/user/$userId');
        break;
      case 'achievement':
      case 'level_up':
        context.push('/achievements');
        break;
      case 'streak_warning':
        context.go('/lessons');
        break;
      default:
        break;
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text(
              'Marcar todas',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<NotificationListResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _emptyOrError('Error al cargar', Icons.error_outline);
          }
          final items = snapshot.data?.items ?? [];
          if (items.isEmpty) {
            return _emptyOrError(
              'Aún no tenés notificaciones',
              Icons.notifications_none,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Theme.of(context).dividerColor, height: 1),
              itemBuilder: (context, i) => _NotificationTile(
                notification: items[i],
                onTap: () => _onTap(items[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyOrError(String msg, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  IconData _iconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble;
      case 'comment_reply':
        return Icons.reply;
      case 'mention':
        return Icons.alternate_email;
      case 'follow':
        return Icons.person_add;
      case 'achievement':
        return Icons.emoji_events;
      case 'level_up':
        return Icons.trending_up;
      case 'streak_warning':
        return Icons.local_fire_department;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type, BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    switch (type) {
      case 'like':
        return Colors.pinkAccent;
      case 'comment':
      case 'comment_reply':
      case 'mention':
        return cs.secondary;
      case 'follow':
        return cs.primary;
      case 'achievement':
      case 'level_up':
        return const Color(0xFFF59E0B);
      case 'streak_warning':
        return Colors.deepOrange;
      default:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _colorForType(notification.type, context);
    final isUnread = !notification.isRead;

    return Material(
      color: isUnread
          ? cs.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconForType(notification.type), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notification.createdAt, locale: 'es'),
                      style: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, left: 8),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
