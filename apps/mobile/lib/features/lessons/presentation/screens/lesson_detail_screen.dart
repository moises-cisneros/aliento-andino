import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/instrument_service.dart';
import '../../../../core/audio/melody_player.dart';
import '../../../../core/audio/tone_synth.dart';
import '../../data/models/note_sequence_model.dart';
import '../bloc/lesson_detail/lesson_detail_bloc.dart';
import '../bloc/lesson_detail/lesson_detail_event.dart';
import '../bloc/lesson_detail/lesson_detail_state.dart';
import '../widgets/audio_preview_button.dart';
import '../widgets/difficulty_badge.dart';
import '../widgets/lesson_download_button.dart';
import '../widgets/note_sequence_viewer.dart';
import '../widgets/piano_guide_widget.dart';
import '../widgets/staff_view.dart';

/// Pantalla de detalle de una lección.
class LessonDetailScreen extends StatefulWidget {
  final String lessonId;

  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<LessonDetailBloc>().add(LessonDetailLoad(widget.lessonId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<LessonDetailBloc, LessonDetailState>(
        builder: (context, state) {
          if (state is LessonDetailLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          if (state is LessonDetailError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<LessonDetailBloc>().add(
                      LessonDetailLoad(widget.lessonId),
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (state is LessonDetailLoaded) {
            return _buildDetail(context, state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDetail(BuildContext context, LessonDetailLoaded state) {
    final lesson = state.lesson;
    final notes = state.notes;

    // Extraer notas únicas para el piano
    final uniqueNotes = notes
        .where((n) => !n.isRest)
        .map((n) => n.note)
        .toSet();

    return CustomScrollView(
      slivers: [
        // Header colapsable
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              lesson.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.music_note,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadatos
                Row(
                  children: [
                    DifficultyBadge(difficulty: lesson.difficulty),
                    SizedBox(width: 12),
                    Icon(
                      Icons.speed,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${lesson.tempoBpm} BPM',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.music_note,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      // Solo notas tocables (sin silencios), para coincidir con
                      // el conteo de la práctica ("Nota X de Y").
                      '${notes.where((n) => !n.isRest).length} notas',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                // Descripción
                if (lesson.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    lesson.description,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],

                // Audio preview si existe
                if (lesson.audioPreviewUrl != null &&
                    lesson.audioPreviewUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AudioPreviewButton(
                    url: lesson.audioPreviewUrl!,
                    lessonId: widget.lessonId,
                  ),
                ],

                // Progreso del usuario
                if (state.userBestScore != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem(
                          'Mejor Score',
                          '${state.userBestScore!.toInt()}%',
                        ),
                        _statItem('Intentos', '${state.userAttempts}'),
                      ],
                    ),
                  ),
                ],

                // Secuencia de notas
                const SizedBox(height: 24),
                Text(
                  'Secuencia de Notas',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                NoteSequenceViewer(notes: notes),

                // Escuchar la melodía (con cámara lenta)
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ListenSection(notes: notes, bpm: lesson.tempoBpm),
                ],

                // Partitura (notación en pentagrama doble, desplazable)
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Partitura',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    child: StaffView(notes: notes),
                  ),
                ],

                // Piano guía
                const SizedBox(height: 24),
                Text(
                  'Teclas Utilizadas',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                PianoGuideWidget(
                  highlightNotes: uniqueNotes,
                  rangeNotes: uniqueNotes,
                  minOctaves: lesson.difficulty.toLowerCase() == 'principiante'
                      ? 2
                      : 3,
                ),

                // Botón iniciar práctica
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/practice/${widget.lessonId}'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text(
                      'Iniciar Práctica',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Descargar para practicar sin conexión
                const SizedBox(height: 12),
                LessonDownloadButton(lessonId: widget.lessonId),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Sección "Escuchar la melodía" con control de velocidad (cámara lenta).
class _ListenSection extends StatefulWidget {
  final List<NoteSequenceModel> notes;
  final int bpm;
  const _ListenSection({required this.notes, required this.bpm});

  @override
  State<_ListenSection> createState() => _ListenSectionState();
}

class _ListenSectionState extends State<_ListenSection> {
  final ToneSynth _synth = ToneSynth();
  late final MelodyPlayer _player = MelodyPlayer(_synth);
  bool _playing = false;
  double _tempo = 1.0;

  @override
  void initState() {
    super.initState();
    InstrumentService().get().then((i) {
      if (mounted) _synth.instrument = i;
    });
  }

  @override
  void dispose() {
    _player.stop();
    _synth.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_playing) {
      _player.stop();
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      _player.play(
        widget.notes,
        bpm: widget.bpm,
        tempo: _tempo,
        onDone: () {
          if (mounted) setState(() => _playing = false);
        },
      );
    }
  }

  void _setTempo(double t) {
    setState(() => _tempo = t);
    if (_playing) {
      // Reiniciar la reproducción al nuevo tempo.
      _player.stop();
      _player.play(
        widget.notes,
        bpm: widget.bpm,
        tempo: _tempo,
        onDone: () {
          if (mounted) setState(() => _playing = false);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tempoChip(String label, double t) {
      final selected = _tempo == t;
      return GestureDetector(
        onTap: () => _setTempo(t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : cs.onSurfaceVariant,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: cs.primary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _playing ? 'Reproduciendo…' : 'Escuchar la melodía',
              style: TextStyle(color: cs.onSurface, fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                tempoChip('0.5×', 0.5),
                tempoChip('0.75×', 0.75),
                tempoChip('1×', 1.0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
