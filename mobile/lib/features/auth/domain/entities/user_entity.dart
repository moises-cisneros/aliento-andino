import 'package:equatable/equatable.dart';

/// Entidad pura de usuario (sin lógica de serialización).
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final bool isActive;
  final bool isAdmin;
  final bool isVerified;
  final String authProvider;
  final String? skillLevel;
  final bool notificationsPushEnabled;
  final bool notificationsEmailEnabled;
  // Suscripción (pago simulado)
  final bool isPremium;
  final String? subscriptionPlan;
  final String? subscriptionExpiresAt;
  final String createdAt;
  final String? updatedAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    required this.isActive,
    required this.isAdmin,
    required this.isVerified,
    required this.authProvider,
    this.skillLevel,
    this.notificationsPushEnabled = true,
    this.notificationsEmailEnabled = true,
    this.isPremium = false,
    this.subscriptionPlan,
    this.subscriptionExpiresAt,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    email,
    username,
    fullName,
    avatarUrl,
    bio,
    isActive,
    isAdmin,
    isVerified,
    authProvider,
    skillLevel,
    notificationsPushEnabled,
    notificationsEmailEnabled,
    isPremium,
    subscriptionPlan,
    subscriptionExpiresAt,
    createdAt,
    updatedAt,
  ];
}
