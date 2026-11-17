import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

/// Datasource remoto para todas las operaciones de autenticación.
class AuthRemoteDatasource {
  final ApiClient apiClient;

  const AuthRemoteDatasource({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// POST /auth/login
  Future<AuthResponse> login(String email, String password) async {
    final response = await _dio.post(
      AppConfig.loginEndpoint,
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(response.data);
  }

  /// POST /auth/register
  Future<AuthResponse> register(
    String email,
    String username,
    String fullName,
    String password,
    String passwordConfirm, {
    String? skillLevel,
  }) async {
    final response = await _dio.post(
      AppConfig.registerEndpoint,
      data: {
        'email': email,
        'username': username,
        'full_name': fullName,
        'password': password,
        'password_confirm': passwordConfirm,
        'skill_level': ?skillLevel,
      },
    );
    return AuthResponse.fromJson(response.data);
  }

  /// POST /auth/google
  Future<AuthResponse> googleSignIn(String googleIdToken) async {
    final response = await _dio.post(
      AppConfig.googleAuthEndpoint,
      data: {'google_token': googleIdToken},
    );
    return AuthResponse.fromJson(response.data);
  }

  /// GET /auth/me
  Future<UserModel> getCurrentUser() async {
    final response = await _dio.get(AppConfig.meEndpoint);
    return UserModel.fromJson(response.data);
  }

  /// PUT /auth/me
  Future<UserModel> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? skillLevel,
    bool? notificationsPushEnabled,
    bool? notificationsEmailEnabled,
  }) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (username != null) data['username'] = username;
    if (bio != null) data['bio'] = bio;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (skillLevel != null) data['skill_level'] = skillLevel;
    if (notificationsPushEnabled != null) {
      data['notifications_push_enabled'] = notificationsPushEnabled;
    }
    if (notificationsEmailEnabled != null) {
      data['notifications_email_enabled'] = notificationsEmailEnabled;
    }

    final response = await _dio.put(AppConfig.meEndpoint, data: data);
    return UserModel.fromJson(response.data);
  }

  /// POST /auth/refresh (rotación: devuelve ambos tokens)
  Future<(String, String)> refreshToken(String refreshToken) async {
    final response = await _dio.post(
      AppConfig.refreshEndpoint,
      data: {'refresh_token': refreshToken},
    );
    return (
      response.data['access_token'] as String,
      response.data['refresh_token'] as String,
    );
  }

  /// PUT /auth/change-password
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _dio.put(
      AppConfig.changePasswordEndpoint,
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  /// DELETE /auth/me — elimina la cuenta. `password` requerido para cuentas
  /// locales; puede ir null para Google.
  Future<void> deleteAccount({String? password}) async {
    await _dio.delete(AppConfig.meEndpoint, data: {'password': ?password});
  }

  /// POST /auth/forgot-password
  Future<void> forgotPassword(String email) async {
    await _dio.post(AppConfig.forgotPasswordEndpoint, data: {'email': email});
  }

  /// POST /auth/reset-password
  Future<AuthResponse> resetPassword(
    String token,
    String newPassword,
    String newPasswordConfirm,
  ) async {
    final response = await _dio.post(
      AppConfig.resetPasswordEndpoint,
      data: {
        'token': token,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      },
    );
    return AuthResponse.fromJson(response.data);
  }
}
