import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/practice/recordings_service.dart';

/// Biblioteca "Mis grabaciones": lista las grabaciones guardadas con un
/// reproductor (uno activo a la vez), y permite compartir y eliminar cada una.
class RecordingsListScreen extends StatefulWidget {
  const RecordingsListScreen({super.key});

  @override
  State<RecordingsListScreen> createState() => _RecordingsListScreenState();
}

class _RecordingsListScreenState extends State<RecordingsListScreen> {
  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  final RecordingsService _service = RecordingsService();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completeSub;

  List<Recording> _recordings = [];
  bool _loading = true;
  String? _playingId; // id de la grabación en reproducción (o null)
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _playingId = null;
        });
      }
    });
    _load();
  }

  Future<void> _load() async {
    final recs = await _service.getAll();
    if (mounted) {
      setState(() {
        _recordings = recs;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(Recording r) async {
    // Pausar/reanudar la que ya está activa.
    if (_playingId == r.id) {
      if (_playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
      } else {
        await _player.resume();
        if (mounted) setState(() => _playing = true);
      }
      return;
    }
    // Otra grabación: arrancar de cero (corta la anterior).
    await _player.stop();
    await _player.play(DeviceFileSource(r.filePath));
    if (mounted) {
      setState(() {
        _playingId = r.id;
        _playing = true;
      });
    }
  }

  Future<void> _share(Recording r) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(r.filePath)],
          subject: 'Mi práctica de "${r.lessonTitle}" en Aliento Andino',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo compartir la grabación.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(Recording r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('¿Eliminar grabación?'),
        content: const Text(
          'Se borrará de forma permanente de este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_playingId == r.id) {
      await _player.stop();
      if (mounted) {
        setState(() {
          _playing = false;
          _playingId = null;
        });
      }
    }
    await _service.delete(r.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Mis grabaciones')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _recordings.isEmpty
          ? _buildEmpty(cs)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _recordings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _buildTile(_recordings[i]),
            ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_none_rounded, color: cs.onSurfaceVariant, size: 56),
            const SizedBox(height: 16),
            Text(
              'Todavía no tenés grabaciones',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Durante una práctica, tocá el botón de grabar (●) en la barra '
              'para guardar tu interpretación acá.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(Recording r) {
    final cs = Theme.of(context).colorScheme;
    final playing = _playingId == r.id && _playing;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.surfaceContainerHighest),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _togglePlay(r),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: cs.primary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.lessonTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(r),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Compartir',
            icon: Icon(
              Icons.share_outlined,
              color: cs.onSurfaceVariant,
              size: 22,
            ),
            onPressed: () => _share(r),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: Icon(Icons.delete_outline, color: cs.error, size: 22),
            onPressed: () => _confirmDelete(r),
          ),
        ],
      ),
    );
  }

  String _subtitle(Recording r) {
    final parts = <String>[_fmtDate(r.date), '${r.score.round()}%'];
    if (r.durationMs > 0) parts.add(_fmtDuration(r.durationMs));
    return parts.join(' · ');
  }

  String _fmtDate(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} ${d.year}, $hh:$mm';
  }

  String _fmtDuration(int ms) {
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}
