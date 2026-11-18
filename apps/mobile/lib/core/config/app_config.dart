import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración central de la app Aliento Andino.
///
/// Para producción, compilar con:
///   flutter build apk --dart-define=API_BASE_URL=https://alientoandino.com/api
///   flutter build apk --dart-define=GOOGLE_WEB_CLIENT_ID=tu-client-id
class AppConfig {
  AppConfig._();

  // Google OAuth - Web Client ID (configurar via --dart-define en producción)
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '85165749876-fttcpknkrnmhr7v7nn7m737o3f3e7cnq.apps.googleusercontent.com',
  );

  // URL base del API (configurar via --dart-define en producción)
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  // URL base del portal Web para compartir enlaces (configurar via --dart-define en producción)
  static const String _envWebBaseUrl = String.fromEnvironment('WEB_BASE_URL');
  static String get webBaseUrl =>
      _envWebBaseUrl.isNotEmpty ? _envWebBaseUrl : 'https://alientoandino.org';

  /// URL base del API según la plataforma.
  /// Si se configura API_BASE_URL via --dart-define, usa ese valor.
  /// Si no, usa los defaults de desarrollo local.
  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:8050/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:8050/api';
    return 'http://localhost:8050/api'; // iOS, macOS, desktop
  }

  // Endpoints de autenticación
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String googleAuthEndpoint = '/auth/google';
  static const String refreshEndpoint = '/auth/refresh';
  static const String meEndpoint = '/auth/me';
  static const String forgotPasswordEndpoint = '/auth/forgot-password';
  static const String resetPasswordEndpoint = '/auth/reset-password';
  static const String changePasswordEndpoint = '/auth/change-password';
}
