import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../lessons/presentation/bloc/lessons/lessons_bloc.dart';
import '../../../lessons/presentation/bloc/lessons/lessons_event.dart';
import '../../data/models/subscription_models.dart';
import '../../data/repositories/subscription_repository.dart';

/// Pantalla de planes (paywall): muestra los beneficios premium y los planes,
/// y lleva a la pantalla de pago (simulado).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late Future<List<PlanModel>> _plansFuture;
  String _selectedPlanId = 'annual';
  bool _trialAvailable = false;
  bool _trialBusy = false;

  static const _benefits = <(IconData, String)>[
    (Icons.library_music, 'Todas las lecciones, todos los géneros'),
    (Icons.workspace_premium, 'Niveles Intermedio, Avanzado y Experto'),
    (Icons.auto_awesome, 'Feedback con IA en cada práctica'),
    (Icons.videocam, 'Coach por cámara (postura y manos)'),
    (Icons.download_for_offline, 'Descarga para practicar sin conexión'),
    (Icons.insights, 'Estadísticas detalladas de tu progreso'),
  ];

  @override
  void initState() {
    super.initState();
    _plansFuture = context.read<SubscriptionRepository>().getPlans();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final s = await context.read<SubscriptionRepository>().getStatus();
      if (mounted) setState(() => _trialAvailable = s.trialAvailable);
    } catch (_) {
      // Si falla, simplemente no mostramos el botón de prueba.
    }
  }

  Future<void> _startTrial() async {
    setState(() => _trialBusy = true);
    try {
      await context.read<SubscriptionRepository>().startTrial();
      if (!mounted) return;
      // Refresca el usuario (is_premium) y las lecciones (desbloqueo).
      context.read<AuthBloc>().add(AuthCheckRequested());
      context.read<LessonsBloc>().add(const LessonsRefresh());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Prueba gratis de 7 días activada!')),
      );
      context.go('/lessons');
    } catch (_) {
      if (!mounted) return;
      setState(() => _trialBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la prueba.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurfaceVariant),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<List<PlanModel>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          final plans = snapshot.data ?? const <PlanModel>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              _header(cs),
              const SizedBox(height: 24),
              ..._benefits.map((b) => _benefitRow(cs, b.$1, b.$2)),
              const SizedBox(height: 24),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ...plans.map((p) => _planCard(cs, p)),
              const SizedBox(height: 16),
              _continueButton(cs, plans),
              if (_trialAvailable) ...[
                const SizedBox(height: 10),
                _trialButton(cs),
              ],
              const SizedBox(height: 12),
              Text(
                'Pago simulado para demo: no se realiza ningún cobro real.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 44),
          const SizedBox(height: 10),
          const Text(
            'Aliento Andino Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Desbloqueá todo y aprendé más rápido',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(ColorScheme cs, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cs.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(ColorScheme cs, PlanModel plan) {
    final selected = _selectedPlanId == plan.id;
    final isAnnual = plan.id == 'annual';
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanId = plan.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.surfaceContainerHighest,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.label,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isAnnual) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Ahorrás 33%',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAnnual
                        ? 'Facturado una vez al año'
                        : 'Facturado cada mes',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${plan.priceLabel}/${plan.period}',
              style: TextStyle(
                color: cs.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _continueButton(ColorScheme cs, List<PlanModel> plans) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: plans.isEmpty
            ? null
            : () {
                final plan = plans.firstWhere(
                  (p) => p.id == _selectedPlanId,
                  orElse: () => plans.first,
                );
                // El id va en la URL (no por `extra`) para sobrevivir a rebuilds
                // del router (teclado, refreshListenable) sin perder el plan.
                context.push('/subscription/payment?plan=${plan.id}');
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Continuar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _trialButton(ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _trialBusy ? null : _startTrial,
        icon: _trialBusy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : const Icon(Icons.card_giftcard),
        label: const Text('Probar 7 días gratis'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
