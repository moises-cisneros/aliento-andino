import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/ranking_repository.dart';
import '../bloc/rankings/rankings_bloc.dart';
import '../bloc/rankings/rankings_event.dart';
import '../bloc/rankings/rankings_state.dart';
import '../widgets/xp_level_card.dart';
import '../widgets/streak_flame_widget.dart';
import '../../../../core/theme/app_theme.dart';

/// Pantalla de Mi XP con nivel, progreso y estadísticas detalladas.
class MyXPScreen extends StatefulWidget {
  const MyXPScreen({super.key});

  @override
  State<MyXPScreen> createState() => _MyXPScreenState();
}

class _MyXPScreenState extends State<MyXPScreen> {
  late final RankingsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = RankingsBloc(rankingRepository: context.read<RankingRepository>())
      ..add(RankingsLoadMyXP());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Mi Progreso XP')),
        body: BlocBuilder<RankingsBloc, RankingsState>(
          builder: (context, state) {
            if (state is RankingsLoading) {
              return Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }
            if (state is RankingsError) {
              return Center(
                child: Text(
                  state.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }
            if (state is MyXPLoaded) {
              return _buildContent(state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(MyXPLoaded state) {
    final xp = state.xpData;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Card de nivel con barra circular
          XPLevelCard(
            level: xp.level,
            totalXp: xp.totalXp,
            xpForCurrentLevel: xp.xpForCurrentLevel,
            xpForNextLevel: xp.xpForNextLevel,
            progressPercentage: xp.xpProgressPercentage,
          ),

          // Racha
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreakFlameWidget(streakDays: xp.currentStreak),
          ),

          // Congeladores de racha (protegen ante 1 día perdido)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _StreakFreezeCard(count: xp.streakFreezes),
          ),

          const SizedBox(height: 16),

          // Stats grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _statTile(
                  'XP Total',
                  '${xp.totalXp}',
                  Icons.star,
                  Theme.of(context).colorScheme.primary,
                ),
                _statTile(
                  'XP Semanal',
                  '${xp.weeklyXp}',
                  Icons.calendar_today,
                  AppTheme.success,
                ),
                _statTile(
                  'Mejor Racha',
                  '${xp.longestStreak} días',
                  Icons.whatshot,
                  AppTheme.orange,
                ),
                _statTile(
                  'Sesiones',
                  '${xp.totalSessions}',
                  Icons.music_note,
                  Theme.of(context).colorScheme.secondary,
                ),
                _statTile(
                  'Minutos',
                  '${xp.totalMinutes.toInt()}',
                  Icons.timer,
                  AppTheme.info,
                ),
                _statTile(
                  'Completadas',
                  '${xp.totalCompleted}',
                  Icons.check_circle,
                  AppTheme.success,
                ),
                _statTile(
                  'Perfectos',
                  '${xp.totalPerfect}',
                  Icons.auto_awesome,
                  AppTheme.warning,
                ),
                _statTile(
                  'Promedio',
                  '${xp.averageScore.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Rankings
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _rankCard('Rank Global', '#${xp.globalRank}')),
                const SizedBox(width: 8),
                Expanded(child: _rankCard('Rank Semanal', '#${xp.weeklyRank}')),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Botón logros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/achievements'),
                icon: const Icon(Icons.emoji_events),
                label: const Text('Ver Todos los Logros'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
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
      ),
    );
  }
}

/// Tarjeta de congeladores de racha: muestra cuántos tenés y qué hacen.
/// Se ganan cada 7 días de racha y se consumen solos si te salteás un día.
class _StreakFreezeCard extends StatelessWidget {
  final int count;
  const _StreakFreezeCard({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = count > 0;
    final accent = active ? const Color(0xFF38BDF8) : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.ac_unit, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 congelador de racha'
                      : '$count congeladores de racha',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? 'Protegen tu racha si te salteás un día'
                      : 'Ganás uno cada 7 días de racha',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
