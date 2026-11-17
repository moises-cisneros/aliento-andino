import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/lesson_repository.dart';
import '../../data/services/lesson_download_service.dart';
import '../widgets/offline_badge_widget.dart';

/// Manages the lessons downloaded for offline practice: shows the space they
/// use and lets the user delete them.
class OfflineLessonsScreen extends StatefulWidget {
  const OfflineLessonsScreen({super.key});

  @override
  State<OfflineLessonsScreen> createState() => _OfflineLessonsScreenState();
}

class _OfflineLessonsScreenState extends State<OfflineLessonsScreen> {
  OfflineDownloads? _downloads;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<LessonRepository>();
    try {
      final downloads = await repo.getOfflineDownloads();
      if (!mounted) return;
      setState(() {
        _downloads = downloads;
        _error = null;
      });
      if (downloads.stale.isNotEmpty) {
        // Looked up after the await: it cannot be done from initState.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${downloads.stale.length} lección(es) perdieron su audio y '
              'quedaron marcadas para volver a descargar.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _delete(OfflineDownloadEntry entry) async {
    final repo = context.read<LessonRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar descarga'),
        content: Text(
          '¿Eliminar "${entry.lesson.title}" de tu dispositivo? '
          'Vas a necesitar conexión para volver a practicarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const ValueKey('confirm-delete'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repo.deleteDownloadedLesson(entry.lesson.id);
      if (!mounted) return;
      await _load();
      messenger.showSnackBar(
        const SnackBar(content: Text('Descarga eliminada')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la descarga')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lecciones sin conexión')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final downloads = _downloads;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudieron leer las descargas'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (downloads == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (downloads.entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Todavía no descargaste lecciones. Abrí una lección y tocá '
            '"Descargar para practicar sin conexión".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.storage_rounded),
          title: Text(
            '${downloads.entries.length} descargada(s) · '
            '${formatBytes(downloads.totalBytes)} en uso',
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: downloads.entries.length,
            itemBuilder: (context, i) {
              final entry = downloads.entries[i];
              return ListTile(
                key: ValueKey('offline-${entry.lesson.id}'),
                leading: const OfflineBadgeWidget(isDownloaded: true, size: 24),
                title: Text(entry.lesson.title),
                subtitle: Text(
                  '${entry.lesson.instrument} · '
                  '${formatBytes(entry.audioBytes)}',
                ),
                trailing: IconButton(
                  key: ValueKey('delete-${entry.lesson.id}'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar descarga',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => _delete(entry),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Human readable size, e.g. `1.5 MB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
