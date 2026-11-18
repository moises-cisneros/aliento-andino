import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/instrument.dart';
import '../../data/models/leaderboard_model.dart';
import '../../data/repositories/ranking_repository.dart';
import '../bloc/leaderboard/leaderboard_bloc.dart';
import '../widgets/podium_widget.dart';

/// Leaderboard semanal por instrumento andino: tabs en la cabecera, podio
/// animado con los 3 primeros y lista del resto (HU-12 / SUB-12-B).
class LeaderboardScreen extends StatefulWidget {
  final InstrumentType initialInstrument;

  const LeaderboardScreen({
    super.key,
    this.initialInstrument = InstrumentType.quena,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final LeaderboardBloc _bloc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: InstrumentType.values.length,
      vsync: this,
      initialIndex: widget.initialInstrument.index,
    );
    _bloc = LeaderboardBloc(
      rankingRepository: context.read<RankingRepository>(),
      initialInstrument: widget.initialInstrument,
    )..add(LeaderboardInstrumentSelected(widget.initialInstrument));

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _bloc.add(
          LeaderboardInstrumentSelected(
            InstrumentType.values[_tabController.index],
          ),
        );
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
    final colorScheme = Theme.of(context).colorScheme;

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ranking semanal'),
          bottom: TabBar(
            key: const Key('leaderboard-tabs'),
            controller: _tabController,
            indicatorColor: colorScheme.primary,
            labelColor: colorScheme.primary,
            tabs: [
              for (final instrument in InstrumentType.values)
                Tab(
                  key: Key('leaderboard-tab-${instrument.name}'),
                  height: 48, // Ley de Fitts
                  text: instrument.displayName,
                ),
            ],
          ),
        ),
        body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
          builder: (context, state) {
            switch (state.status) {
              case LeaderboardStatus.initial:
              case LeaderboardStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case LeaderboardStatus.failure:
                return _ErrorView(
                  message: state.message ?? 'Error al cargar el ranking',
                  onRetry: () => _bloc.add(const LeaderboardRefreshed()),
                );
              case LeaderboardStatus.success:
                return _LeaderboardBody(state: state);
            }
          },
        ),
      ),
    );
  }
}

class _LeaderboardBody extends StatelessWidget {
  final LeaderboardState state;

  const _LeaderboardBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rest = state.items.skip(3).toList();

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => context.read<LeaderboardBloc>().add(
              const LeaderboardRefreshed(),
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (state.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Aún no hay prácticas de ${state.instrument.displayName} esta semana.',
                      key: const Key('leaderboard-empty'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  PodiumWidget(entries: state.items),
                const SizedBox(height: 16),
                for (final entry in rest) _RankTile(entry: entry),
              ],
            ),
          ),
        ),
        _MyPositionBar(userRank: state.userRank),
      ],
    );
  }
}

class _RankTile extends StatelessWidget {
  final LeaderboardEntryModel entry;

  const _RankTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final name = entry.fullName.isNotEmpty ? entry.fullName : entry.username;
    return ListTile(
      key: Key('leaderboard-row-${entry.userId}'),
      minVerticalPadding: 12,
      leading: SizedBox(
        width: 40,
        child: Text(
          '#${entry.rank}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('@${entry.username}'),
      trailing: Text(
        '${entry.xp} XP',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

/// Pie fijo con la posición del usuario; sin prácticas esta semana muestra
/// "Sin clasificar".
class _MyPositionBar extends StatelessWidget {
  final int? userRank;

  const _MyPositionBar({required this.userRank});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('leaderboard-my-position'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Text(
          userRank == null
              ? 'Tu posición: Sin clasificar'
              : 'Tu posición: #$userRank',
          style: theme.textTheme.titleSmall,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('leaderboard-retry'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
