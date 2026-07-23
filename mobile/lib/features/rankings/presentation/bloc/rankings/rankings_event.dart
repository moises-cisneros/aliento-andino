/// Eventos del BLoC de rankings.
abstract class RankingsEvent {}

class RankingsLoadGlobal extends RankingsEvent {}

class RankingsLoadWeekly extends RankingsEvent {}

class RankingsLoadFriends extends RankingsEvent {}

class RankingsLoadStreaks extends RankingsEvent {}

class RankingsLoadMyXP extends RankingsEvent {}

class RankingsLoadLessonRanking extends RankingsEvent {
  final String lessonId;
  final String lessonTitle;
  RankingsLoadLessonRanking({required this.lessonId, this.lessonTitle = ''});
}
