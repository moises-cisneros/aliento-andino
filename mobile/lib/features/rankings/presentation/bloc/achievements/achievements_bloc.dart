import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/achievement_model.dart';
import '../../../data/repositories/ranking_repository.dart';
import 'achievements_event.dart';
import 'achievements_state.dart';

/// BLoC de logros del usuario.
class AchievementsBloc extends Bloc<AchievementsEvent, AchievementsState> {
  final RankingRepository rankingRepository;

  List<AchievementModel> _allAchievements = [];
  int _totalUnlocked = 0;
  int _totalAvailable = 0;

  AchievementsBloc({required this.rankingRepository})
    : super(AchievementsInitial()) {
    on<AchievementsLoadAll>(_onLoadAll);
    on<AchievementsFilterByCategory>(_onFilterByCategory);
  }

  Future<void> _onLoadAll(
    AchievementsLoadAll event,
    Emitter<AchievementsState> emit,
  ) async {
    emit(AchievementsLoading());
    try {
      final data = await rankingRepository.getAllAchievements();
      _allAchievements = data['achievements'] as List<AchievementModel>;
      _totalUnlocked = data['total_unlocked'] as int;
      _totalAvailable = data['total_available'] as int;
      emit(
        AchievementsLoaded(
          achievements: _allAchievements,
          totalUnlocked: _totalUnlocked,
          totalAvailable: _totalAvailable,
        ),
      );
    } catch (e) {
      emit(AchievementsError(message: 'Error al cargar logros'));
    }
  }

  void _onFilterByCategory(
    AchievementsFilterByCategory event,
    Emitter<AchievementsState> emit,
  ) {
    final category = event.category;
    final filtered = category == null
        ? _allAchievements
        : _allAchievements.where((a) => a.category == category).toList();

    emit(
      AchievementsLoaded(
        achievements: filtered,
        totalUnlocked: _totalUnlocked,
        totalAvailable: _totalAvailable,
        activeCategory: category,
      ),
    );
  }
}
