import '../../domain/entities/user_entity.dart';

/// Modelo de usuario con serialización JSON.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.username,
    required super.fullName,
    super.avatarUrl,
    super.bio,
    required super.isActive,
    required super.isAdmin,
    required super.isVerified,
    required super.authProvider,
    super.skillLevel,
    super.preferredInstruments,
    super.breathSensitivityRms,
    super.notificationsPushEnabled,
    super.notificationsEmailEnabled,
    super.isPremium,
    super.subscriptionPlan,
    super.subscriptionExpiresAt,
    required super.createdAt,
    super.updatedAt,
  });

  /// Construye un UserModel desde cualquier UserEntity (para cachear el perfil).
  factory UserModel.fromEntity(UserEntity e) {
    return UserModel(
      id: e.id,
      email: e.email,
      username: e.username,
      fullName: e.fullName,
      avatarUrl: e.avatarUrl,
      bio: e.bio,
      isActive: e.isActive,
      isAdmin: e.isAdmin,
      isVerified: e.isVerified,
      authProvider: e.authProvider,
      skillLevel: e.skillLevel,
      preferredInstruments: e.preferredInstruments,
      breathSensitivityRms: e.breathSensitivityRms,
      notificationsPushEnabled: e.notificationsPushEnabled,
      notificationsEmailEnabled: e.notificationsEmailEnabled,
      isPremium: e.isPremium,
      subscriptionPlan: e.subscriptionPlan,
      subscriptionExpiresAt: e.subscriptionExpiresAt,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isAdmin: json['is_admin'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      authProvider: (json['auth_provider'] as String?) ?? 'local',
      skillLevel: json['skill_level'] as String?,
      preferredInstruments:
          (json['preferred_instruments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      breathSensitivityRms: (json['breath_sensitivity_rms'] as num?)
          ?.toDouble(),
      notificationsPushEnabled:
          json['notifications_push_enabled'] as bool? ?? true,
      notificationsEmailEnabled:
          json['notifications_email_enabled'] as bool? ?? true,
      isPremium: json['is_premium'] as bool? ?? false,
      subscriptionPlan: json['subscription_plan'] as String?,
      subscriptionExpiresAt: json['subscription_expires_at'] as String?,
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_active': isActive,
      'is_admin': isAdmin,
      'is_verified': isVerified,
      'auth_provider': authProvider,
      'skill_level': skillLevel,
      'preferred_instruments': preferredInstruments,
      'breath_sensitivity_rms': breathSensitivityRms,
      'notifications_push_enabled': notificationsPushEnabled,
      'notifications_email_enabled': notificationsEmailEnabled,
      'is_premium': isPremium,
      'subscription_plan': subscriptionPlan,
      'subscription_expires_at': subscriptionExpiresAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
