/// Plan de suscripción disponible.
class PlanModel {
  final String id; // "monthly" | "annual"
  final String label;
  final double priceUsd;
  final String period; // "mes" | "año"
  final int days;

  const PlanModel({
    required this.id,
    required this.label,
    required this.priceUsd,
    required this.period,
    required this.days,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as String,
      label: json['label'] as String,
      priceUsd: (json['price_usd'] as num).toDouble(),
      period: json['period'] as String,
      days: json['days'] as int,
    );
  }

  /// Precio formateado, ej. "$4.99".
  String get priceLabel => '\$${priceUsd.toStringAsFixed(2)}';
}

/// Estado de suscripción del usuario.
class SubscriptionStatusModel {
  final bool isPremium;
  final String status; // "free" | "premium"
  final String? plan;
  final String? planLabel;
  final String? expiresAt;
  final bool trialUsed;
  final bool trialAvailable;

  const SubscriptionStatusModel({
    required this.isPremium,
    required this.status,
    this.plan,
    this.planLabel,
    this.expiresAt,
    this.trialUsed = false,
    this.trialAvailable = false,
  });

  factory SubscriptionStatusModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatusModel(
      isPremium: json['is_premium'] as bool? ?? false,
      status: json['status'] as String? ?? 'free',
      plan: json['plan'] as String?,
      planLabel: json['plan_label'] as String?,
      expiresAt: json['expires_at'] as String?,
      trialUsed: json['trial_used'] as bool? ?? false,
      trialAvailable: json['trial_available'] as bool? ?? false,
    );
  }
}
