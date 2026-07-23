import 'package:flutter/material.dart';

import '../../../tutor/presentation/tutor_targets.dart';

/// FAB para crear nueva publicación.
class CreatePostFab extends StatelessWidget {
  final VoidCallback onPressed;

  const CreatePostFab({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: TutorTargets.keyFor('create_post_button'),
      onPressed: onPressed,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.edit, color: Colors.white),
    );
  }
}
