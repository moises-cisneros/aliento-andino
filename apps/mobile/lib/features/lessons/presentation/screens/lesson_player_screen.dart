import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/lesson_model.dart';
import '../../data/models/note_sequence_model.dart';
import '../../data/repositories/lesson_repository.dart';
import '../bloc/lesson_player_bloc.dart';

/// Pantalla interactiva de reproducción y práctica musical (HU-04, SUB-04-B).
/// La melodía avanza nota a nota y compás a compás con ergonomía táctil (botones >= 48px, crítico >= 52px).
class LessonPlayerScreen extends StatelessWidget {
  final String lessonId;

  const LessonPlayerScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          LessonPlayerBloc(lessonRepository: ctx.read<LessonRepository>())
            ..add(LoadLessonPlayer(lessonId)),
      child: const _LessonPlayerView(),
    );
  }
}

class _LessonPlayerView extends StatelessWidget {
  const _LessonPlayerView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproductor de Lección'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reiniciar Lección',
            onPressed: () {
              context.read<LessonPlayerBloc>().add(const RestartPlayback());
            },
          ),
        ],
      ),
      body: BlocConsumer<LessonPlayerBloc, LessonPlayerState>(
        listener: (context, state) {
          if (state is LessonPlayerLoaded && state.isCompleted) {
            HapticFeedback.mediumImpact();
            _showCompletionDialog(context, state);
          }
        },
        builder: (context, state) {
          if (state is LessonPlayerLoading || state is LessonPlayerInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is LessonPlayerError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No se pudo cargar la lección',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(
                          160,
                          52,
                        ), // Botón crítico >= 52px
                      ),
                      onPressed: () {
                        final bloc = context.read<LessonPlayerBloc>();
                        if (bloc.state is LessonPlayerLoaded) {
                          bloc.add(
                            LoadLessonPlayer(
                              (bloc.state as LessonPlayerLoaded).lesson.id,
                            ),
                          );
                        }
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final loaded = state as LessonPlayerLoaded;
          return Column(
            children: [
              if (loaded.isOffline)
                Container(
                  width: double.infinity,
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_off, color: AppTheme.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Modo offline activo: practicando con notas almacenadas localmente.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Encabezado de la lección
              _LessonHeader(
                lesson: loaded.lesson,
                measure: loaded.currentMeasure,
              ),
              const Divider(height: 1),
              // Pentagrama y notas en desplazamiento visual
              Expanded(
                child: _VisualNotesDisplay(
                  notes: loaded.notes,
                  currentIndex: loaded.currentNoteIndex,
                  isPlaying: loaded.isPlaying,
                ),
              ),
              // Barra de progreso y precisión
              _ProgressHUD(
                progress: loaded.progress,
                score: loaded.score,
                correctCount: loaded.correctNotesCount,
                wrongCount: loaded.wrongNotesCount,
                currentIndex: loaded.currentNoteIndex,
                totalNotes: loaded.totalNotes,
              ),
              // Barra de controles de reproducción táctiles ergonómicos
              _PlayerControls(loaded: loaded),
            ],
          );
        },
      ),
    );
  }

  void _showCompletionDialog(BuildContext context, LessonPlayerLoaded state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.emoji_events, color: AppTheme.gold, size: 28),
              SizedBox(width: 8),
              Text('¡Lección Completada!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Puntaje final: ${state.score.toStringAsFixed(1)}%'),
              const SizedBox(height: 8),
              Text(
                'Notas correctas: ${state.correctNotesCount} / ${state.totalNotes}',
              ),
              Text('Notas erradas: ${state.wrongNotesCount}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<LessonPlayerBloc>().add(const RestartPlayback());
              },
              child: const Text('Practicar de nuevo'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Volver al Catálogo'),
            ),
          ],
        );
      },
    );
  }
}

class _LessonHeader extends StatelessWidget {
  final LessonModel lesson;
  final int measure;

  const _LessonHeader({required this.lesson, required this.measure});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lesson.instrument.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Compás $measure',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•  ${lesson.tempoBpm} BPM',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualNotesDisplay extends StatelessWidget {
  final List<NoteSequenceModel> notes;
  final int currentIndex;
  final bool isPlaying;

  const _VisualNotesDisplay({
    required this.notes,
    required this.currentIndex,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Center(
        child: Text('Esta lección no contiene notas registradas.'),
      );
    }

    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(notes.length, (index) {
              final note = notes[index];
              final isTarget = index == currentIndex;
              final isPast = index < currentIndex;

              Color noteColor;
              if (isTarget) {
                noteColor = AppTheme.cyan;
              } else if (isPast) {
                noteColor = AppTheme.success;
              } else {
                noteColor = Colors.white54;
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: EdgeInsets.symmetric(
                  horizontal: isTarget ? 16 : 10,
                  vertical: isTarget ? 16 : 10,
                ),
                decoration: BoxDecoration(
                  color: isTarget
                      ? AppTheme.cyan.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: noteColor,
                    width: isTarget ? 2.5 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note.note,
                      style: TextStyle(
                        color: noteColor,
                        fontSize: isTarget ? 24 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'pos ${note.position}',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: isTarget ? 11 : 9,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ProgressHUD extends StatelessWidget {
  final double progress;
  final double score;
  final int correctCount;
  final int wrongCount;
  final int currentIndex;
  final int totalNotes;

  const _ProgressHUD({
    required this.progress,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.currentIndex,
    required this.totalNotes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nota $currentIndex de $totalNotes',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                'Puntaje: ${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: score >= 80 ? AppTheme.success : AppTheme.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyan),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  final LessonPlayerLoaded loaded;

  const _PlayerControls({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LessonPlayerBloc>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Fila de controles principales
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón Reiniciar (>= 48px)
                IconButton(
                  iconSize: 28,
                  padding: const EdgeInsets.all(12), // Touch target >= 48px
                  icon: const Icon(Icons.replay),
                  tooltip: 'Reiniciar',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    bloc.add(const RestartPlayback());
                  },
                ),
                // Botón Play / Pause Crítico (>= 52px con diseño expandido)
                SizedBox(
                  width: 64,
                  height: 64, // Botón crítico >= 52px (Ley de Fitts)
                  child: FloatingActionButton(
                    heroTag: 'player_play_pause_fab',
                    elevation: 3,
                    backgroundColor: AppTheme.cyan,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      if (loaded.isPlaying) {
                        bloc.add(const PausePlayback());
                      } else {
                        bloc.add(const StartPlayback());
                      }
                    },
                    child: Icon(
                      loaded.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Botón Simular Acierto / Detección (>= 48px)
                IconButton(
                  iconSize: 28,
                  padding: const EdgeInsets.all(12), // Touch target >= 48px
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.success,
                  ),
                  tooltip: 'Evaluar Nota Correcta',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    bloc.add(
                      NoteEvaluated(
                        noteIndex: loaded.currentNoteIndex,
                        isCorrect: true,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Botones de práctica guiada interactiva
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(140, 48), // Ergonomía >= 48px
                  ),
                  icon: const Icon(
                    Icons.close,
                    color: AppTheme.error,
                    size: 18,
                  ),
                  label: const Text('Nota Fallida'),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    bloc.add(
                      NoteEvaluated(
                        noteIndex: loaded.currentNoteIndex,
                        isCorrect: false,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(140, 48), // Ergonomía >= 48px
                    backgroundColor: AppTheme.success,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Nota Afinada'),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    bloc.add(
                      NoteEvaluated(
                        noteIndex: loaded.currentNoteIndex,
                        isCorrect: true,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
