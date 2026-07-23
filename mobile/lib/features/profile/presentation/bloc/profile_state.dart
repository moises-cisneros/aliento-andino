import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../rankings/data/models/achievement_model.dart';
import '../../../rankings/data/models/user_xp_model.dart';
import '../../../social/data/models/post_model.dart';
import '../../../social/data/models/user_profile_model.dart';

/// Estados del BLoC de perfil.
abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial.
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

/// Cargando datos del perfil.
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// Perfil cargado con todos los datos.
class ProfileLoaded extends ProfileState {
  final UserEntity user;
  final UserProfileModel socialProfile;
  final UserXPModel xpData;
  final List<AchievementModel> recentAchievements;
  final List<PostModel> myPosts;
  final String? nextCursor;
  final bool hasMorePosts;
  final bool isLoadingMore;

  const ProfileLoaded({
    required this.user,
    required this.socialProfile,
    required this.xpData,
    required this.recentAchievements,
    required this.myPosts,
    this.nextCursor,
    this.hasMorePosts = false,
    this.isLoadingMore = false,
  });

  ProfileLoaded copyWith({
    UserEntity? user,
    UserProfileModel? socialProfile,
    UserXPModel? xpData,
    List<AchievementModel>? recentAchievements,
    List<PostModel>? myPosts,
    String? nextCursor,
    bool? hasMorePosts,
    bool? isLoadingMore,
  }) {
    return ProfileLoaded(
      user: user ?? this.user,
      socialProfile: socialProfile ?? this.socialProfile,
      xpData: xpData ?? this.xpData,
      recentAchievements: recentAchievements ?? this.recentAchievements,
      myPosts: myPosts ?? this.myPosts,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    user,
    socialProfile,
    xpData,
    recentAchievements,
    myPosts,
    nextCursor,
    hasMorePosts,
    isLoadingMore,
  ];
}

/// Perfil actualizado exitosamente.
class ProfileUpdateSuccess extends ProfileState {
  final UserEntity updatedUser;

  const ProfileUpdateSuccess({required this.updatedUser});

  @override
  List<Object?> get props => [updatedUser];
}

/// Error en el perfil.
class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
