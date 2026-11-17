import '../../../rankings/data/models/achievement_model.dart' as ranking;

/// Insignia para la vitrina de trofeos del perfil.
///
/// Es la vista de presentación de un logro del backend
/// (`rankings/data/models/achievement_model.dart`): se construye con
/// [AchievementModel.fromRanking].
class AchievementModel {
  final String id;
  final String title;
  final String description;
  final String iconAsset;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.iconAsset,
    required this.isUnlocked,
    this.unlockedAt,
  });

  factory AchievementModel.fromRanking(ranking.AchievementModel source) {
    return AchievementModel(
      id: source.id,
      title: source.name,
      description: source.description,
      iconAsset: 'assets/badges/${source.code}.png',
      isUnlocked: source.isUnlocked,
      unlockedAt: source.unlockedAt == null
          ? null
          : DateTime.tryParse(source.unlockedAt!),
    );
  }

  /// Solo las insignias ya obtenidas, en el orden recibido.
  static List<AchievementModel> unlockedOnly(List<AchievementModel> all) =>
      all.where((a) => a.isUnlocked).toList();
}
