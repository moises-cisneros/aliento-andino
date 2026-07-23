import '../../../../core/network/api_client.dart';
import '../models/subscription_models.dart';

/// Repositorio de suscripción (pago simulado contra el backend).
class SubscriptionRepository {
  final ApiClient _apiClient;

  const SubscriptionRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  Future<List<PlanModel>> getPlans() async {
    final response = await _apiClient.dio.get('/subscription/plans');
    return (response.data as List<dynamic>)
        .map((e) => PlanModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionStatusModel> getStatus() async {
    final response = await _apiClient.dio.get('/subscription/me');
    return SubscriptionStatusModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Pago SIMULADO: manda los datos de tarjeta (no se procesan) y activa premium.
  Future<SubscriptionStatusModel> checkout({
    required String plan,
    required String cardNumber,
    required String cardHolder,
    required String cardExpiry,
    required String cardCvc,
  }) async {
    final response = await _apiClient.dio.post(
      '/subscription/checkout',
      data: {
        'plan': plan,
        'card_number': cardNumber,
        'card_holder': cardHolder,
        'card_expiry': cardExpiry,
        'card_cvc': cardCvc,
      },
    );
    return SubscriptionStatusModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Inicia la prueba gratis de 7 días (una sola vez por usuario).
  Future<SubscriptionStatusModel> startTrial() async {
    final response = await _apiClient.dio.post('/subscription/trial');
    return SubscriptionStatusModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<SubscriptionStatusModel> cancel() async {
    final response = await _apiClient.dio.post('/subscription/cancel');
    return SubscriptionStatusModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
