import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/services/lesson_download_service.dart';

/// Botón para descargar una lección y practicarla sin conexión.
///
/// Maneja su propio estado (verificando / no descargada / descargando /
/// descargada) leyendo el [LessonRepository] del árbol.
class LessonDownloadButton extends StatefulWidget {
  final String lessonId;

  const LessonDownloadButton({super.key, required this.lessonId});

  @override
  State<LessonDownloadButton> createState() => _LessonDownloadButtonState();
}

class _LessonDownloadButtonState extends State<LessonDownloadButton> {
  bool? _downloaded; // null = aún verificando
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final repo = context.read<LessonRepository>();
    final downloaded = await repo.isDownloaded(widget.lessonId);
    if (mounted) setState(() => _downloaded = downloaded);
  }

  Future<void> _download() async {
    setState(() => _busy = true);
    final repo = context.read<LessonRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.downloadLesson(widget.lessonId);
      if (!mounted) return;
      setState(() {
        _downloaded = true;
        _busy = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Lección disponible sin conexión')),
      );
    } on InsufficientStorageException {
      if (!mounted) return;
      setState(() => _busy = false);
      // Non-blocking: the app stays usable behind the dialog.
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Espacio insuficiente'),
          content: const Text(
            'No hay espacio libre para descargar esta lección. '
            'Liberá almacenamiento e intentá de nuevo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo descargar. Revisá tu conexión.'),
        ),
      );
    }
  }

  bool get _isPremium {
    final state = context.watch<AuthBloc>().state;
    if (state is AuthAuthenticated) return state.user.isPremium;
    if (state is AuthRegistered) return state.user.isPremium;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    // La descarga sin conexión es una función premium.
    if (!_isPremium && _downloaded != true) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () => context.push('/subscription/paywall'),
          icon: const Icon(Icons.workspace_premium, color: AppTheme.warning),
          label: const Text('Descargar sin conexión (Premium)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: AppTheme.warning.withValues(alpha: 0.5)),
            shape: shape,
          ),
        ),
      );
    }

    // Ya descargada: estado informativo en verde, no accionable.
    if (_downloaded == true) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.offline_pin_outlined, color: AppTheme.success),
          label: Text(
            'Disponible sin conexión',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppTheme.success.withValues(alpha: 0.4)),
            shape: shape,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _download,
        icon: _busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            : const Icon(Icons.download_for_offline_outlined),
        label: Text(
          _busy ? 'Descargando…' : 'Descargar para practicar sin conexión',
        ),
        style: OutlinedButton.styleFrom(shape: shape),
      ),
    );
  }
}
