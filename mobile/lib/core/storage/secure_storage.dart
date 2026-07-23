import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper alrededor de FlutterSecureStorage para manejo de tokens.
class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user_profile';

  // --- Access Token ---

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  // --- Refresh Token ---

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  // --- Guardar ambos tokens ---

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
    ]);
  }

  // --- Perfil de usuario cacheado (para restaurar sesión offline) ---

  Future<String?> getUser() async {
    return await _storage.read(key: _userKey);
  }

  Future<void> saveUser(String userJson) async {
    await _storage.write(key: _userKey, value: userJson);
  }

  // --- Limpiar todo ---

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
