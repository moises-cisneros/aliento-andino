import '../../../data/models/ranking_entry_model.dart';
import '../../../data/models/lesson_ranking_model.dart';
import '../../../data/models/user_xp_model.dart';

/// Estados del BLoC de rankings.
abstract class RankingsState {}

class RankingsInitial extends RankingsState {}

class RankingsLoading extends RankingsState {}

class RankingsLoaded extends RankingsState {
  final List<RankingEntryModel> leaderboard;
  final int myRank;
  final int myXP;
  final int myLevel;
  final int? daysRemaining;
  final String activeTab;

  RankingsLoaded({
    required this.leaderboard,
    required this.myRank,
    this.myXP = 0,
    this.myLevel = 1,
    this.daysRemaining,
    this.activeTab = 'global',
  });
}

class MyXPLoaded extends RankingsState {
  final UserXPModel xpData;
  MyXPLoaded({required this.xpData});
}

class LessonRankingLoaded extends RankingsState {
  final List<LessonRankingModel> leaderboard;
  final double myBestScore;
  final int myRank;
  final String lessonTitle;

  LessonRankingLoaded({
    required this.leaderboard,
    required this.myBestScore,
    required this.myRank,
    this.lessonTitle = '',
  });
}

class RankingsError extends RankingsState {
  final String message;
  RankingsError({required this.message});
}
