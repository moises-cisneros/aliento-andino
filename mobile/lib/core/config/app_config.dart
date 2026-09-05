import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración central de la app PianoVision AI.
///
/// Para producción, compilar con:
///   flutter build apk --dart-define=API_BASE_URL=https://pianovision.net/api
///   flutter build apk --dart-define=GOOGLE_WEB_CLIENT_ID=tu-client-id
class AppConfig {
  AppConfig._();

  // Google OAuth - Web Client ID (configurar via --dart-define en producción)
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '85165749876-fttcpknkrnmhr7v7nn7m737o3f3e7cnq.apps.googleusercontent.com',
  );

  // URL base del API (configurable via --dart-define en compilación)
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// URL base del API.
  /// Apunta al backend desplegado en http://vientoapp.duckdns.org/api por defecto.
  /// Si se provee API_BASE_URL via --dart-define, usa ese valor.
  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return 'http://vientoapp.duckdns.org/api';
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
