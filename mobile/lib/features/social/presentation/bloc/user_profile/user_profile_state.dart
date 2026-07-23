import 'package:equatable/equatable.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_profile_model.dart';

abstract class UserProfileState extends Equatable {
  const UserProfileState();

  @override
  List<Object?> get props => [];
}

class UserProfileInitial extends UserProfileState {
  const UserProfileInitial();
}

class UserProfileLoading extends UserProfileState {
  const UserProfileLoading();
}

class UserProfileLoaded extends UserProfileState {
  final UserProfileModel profile;
  final List<PostModel> posts;
  final String? nextCursor;
  final bool hasMorePosts;
  final bool isLoadingMore;

  const UserProfileLoaded({
    required this.profile,
    required this.posts,
    this.nextCursor,
    required this.hasMorePosts,
    this.isLoadingMore = false,
  });

  UserProfileLoaded copyWith({
    UserProfileModel? profile,
    List<PostModel>? posts,
    String? nextCursor,
    bool? hasMorePosts,
    bool? isLoadingMore,
  }) {
    return UserProfileLoaded(
      profile: profile ?? this.profile,
      posts: posts ?? this.posts,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    profile,
    posts,
    nextCursor,
    hasMorePosts,
    isLoadingMore,
  ];
}

class UserProfileError extends UserProfileState {
  final String message;
  const UserProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
