import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/lesson_ranking_model.dart';
import '../../data/repositories/ranking_repository.dart';
import '../bloc/rankings/rankings_bloc.dart';
import '../bloc/rankings/rankings_event.dart';
import '../bloc/rankings/rankings_state.dart';
import '../../../../core/theme/app_theme.dart';

/// Pantalla de ranking de una lección específica.
class LessonRankingScreen extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;

  const LessonRankingScreen({
    super.key,
    required this.lessonId,
    this.lessonTitle = '',
  });

  @override
  State<LessonRankingScreen> createState() => _LessonRankingScreenState();
}

class _LessonRankingScreenState extends State<LessonRankingScreen> {
  late final RankingsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = RankingsBloc(rankingRepository: context.read<RankingRepository>())
      ..add(
        RankingsLoadLessonRanking(
          lessonId: widget.lessonId,
          lessonTitle: widget.lessonTitle,
        ),
      );
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
        appBar: AppBar(
          title: Text(
            widget.lessonTitle.isNotEmpty
                ? 'Ranking: ${widget.lessonTitle}'
                : 'Ranking de Lección',
          ),
        ),
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
            if (state is LessonRankingLoaded) {
              return _buildContent(state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(LessonRankingLoaded state) {
    return Column(
      children: [
        // Mi mejor score
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '#${state.myRank}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    'Mi Posición',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${state.myBestScore.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    'Mi Mejor Score',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Lista
        Expanded(
          child: state.leaderboard.isEmpty
              ? Center(
                  child: Text(
                    'Nadie ha jugado esta lección aún',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: state.leaderboard.length,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemBuilder: (context, index) {
                    final entry = state.leaderboard[index];
                    return _buildLessonTile(entry, entry.rank == state.myRank);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLessonTile(LessonRankingModel entry, bool isCurrentUser) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              )
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: entry.rank <= 3
                    ? [
                        AppTheme.gold,
                        AppTheme.silver,
                        AppTheme.bronze,
                      ][entry.rank - 1]
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            backgroundImage: entry.avatarUrl != null
                ? NetworkImage(entry.avatarUrl!)
                : null,
            child: entry.avatarUrl == null
                ? Text(
                    entry.username[0].toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          // Nombre
          Expanded(
            child: Text(
              entry.fullName,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Score
          Text(
            '${entry.score.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: AppTheme.success,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
