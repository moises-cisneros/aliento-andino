import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/ranking_repository.dart';
import '../bloc/achievements/achievements_bloc.dart';
import '../bloc/achievements/achievements_event.dart';
import '../bloc/achievements/achievements_state.dart';
import '../widgets/achievement_card.dart';
import '../../../../core/theme/app_theme.dart';

/// Pantalla con grid de todos los logros del sistema.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final AchievementsBloc _bloc;
  String? _selectedCategory;

  static const _categories = [
    null,
    'practice',
    'streak',
    'score',
    'social',
    'milestone',
  ];
  static const _categoryLabels = [
    'Todos',
    'Práctica',
    'Racha',
    'Score',
    'Social',
    'Milestone',
  ];

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
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Logros')),
        body: BlocBuilder<AchievementsBloc, AchievementsState>(
          builder: (context, state) {
            if (state is AchievementsLoading) {
              return Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }
            if (state is AchievementsError) {
              return Center(
                child: Text(
                  state.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }
            if (state is AchievementsLoaded) {
              return _buildContent(state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(AchievementsLoaded state) {
    return Column(
      children: [
        // Counter
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: AppTheme.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                '${state.totalUnlocked}/${state.totalAvailable} logros desbloqueados',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Filtros
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(_categoryLabels[index]),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedCategory = cat);
                    _bloc.add(AchievementsFilterByCategory(category: cat));
                  },
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.9,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: state.achievements.length,
            itemBuilder: (context, index) {
              return AchievementCard(achievement: state.achievements[index]);
            },
          ),
        ),
      ],
    );
  }
}
