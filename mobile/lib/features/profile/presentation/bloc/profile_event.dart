import 'package:equatable/equatable.dart';

/// Eventos del BLoC de perfil.
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar toda la data del perfil.
class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

/// Pull-to-refresh.
class ProfileRefreshRequested extends ProfileEvent {
  const ProfileRefreshRequested();
}

/// Cargar más posts propios.
class ProfileLoadMorePosts extends ProfileEvent {
  const ProfileLoadMorePosts();
}

/// Actualizar perfil del usuario.
class ProfileUpdateRequested extends ProfileEvent {
  final String? fullName;
  final String? username;
  final String? bio;
  final String? avatarUrl;

  const ProfileUpdateRequested({
    this.fullName,
    this.username,
    this.bio,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [fullName, username, bio, avatarUrl];
}
