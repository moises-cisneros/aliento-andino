import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../rankings/data/repositories/ranking_repository.dart';
import '../../../rankings/presentation/bloc/achievements/achievements_bloc.dart';
import '../../../rankings/presentation/bloc/achievements/achievements_event.dart';
import '../../../rankings/presentation/bloc/achievements/achievements_state.dart';
import '../../data/models/achievement_model.dart';
import '../widgets/badge_item_widget.dart';

/// Vitrina de trofeos: insignias andinas con estado y fecha de obtención.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final AchievementsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = AchievementsBloc(
      rankingRepository: context.read<RankingRepository>(),
    )..add(AchievementsLoadAll());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mis insignias')),
        body: BlocBuilder<AchievementsBloc, AchievementsState>(
          builder: (context, state) {
            if (state is AchievementsLoading || state is AchievementsInitial) {
              return Center(
                child: CircularProgressIndicator(color: scheme.primary),
              );
            }
            if (state is AchievementsError) {
              return Center(
                child: Text(
                  state.message,
                  style: TextStyle(color: scheme.error),
                ),
              );
            }
            if (state is AchievementsLoaded) {
              final badges = state.achievements
                  .map(AchievementModel.fromRanking)
                  .toList();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${state.totalUnlocked}/${state.totalAvailable} '
                      'insignias desbloqueadas',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.95,
                          ),
                      itemCount: badges.length,
                      itemBuilder: (_, i) =>
                          BadgeItemWidget(achievement: badges[i]),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
