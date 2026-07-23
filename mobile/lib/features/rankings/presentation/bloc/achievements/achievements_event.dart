/// Eventos del BLoC de logros.
abstract class AchievementsEvent {}

class AchievementsLoadAll extends AchievementsEvent {}

class AchievementsLoadRecent extends AchievementsEvent {}

class AchievementsFilterByCategory extends AchievementsEvent {
  final String? category;
  AchievementsFilterByCategory({this.category});
}
