import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Abstracción mínima del reproductor del preview (inyectable en tests).
abstract class PostAudioPlayer {
  Future<void> play(String url);
  Future<void> stop();
  Stream<bool> get playing;
  void dispose();
}

class _AudioplayersPostPlayer implements PostAudioPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String url) => _player.play(UrlSource(url));

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<bool> get playing =>
      _player.onPlayerStateChanged.map((s) => s == PlayerState.playing);

  @override
  void dispose() => unawaited(_player.dispose());
}

/// Preview de audio de una publicación.
///
/// Si la reproducción falla muestra un icono de audio no disponible con la
/// causa real como tooltip, sin interrumpir la lectura del post.
class SocialAudioPreview extends StatefulWidget {
  final String url;
  final PostAudioPlayer Function()? playerFactory;

  const SocialAudioPreview({super.key, required this.url, this.playerFactory});

  /// Heurística por extensión: el contrato de posts solo expone `media_url`.
  static bool isAudioUrl(String? url) {
    if (url == null) return false;
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return const [
      '.mp3',
      '.m4a',
      '.aac',
      '.wav',
      '.ogg',
      '.opus',
    ].any(path.endsWith);
  }

  @override
  State<SocialAudioPreview> createState() => _SocialAudioPreviewState();
}

class _SocialAudioPreviewState extends State<SocialAudioPreview> {
  PostAudioPlayer? _player;
  StreamSubscription<bool>? _sub;
  bool _playing = false;
  String? _error;

  PostAudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = (widget.playerFactory ?? _AudioplayersPostPlayer.new)();
    _sub = p.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    }, onError: (Object e) => _fail(e));
    return _player = p;
  }

  void _fail(Object e) {
    if (mounted) {
      setState(() {
        _error = e.toString();
        _playing = false;
      });
    }
  }

  Future<void> _toggle() async {
    try {
      final p = _ensurePlayer();
      if (_playing) {
        await p.stop();
        if (mounted) setState(() => _playing = false);
      } else {
        await p.play(widget.url);
      }
    } catch (e) {
      _fail(e);
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_error != null) {
      return Tooltip(
        message: _error!,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(Icons.volume_off, color: cs.onSurfaceVariant, size: 24),
              const SizedBox(width: 8),
              Text(
                'Audio no disponible',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return Row(
      children: [
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: _playing ? 'Detener preview' : 'Escuchar preview',
          onPressed: _toggle,
          icon: Icon(
            _playing ? Icons.stop : Icons.play_arrow,
            color: cs.primary,
          ),
        ),
        Text(
          'Escuchar preview',
          style: TextStyle(color: cs.onSurface, fontSize: 13),
        ),
      ],
    );
  }
}
