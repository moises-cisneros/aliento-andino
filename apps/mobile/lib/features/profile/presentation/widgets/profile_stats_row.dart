import 'package:flutter/material.dart';

import '../../../social/data/models/user_profile_model.dart';

/// Fila de estadísticas: Posts | Seguidores | Siguiendo.
class ProfileStatsRow extends StatelessWidget {
  final UserProfileModel profile;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const ProfileStatsRow({
    super.key,
    required this.profile,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(count: profile.postsCount, label: 'Posts', onTap: null),
          Container(
            width: 1,
            height: 32,
            color: Theme.of(context).dividerColor,
          ),
          _StatItem(
            count: profile.followersCount,
            label: 'Seguidores',
            onTap: onFollowersTap,
          ),
          Container(
            width: 1,
            height: 32,
            color: Theme.of(context).dividerColor,
          ),
          _StatItem(
            count: profile.followingCount,
            label: 'Siguiendo',
            onTap: onFollowingTap,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback? onTap;

  const _StatItem({required this.count, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
