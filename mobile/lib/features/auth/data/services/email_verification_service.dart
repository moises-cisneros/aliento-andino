import '../../../../core/network/api_client.dart';

/// Servicio para verificación de email (envío + validación de código).
class EmailVerificationService {
  final ApiClient _apiClient;

  const EmailVerificationService({required ApiClient apiClient})
    : _apiClient = apiClient;

  /// Pide al backend que genere y envíe un código de 6 dígitos al email del user.
  Future<void> sendCode() async {
    await _apiClient.dio.post('/auth/send-verification-code');
  }

  /// Verifica el código. Si es válido, el backend marca is_verified=true.
  Future<void> verify(String code) async {
    await _apiClient.dio.post('/auth/verify-email', data: {'code': code});
  }
}
