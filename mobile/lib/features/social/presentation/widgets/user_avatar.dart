import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../data/models/user_summary_model.dart';

/// Avatar circular de usuario con imagen de red o iniciales.
class UserAvatar extends StatelessWidget {
  final UserSummaryModel? user;
  final String? imageUrl;
  final double radius;

  const UserAvatar({super.key, this.user, this.imageUrl, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? user?.avatarUrl;
    final name = user?.fullName ?? '?';

    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (_, provider) =>
            CircleAvatar(radius: radius, backgroundImage: provider),
        placeholder: (ctx, url) => CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (ctx, url, err) => _initialsAvatar(context, name),
      );
    }
    return _initialsAvatar(context, name);
  }

  Widget _initialsAvatar(BuildContext context, String name) {
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
