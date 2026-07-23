import '../../../data/models/achievement_model.dart';

/// Estados del BLoC de logros.
abstract class AchievementsState {}

class AchievementsInitial extends AchievementsState {}

class AchievementsLoading extends AchievementsState {}

class AchievementsLoaded extends AchievementsState {
  final List<AchievementModel> achievements;
  final int totalUnlocked;
  final int totalAvailable;
  final String? activeCategory;

  AchievementsLoaded({
    required this.achievements,
    this.totalUnlocked = 0,
    this.totalAvailable = 0,
    this.activeCategory,
  });
}

class AchievementsError extends AchievementsState {
  final String message;
  AchievementsError({required this.message});
}
