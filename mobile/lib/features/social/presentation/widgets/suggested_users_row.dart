import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user_summary_model.dart';
import '../../data/repositories/user_repository.dart';
import 'follow_button.dart';
import 'user_avatar.dart';

/// Carrusel horizontal de "A quién seguir". No ocupa espacio si no hay sugerencias.
class SuggestedUsersRow extends StatefulWidget {
  const SuggestedUsersRow({super.key});

  @override
  State<SuggestedUsersRow> createState() => _SuggestedUsersRowState();
}

class _SuggestedUsersRowState extends State<SuggestedUsersRow> {
  List<UserSummaryModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await context.read<UserRepository>().getSuggestions();
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(int index) async {
    final u = _users[index];
    final was = u.isFollowedByMe ?? false;
    setState(() => _users[index] = u.copyWith(isFollowedByMe: !was));
    try {
      await context.read<UserRepository>().toggleFollow(u.id);
    } catch (_) {
      if (mounted) setState(() => _users[index] = u);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _users.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'A quién seguir',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 184,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final u = _users[index];
              return Container(
                width: 150,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.surfaceContainerHighest),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/social/user/${u.id}'),
                      child: UserAvatar(imageUrl: u.avatarUrl, radius: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      u.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '@${u.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FollowButton(
                      isFollowing: u.isFollowedByMe ?? false,
                      onPressed: () => _toggle(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
