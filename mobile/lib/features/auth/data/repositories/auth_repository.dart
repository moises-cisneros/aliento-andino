import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository_interface.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implementación concreta del repositorio de autenticación.
class AuthRepository implements AuthRepositoryInterface {
  final AuthRemoteDatasource remoteDatasource;

  const AuthRepository({required this.remoteDatasource});

  @override
  Future<(UserEntity, String, String)> login(
    String email,
    String password,
  ) async {
    final response = await remoteDatasource.login(email, password);
    return (
      response.user as UserEntity,
      response.accessToken,
      response.refreshToken,
    );
  }

  @override
  Future<(UserEntity, String, String)> register(
    String email,
    String username,
    String fullName,
    String password,
    String passwordConfirm, {
    String? skillLevel,
  }) async {
    final response = await remoteDatasource.register(
      email,
      username,
      fullName,
      password,
      passwordConfirm,
      skillLevel: skillLevel,
    );
    return (
      response.user as UserEntity,
      response.accessToken,
      response.refreshToken,
    );
  }

  @override
  Future<(UserEntity, String, String)> googleSignIn(
    String googleIdToken,
  ) async {
    final response = await remoteDatasource.googleSignIn(googleIdToken);
    return (
      response.user as UserEntity,
      response.accessToken,
      response.refreshToken,
    );
  }

  @override
  Future<UserEntity> getCurrentUser() async {
    return await remoteDatasource.getCurrentUser();
  }

  @override
  Future<UserEntity> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? skillLevel,
    bool? notificationsPushEnabled,
    bool? notificationsEmailEnabled,
  }) async {
    return await remoteDatasource.updateProfile(
      fullName: fullName,
      username: username,
      bio: bio,
      avatarUrl: avatarUrl,
      skillLevel: skillLevel,
      notificationsPushEnabled: notificationsPushEnabled,
      notificationsEmailEnabled: notificationsEmailEnabled,
    );
  }

  @override
  Future<(String, String)> refreshToken(String refreshToken) async {
    return await remoteDatasource.refreshToken(refreshToken);
  }

  @override
  Future<void> forgotPassword(String email) async {
    await remoteDatasource.forgotPassword(email);
  }

  @override
  Future<(UserEntity, String, String)> resetPassword(
    String token,
    String newPassword,
    String newPasswordConfirm,
  ) async {
    final response = await remoteDatasource.resetPassword(
      token,
      newPassword,
      newPasswordConfirm,
    );
    return (
      response.user as UserEntity,
      response.accessToken,
      response.refreshToken,
    );
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await remoteDatasource.changePassword(currentPassword, newPassword);
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    await remoteDatasource.deleteAccount(password: password);
  }
}
