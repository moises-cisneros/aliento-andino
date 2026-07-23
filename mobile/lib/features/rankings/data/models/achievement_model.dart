/// Modelo de logro con estado del usuario.
class AchievementModel {
  final String id;
  final String code;
  final String name;
  final String description;
  final String icon;
  final String category;
  final int xpReward;
  final String rarity;
  final String requirementType;
  final int requirementValue;
  final bool isUnlocked;
  final String? unlockedAt;
  final int progress;

  const AchievementModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    this.xpReward = 0,
    this.rarity = 'common',
    required this.requirementType,
    required this.requirementValue,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress = 0,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: (json['id'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      icon: (json['icon'] as String?) ?? 'emoji_events',
      category: (json['category'] as String?) ?? '',
      xpReward: json['xp_reward'] as int? ?? 0,
      rarity: (json['rarity'] as String?) ?? 'common',
      requirementType: (json['requirement_type'] as String?) ?? '',
      requirementValue: json['requirement_value'] as int? ?? 0,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      unlockedAt: json['unlocked_at'] as String?,
      progress: json['progress'] as int? ?? 0,
    );
  }
}
