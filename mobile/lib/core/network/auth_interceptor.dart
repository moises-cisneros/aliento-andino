import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

/// Interceptor que adjunta el token a cada request y refresca en caso de 401.
/// Usa QueuedInterceptor para evitar race conditions con múltiples refreshes.
class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;
  final SecureStorageService secureStorage;
  final void Function() onAuthError;

  /// Rutas que NO necesitan autenticación.
  static const _publicPaths = [
    AppConfig.loginEndpoint,
    AppConfig.registerEndpoint,
    AppConfig.refreshEndpoint,
    AppConfig.googleAuthEndpoint,
    AppConfig.forgotPasswordEndpoint,
    AppConfig.resetPasswordEndpoint,
  ];

  AuthInterceptor({
    required this.dio,
    required this.secureStorage,
    required this.onAuthError,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // No adjuntar token a rutas públicas
    final isPublic = _publicPaths.any((path) => options.path.contains(path));
    if (!isPublic) {
      final token = await secureStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Solo intentar refresh en errores 401
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // No intentar refresh si la ruta es pública
    final isPublic = _publicPaths.any(
      (path) => err.requestOptions.path.contains(path),
    );
    if (isPublic) {
      return handler.next(err);
    }

    // Intentar refrescar el token
    try {
      final refreshToken = await secureStorage.getRefreshToken();
      if (refreshToken == null) {
        await secureStorage.clearAll();
        onAuthError();
        return handler.next(err);
      }

      // Crear Dio temporal sin interceptores para evitar loop infinito
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: dio.options.baseUrl,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        AppConfig.refreshEndpoint,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'] as String;
        final newRefreshToken = response.data['refresh_token'] as String;
        await secureStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        // Reintentar el request original con el nuevo token
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

        final retryResponse = await refreshDio.fetch(retryOptions);
        return handler.resolve(retryResponse);
      }
    } catch (_) {
      // Refresh falló, forzar logout
    }

    await secureStorage.clearAll();
    onAuthError();
    handler.next(err);
  }
}
