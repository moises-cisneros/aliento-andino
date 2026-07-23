import '../entities/user_entity.dart';

/// Contrato abstracto del repositorio de autenticación.
abstract class AuthRepositoryInterface {
  /// Login con email y contraseña. Retorna (user, accessToken, refreshToken).
  Future<(UserEntity, String, String)> login(String email, String password);

  /// Registro de nuevo usuario. Retorna (user, accessToken, refreshToken).
  Future<(UserEntity, String, String)> register(
    String email,
    String username,
    String fullName,
    String password,
    String passwordConfirm, {
    String? skillLevel,
  });

  /// Autenticación con Google. Retorna (user, accessToken, refreshToken).
  Future<(UserEntity, String, String)> googleSignIn(String googleIdToken);

  /// Obtener perfil del usuario autenticado.
  Future<UserEntity> getCurrentUser();

  /// Actualizar perfil del usuario.
  Future<UserEntity> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? skillLevel,
    bool? notificationsPushEnabled,
    bool? notificationsEmailEnabled,
  });

  /// Refrescar tokens (rotación). Retorna (new_access_token, new_refresh_token).
  Future<(String, String)> refreshToken(String refreshToken);

  /// Solicitar recuperación de contraseña.
  Future<void> forgotPassword(String email);

  /// Resetear contraseña con token. Retorna (user, accessToken, refreshToken).
  Future<(UserEntity, String, String)> resetPassword(
    String token,
    String newPassword,
    String newPasswordConfirm,
  );

  /// Cambiar la contraseña (usuario autenticado) verificando la actual.
  Future<void> changePassword(String currentPassword, String newPassword);

  /// Eliminar definitivamente la cuenta. `password` requerido para cuentas
  /// locales; null para Google.
  Future<void> deleteAccount({String? password});
}
