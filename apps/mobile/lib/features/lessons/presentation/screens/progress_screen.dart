import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/progress/progress_bloc.dart';
import '../bloc/progress/progress_event.dart';
import '../bloc/progress/progress_state.dart';
import '../widgets/score_circle.dart';
import '../widgets/weekly_chart.dart';
import '../../data/models/progress_stats_model.dart';
import '../../data/repositories/practice_repository.dart';
import '../../../../core/connectivity/offline_banner.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/auto_refresh_mixin.dart';
import '../../../tutor/presentation/tutor_targets.dart';

/// Pantalla de progreso general del usuario.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with AutoRefreshOnResume {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final bloc = context.read<ProgressBloc>();
    bloc.add(const ProgressLoadStats());
    bloc.add(const ProgressLoadWeekly());
    bloc.add(const ProgressLoadHistory());
  }

  @override
  void onAutoRefresh() => _load();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Mi Progreso')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: BlocBuilder<ProgressBloc, ProgressState>(
              builder: (context, state) {
                if (state is ProgressLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }

                if (state is ProgressError) {
                  final offline = state.message == offlineMessage;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          offline
                              ? Icons.wifi_off_rounded
                              : Icons.error_outline,
                          color: offline
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.message,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ProgressBloc>().add(
                              const ProgressLoadStats(),
                            );
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is ProgressLoaded) {
                  return _buildContent(state);
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ProgressLoaded state) {
    final stats = state.stats;

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        final bloc = context.read<ProgressBloc>();
        bloc.add(const ProgressLoadStats());
        bloc.add(const ProgressLoadWeekly());
        bloc.add(const ProgressLoadHistory());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stat cards row
          Row(
            key: TutorTargets.keyFor('progress_stats'),
            children: [
              Expanded(
                child: _statCard(
                  'Score Promedio',
                  '${stats.averageScore.toInt()}%',
                  Icons.speed,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Sesiones',
                  '${stats.totalSessions}',
                  Icons.music_note,
                  Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Racha',
                  '${stats.currentStreak} días',
                  Icons.local_fire_department,
                  AppTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Lecciones jugadas',
                  '${stats.totalLessonsPlayed}',
                  Icons.library_music,
                  AppTheme.success,
                ),
              ),
            ],
          ),

          // Gráfico semanal
          const SizedBox(height: 28),
          Text(
            'Progreso Semanal',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: WeeklyChart(data: state.weeklyData),
          ),

          // Desafíos de la semana
          const SizedBox(height: 28),
          const _WeeklyChallengesSection(),

          // Categoría favorita
          if (stats.favoriteCategory != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Categoría Favorita',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stats.favoriteCategory!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Historial de sesiones
          const SizedBox(height: 28),
          Text(
            'Historial Reciente',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (state.history.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  'No hay sesiones recientes',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...state.history.map(
              (session) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    ScoreCircle(score: session.score, size: 44, strokeWidth: 4),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.lessonTitle ?? 'Lección',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${session.correctNotes}/${session.totalNotes} notas · ${_formatDate(DateTime.tryParse(session.createdAt ?? ''))}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${session.score.toInt()}%',
                      style: TextStyle(
                        color: session.score >= 80
                            ? AppTheme.success
                            : session.score >= 50
                            ? AppTheme.warning
                            : Theme.of(context).colorScheme.error,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
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
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Sección de "Desafíos de la semana": una barra de progreso por reto + el
/// contador de días que faltan para que se renueven (lunes). Carga sola desde
/// el repositorio (no toca el ProgressBloc); si falla, no rompe la pantalla.
class _WeeklyChallengesSection extends StatefulWidget {
  const _WeeklyChallengesSection();

  @override
  State<_WeeklyChallengesSection> createState() =>
      _WeeklyChallengesSectionState();
}

class _WeeklyChallengesSectionState extends State<_WeeklyChallengesSection> {
  late final Future<
    ({List<WeeklyChallengeModel> challenges, int daysRemaining})
  >
  _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<PracticeRepository>().getWeeklyChallenges();
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'days':
        return Icons.calendar_today;
      case 'lessons80':
        return Icons.workspace_premium;
      case 'xp':
        return Icons.star;
      case 'sessions':
        return Icons.fitness_center;
      default:
        return Icons.flag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<
      ({List<WeeklyChallengeModel> challenges, int daysRemaining})
    >(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final data = snap.data;
        if (data == null || data.challenges.isEmpty) {
          return const SizedBox.shrink(); // sin datos / error: no romper
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Desafíos de la semana',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Resetea en ${data.daysRemaining} '
                  '${data.daysRemaining == 1 ? "día" : "días"}',
                  style: const TextStyle(color: AppTheme.warning, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...data.challenges.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _challengeCard(c),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _challengeCard(WeeklyChallengeModel c) {
    final cs = Theme.of(context).colorScheme;
    final accent = c.completed ? AppTheme.success : cs.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.completed
              ? AppTheme.success.withValues(alpha: 0.5)
              : cs.surfaceContainerHighest,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              c.completed ? Icons.check : _iconFor(c.key),
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${c.progress}/${c.target}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  c.description,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: c.fraction,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
