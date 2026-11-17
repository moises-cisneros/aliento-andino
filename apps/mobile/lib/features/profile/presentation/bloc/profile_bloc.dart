import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_error.dart';
import '../../../social/data/models/post_model.dart';
import '../../data/repositories/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

/// BLoC para gestionar el perfil del usuario.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _profileRepository;

  ProfileBloc({required ProfileRepository profileRepository})
    : _profileRepository = profileRepository,
      super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onLoad);
    on<ProfileRefreshRequested>(_onRefresh);
    on<ProfileLoadMorePosts>(_onLoadMorePosts);
    on<ProfileUpdateRequested>(_onUpdate);
  }

  Future<void> _onLoad(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final profileData = await _profileRepository.getMyProfile();
      final user = profileData['user'] as dynamic;
      final socialProfile = await _profileRepository.getSocialProfile(user.id);
      final postsResult = await _profileRepository.getMyPosts(
        user.id,
        cursor: null,
      );
      final posts =
          (postsResult['items'] as List?)?.cast<PostModel>().toList() ??
          <PostModel>[];

      emit(
        ProfileLoaded(
          user: user,
          socialProfile: socialProfile,
          xpData: profileData['xp_data'] as dynamic,
          recentAchievements: profileData['recent_achievements'] as dynamic,
          myPosts: posts,
          nextCursor: postsResult['next_cursor'] as String?,
          hasMorePosts: (postsResult['has_more'] as bool?) ?? false,
        ),
      );
    } catch (e) {
      emit(ProfileError(_extractError(e)));
    }
  }

  Future<void> _onRefresh(
    ProfileRefreshRequested event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final profileData = await _profileRepository.getMyProfile();
      final user = profileData['user'] as dynamic;
      final socialProfile = await _profileRepository.getSocialProfile(user.id);
      final postsResult = await _profileRepository.getMyPosts(
        user.id,
        cursor: null,
      );
      final posts =
          (postsResult['items'] as List?)?.cast<PostModel>().toList() ??
          <PostModel>[];

      emit(
        ProfileLoaded(
          user: user,
          socialProfile: socialProfile,
          xpData: profileData['xp_data'] as dynamic,
          recentAchievements: profileData['recent_achievements'] as dynamic,
          myPosts: posts,
          nextCursor: postsResult['next_cursor'] as String?,
          hasMorePosts: (postsResult['has_more'] as bool?) ?? false,
        ),
      );
    } catch (e) {
      emit(ProfileError(_extractError(e)));
    }
  }

  Future<void> _onLoadMorePosts(
    ProfileLoadMorePosts event,
    Emitter<ProfileState> emit,
  ) async {
    final current = state;
    if (current is! ProfileLoaded ||
        !current.hasMorePosts ||
        current.isLoadingMore) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    try {
      final postsResult = await _profileRepository.getMyPosts(
        current.user.id,
        cursor: current.nextCursor,
      );
      final newPosts = postsResult['items'] as List<PostModel>;

      emit(
        current.copyWith(
          myPosts: [...current.myPosts, ...newPosts],
          nextCursor: postsResult['next_cursor'] as String?,
          hasMorePosts: postsResult['has_more'] as bool,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onUpdate(
    ProfileUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final updatedUser = await _profileRepository.updateProfile(
        fullName: event.fullName,
        username: event.username,
        bio: event.bio,
        avatarUrl: event.avatarUrl,
        preferredInstruments: event.preferredInstruments,
        breathSensitivityRms: event.breathSensitivityRms,
      );
      emit(ProfileUpdateSuccess(updatedUser: updatedUser));
    } catch (e) {
      emit(ProfileError(_extractError(e)));
    }
  }

  String _extractError(Object error) {
    if (isConnectionError(error)) return offlineMessage;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('detail')) {
        return data['detail'] as String;
      }
      return 'Error de conexión con el servidor';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
