import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/connectivity/offline_banner.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/auto_refresh_mixin.dart';
import '../../data/repositories/ranking_repository.dart';
import '../bloc/rankings/rankings_bloc.dart';
import '../bloc/rankings/rankings_event.dart';
import '../bloc/rankings/rankings_state.dart';
import '../widgets/leaderboard_tile.dart';
import '../../../tutor/presentation/tutor_targets.dart';

/// Pantalla principal de leaderboard con tabs: Global, Amigos, Semanal, Rachas.
class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen>
    with SingleTickerProviderStateMixin, AutoRefreshOnResume {
  late final TabController _tabController;
  late final RankingsBloc _bloc;

  @override
  void onAutoRefresh() {
    // Refresca el tab activo al reabrir la app.
    switch (_tabController.index) {
      case 1:
        _bloc.add(RankingsLoadFriends());
        break;
      case 2:
        _bloc.add(RankingsLoadWeekly());
        break;
      case 3:
        _bloc.add(RankingsLoadStreaks());
        break;
      default:
        _bloc.add(RankingsLoadGlobal());
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _bloc = RankingsBloc(rankingRepository: context.read<RankingRepository>())
      ..add(RankingsLoadGlobal());

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        switch (_tabController.index) {
          case 0:
            _bloc.add(RankingsLoadGlobal());
            break;
          case 1:
            _bloc.add(RankingsLoadFriends());
            break;
          case 2:
            _bloc.add(RankingsLoadWeekly());
            break;
          case 3:
            _bloc.add(RankingsLoadStreaks());
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          title: const Text('Rankings'),
          actions: [
            IconButton(
              icon: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => context.push('/my-xp'),
              tooltip: 'Mi XP',
            ),
            IconButton(
              icon: Icon(Icons.emoji_events, color: AppTheme.warning),
              onPressed: () => context.push('/achievements'),
              tooltip: 'Logros',
            ),
          ],
          bottom: TabBar(
            key: TutorTargets.keyFor('rankings_tabs'),
            controller: _tabController,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: const [
              Tab(text: 'Global'),
              Tab(text: 'Amigos'),
              Tab(text: 'Semanal'),
              Tab(text: 'Rachas'),
            ],
          ),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: BlocBuilder<RankingsBloc, RankingsState>(
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            state.message == offlineMessage
                                ? Icons.wifi_off_rounded
                                : Icons.error_outline,
                            color: state.message == offlineMessage
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
                            onPressed: () => _bloc.add(RankingsLoadGlobal()),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state is RankingsLoaded) {
                    return _buildLeaderboard(state);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard(RankingsLoaded state) {
    final leaderboard = state.leaderboard;

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        switch (_tabController.index) {
          case 0:
            _bloc.add(RankingsLoadGlobal());
            break;
          case 1:
            _bloc.add(RankingsLoadFriends());
            break;
          case 2:
            _bloc.add(RankingsLoadWeekly());
            break;
          case 3:
            _bloc.add(RankingsLoadStreaks());
            break;
        }
      },
      child: Column(
        children: [
          // Info card del usuario
          _buildMyRankCard(state),
          // Header info
          if (state.activeTab == 'weekly' && state.daysRemaining != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Resetea en ${state.daysRemaining} días',
                style: const TextStyle(color: AppTheme.warning, fontSize: 12),
              ),
            ),
          // Lista
          Expanded(
            child: leaderboard.isEmpty
                ? Center(
                    child: Text(
                      'No hay datos todavía',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: leaderboard.length,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemBuilder: (context, index) {
                      final entry = leaderboard[index];
                      return LeaderboardTile(
                        entry: entry,
                        isCurrentUser: entry.rank == state.myRank,
                        valueLabel: state.activeTab == 'streaks'
                            ? 'días'
                            : 'XP',
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRankCard(RankingsLoaded state) {
    return Container(
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
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _miniStat('Mi Posición', '#${state.myRank}'),
          _miniStat(
            state.activeTab == 'streaks' ? 'Mi Racha' : 'Mi XP',
            '${state.myXP}',
          ),
          if (state.activeTab != 'streaks')
            _miniStat('Mi Nivel', '${state.myLevel}'),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
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
    );
  }
}
