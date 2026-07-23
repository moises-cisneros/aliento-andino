import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';

/// Cliente HTTP configurado con Dio para comunicarse con el backend.
class ApiClient {
  late final Dio dio;
  final SecureStorageService secureStorage;

  /// Callback para notificar cuando el refresh token falla (forzar logout).
  void Function()? onAuthError;

  ApiClient({required this.secureStorage}) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptor de autenticación con auto-refresh
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        onAuthError: () => onAuthError?.call(),
      ),
    );
  }
}
