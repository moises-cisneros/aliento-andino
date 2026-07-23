import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/user_repository.dart';

/// Resuelve un username (de una @mención) a su id y redirige al perfil.
class MentionResolverScreen extends StatefulWidget {
  final String username;

  const MentionResolverScreen({super.key, required this.username});

  @override
  State<MentionResolverScreen> createState() => _MentionResolverScreenState();
}

class _MentionResolverScreenState extends State<MentionResolverScreen> {
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final id = await context.read<UserRepository>().getUserIdByUsername(
        widget.username,
      );
      if (!mounted) return;
      context.pushReplacement('/social/user/$id');
    } catch (_) {
      if (mounted) setState(() => _notFound = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text('@${widget.username}')),
      body: Center(
        child: _notFound
            ? Text(
                'Usuario no encontrado',
                style: TextStyle(color: cs.onSurfaceVariant),
              )
            : CircularProgressIndicator(color: cs.primary),
      ),
    );
  }
}
