import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/connectivity/offline_banner.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/auto_refresh_mixin.dart';
import '../../data/models/ranking_entry_model.dart';
import '../../data/repositories/ranking_repository.dart';
import '../bloc/rankings/rankings_bloc.dart';
import '../bloc/rankings/rankings_event.dart';
import '../bloc/rankings/rankings_state.dart';
import '../widgets/leaderboard_tile.dart';
import '../widgets/podium_widget.dart';

/// Instrumentos andinos admitidos para filtrado.
enum AndeanInstrumentFilter {
  quena('quena', 'Quena', Icons.music_note),
  zampona('zampona', 'Zampoña', Icons.queue_music),
  tarka('tarka', 'Tarka', Icons.graphic_eq);

  final String id;
  final String label;
  final IconData icon;

  const AndeanInstrumentFilter(this.id, this.label, this.icon);
}

/// Pantalla de Leaderboard Semanal segmentado por instrumento andino (HU-12 / SUB-12-B).
class LeaderboardScreen extends StatefulWidget {
  final String initialInstrument;

  const LeaderboardScreen({super.key, this.initialInstrument = 'quena'});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin, AutoRefreshOnResume {
  late String _selectedInstrument;
  late final RankingsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _selectedInstrument = widget.initialInstrument;
    _bloc = RankingsBloc(rankingRepository: context.read<RankingRepository>())
      ..add(
        RankingsLoadInstrumentLeaderboard(
          instrument: _selectedInstrument,
          scope: 'weekly',
        ),
      );
  }

  @override
  void onAutoRefresh() {
    _bloc.add(
      RankingsLoadInstrumentLeaderboard(
        instrument: _selectedInstrument,
        scope: 'weekly',
      ),
    );
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _onSelectInstrument(String instrument) {
    if (_selectedInstrument == instrument) return;
    setState(() {
      _selectedInstrument = instrument;
    });
    _bloc.add(
      RankingsLoadInstrumentLeaderboard(
        instrument: _selectedInstrument,
        scope: 'weekly',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Leaderboard Semanal'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: _buildInstrumentTabs(theme),
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
                        color: theme.colorScheme.primary,
                      ),
                    );
                  }

                  if (state is RankingsError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              state.message == offlineMessage
                                  ? Icons.wifi_off_rounded
                                  : Icons.error_outline,
                              color: state.message == offlineMessage
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.error,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _bloc.add(
                                RankingsLoadInstrumentLeaderboard(
                                  instrument: _selectedInstrument,
                                  scope: 'weekly',
                                ),
                              ),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state is InstrumentLeaderboardLoaded) {
                    return _buildLoadedContent(context, state);
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: BlocBuilder<RankingsBloc, RankingsState>(
          builder: (context, state) {
            if (state is InstrumentLeaderboardLoaded) {
              return _buildStickyUserFooter(context, state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  /// Selector horizontal de pestañas para instrumentos andinos respetando Ley de Fitts (>= 48px).
  Widget _buildInstrumentTabs(ThemeData theme) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: AndeanInstrumentFilter.values.map((item) {
          final isSelected = _selectedInstrument == item.id;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                key: Key('tab_instrument_${item.id}'),
                onTap: () => _onSelectInstrument(item.id),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadedContent(
    BuildContext context,
    InstrumentLeaderboardLoaded state,
  ) {
    final items = state.items;
    final topThree = items.take(3).toList();
    final remainingItems = items.length > 3
        ? items.sublist(3)
        : <RankingEntryModel>[];

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        _bloc.add(
          RankingsLoadInstrumentLeaderboard(
            instrument: _selectedInstrument,
            scope: 'weekly',
          ),
        );
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Banner de reinicio semanal
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: AppTheme.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Puntuaciones semanales. Reinicio cada lunes 00:00 UTC.',
                      style: TextStyle(fontSize: 12, color: AppTheme.warning),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Podio animado con los 3 primeros
          SliverToBoxAdapter(child: PodiumWidget(entries: topThree)),

          // Título de lista restante si hay más de 3
          if (remainingItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Otras posiciones',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

          // Lista de posiciones restantes (4+)
          if (remainingItems.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final entry = remainingItems[index];
                final isCurrentUser =
                    state.userRank != null && entry.rank == state.userRank;
                return LeaderboardTile(
                  entry: entry,
                  isCurrentUser: isCurrentUser,
                  valueLabel: 'XP',
                );
              }, childCount: remainingItems.length),
            )
          else if (items.length <= 3 && items.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '¡Sé el siguiente en practicar para unirte al podio!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

          // Espacio extra al final para que el footer no tape elementos
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  /// Footer fijo al pie con la posición del usuario.
  /// Si no tiene prácticas esta semana, se muestra "Sin clasificar".
  Widget _buildStickyUserFooter(
    BuildContext context,
    InstrumentLeaderboardLoaded state,
  ) {
    final theme = Theme.of(context);
    final userRank = state.userRank;
    final isRanked = userRank != null && userRank > 0;

    // Buscar si el usuario está en los items para obtener su XP
    final userEntry = isRanked
        ? state.items.cast<RankingEntryModel?>().firstWhere(
            (e) => e?.rank == userRank,
            orElse: () => null,
          )
        : null;

    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: isRanked
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.colorScheme.outlineVariant,
              width: isRanked ? 2 : 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ícono o badge de posición
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRanked
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : theme.colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: isRanked
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Center(
                child: isRanked
                    ? Text(
                        '#$userRank',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : Icon(
                        Icons.hourglass_empty_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Posición y descripción
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRanked
                        ? 'Tu posición: #$userRank'
                        : 'Tu posición: Sin clasificar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isRanked
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    isRanked
                        ? (userEntry != null
                              ? '${userEntry.xp} XP esta semana'
                              : 'Clasificado esta semana')
                        : 'Sin prácticas esta semana en $_selectedInstrumentName',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Medalla o indicador
            if (isRanked && userRank <= 3)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: userRank == 1
                      ? AppTheme.gold
                      : (userRank == 2 ? AppTheme.silver : AppTheme.bronze),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  userRank == 1 ? 'Oro' : (userRank == 2 ? 'Plata' : 'Bronce'),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _selectedInstrumentName {
    switch (_selectedInstrument) {
      case 'zampona':
        return 'Zampoña';
      case 'tarka':
        return 'Tarka';
      case 'quena':
      default:
        return 'Quena';
    }
  }
}
