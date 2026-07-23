import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/post_model.dart';
import '../../../data/repositories/user_repository.dart';
import 'user_profile_event.dart';
import 'user_profile_state.dart';

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final UserRepository _userRepository;
  late String _userId;

  UserProfileBloc({required UserRepository userRepository})
    : _userRepository = userRepository,
      super(const UserProfileInitial()) {
    on<UserProfileLoad>(_onLoad);
    on<UserProfileToggleFollow>(_onToggleFollow);
    on<UserProfileLoadMorePosts>(_onLoadMorePosts);
  }

  Future<void> _onLoad(
    UserProfileLoad event,
    Emitter<UserProfileState> emit,
  ) async {
    _userId = event.userId;
    emit(const UserProfileLoading());
    try {
      final profile = await _userRepository.getUserProfile(_userId);
      final postsResult = await _userRepository.getUserPosts(_userId);
      final posts = postsResult['items'] as List<PostModel>;

      emit(
        UserProfileLoaded(
          profile: profile,
          posts: posts,
          nextCursor: postsResult['next_cursor'] as String?,
          hasMorePosts: postsResult['has_more'] as bool,
        ),
      );
    } catch (e) {
      emit(UserProfileError(e.toString()));
    }
  }

  Future<void> _onToggleFollow(
    UserProfileToggleFollow event,
    Emitter<UserProfileState> emit,
  ) async {
    final s = state;
    if (s is! UserProfileLoaded) return;

    final newFollowed = !s.profile.isFollowedByMe;
    final optimistic = s.profile.copyWith(
      isFollowedByMe: newFollowed,
      followersCount: s.profile.followersCount + (newFollowed ? 1 : -1),
    );
    emit(s.copyWith(profile: optimistic));

    try {
      await _userRepository.toggleFollow(_userId);
    } catch (_) {
      emit(s);
    }
  }

  Future<void> _onLoadMorePosts(
    UserProfileLoadMorePosts event,
    Emitter<UserProfileState> emit,
  ) async {
    final s = state;
    if (s is! UserProfileLoaded || !s.hasMorePosts || s.isLoadingMore) return;

    emit(s.copyWith(isLoadingMore: true));
    try {
      final result = await _userRepository.getUserPosts(
        _userId,
        cursor: s.nextCursor,
      );
      final newPosts = result['items'] as List<PostModel>;
      emit(
        UserProfileLoaded(
          profile: s.profile,
          posts: [...s.posts, ...newPosts],
          nextCursor: result['next_cursor'] as String?,
          hasMorePosts: result['has_more'] as bool,
        ),
      );
    } catch (_) {
      emit(s.copyWith(isLoadingMore: false));
    }
  }
}
