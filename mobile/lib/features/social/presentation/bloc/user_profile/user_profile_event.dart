import 'package:equatable/equatable.dart';

abstract class UserProfileEvent extends Equatable {
  const UserProfileEvent();

  @override
  List<Object?> get props => [];
}

class UserProfileLoad extends UserProfileEvent {
  final String userId;
  const UserProfileLoad(this.userId);

  @override
  List<Object?> get props => [userId];
}

class UserProfileToggleFollow extends UserProfileEvent {
  const UserProfileToggleFollow();
}

class UserProfileLoadMorePosts extends UserProfileEvent {
  const UserProfileLoadMorePosts();
}
