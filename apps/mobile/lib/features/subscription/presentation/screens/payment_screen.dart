import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../lessons/presentation/bloc/lessons/lessons_bloc.dart';
import '../../../lessons/presentation/bloc/lessons/lessons_event.dart';
import '../../data/models/subscription_models.dart';
import '../../data/repositories/subscription_repository.dart';

/// Pantalla de PAGO SIMULADO: formulario de tarjeta. No se cobra nada; al
/// "pagar" activa la suscripción premium en el backend.
class PaymentScreen extends StatefulWidget {
  final String planId;

  const PaymentScreen({super.key, required this.planId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();

  bool _processing = false;
  bool _success = false;
  String? _error;
  PlanModel? _plan;
  bool _loadingPlan = true;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  /// Resuelve el PlanModel a partir del id de la URL (la fuente de verdad es el
  /// backend), en vez de depender de `extra` que se pierde en rebuilds.
  Future<void> _loadPlan() async {
    try {
      final plans = await context.read<SubscriptionRepository>().getPlans();
      if (!mounted) return;
      setState(() {
        _plan = plans.firstWhere(
          (p) => p.id == widget.planId,
          orElse: () => plans.first,
        );
        _loadingPlan = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPlan = false);
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    _expiry.dispose();
    _cvc.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await context.read<SubscriptionRepository>().checkout(
        plan: _plan!.id,
        cardNumber: _number.text,
        cardHolder: _holder.text,
        cardExpiry: _expiry.text,
        cardCvc: _cvc.text,
      );
      if (!mounted) return;
      // Refrescar el usuario (isPremium) y las lecciones (desbloqueo).
      context.read<AuthBloc>().add(AuthCheckRequested());
      context.read<LessonsBloc>().add(const LessonsRefresh());
      setState(() {
        _processing = false;
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error =
            'No se pudo procesar el pago. Revisá los datos e intentá de nuevo.';
      });
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
        title: Text(_success ? '' : 'Pago'),
        foregroundColor: cs.onSurface,
      ),
      body: _success
          ? _successView(cs)
          : _plan == null
          ? _loadingOrError(cs)
          : _formView(cs),
    );
  }

  Widget _loadingOrError(ColorScheme cs) {
    if (_loadingPlan) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No se pudo cargar el plan. Volvé e intentá de nuevo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _formView(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Resumen del plan
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.workspace_premium, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Plan ${_plan!.label}',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${_plan!.priceLabel}/${_plan!.period}',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            children: [
              _field(
                controller: _number,
                label: 'Número de tarjeta',
                hint: '4242 4242 4242 4242',
                keyboard: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CardNumberFormatter(),
                ],
                validator: (v) {
                  final digits = (v ?? '').replaceAll(' ', '');
                  if (digits.length < 13) return 'Tarjeta inválida';
                  return null;
                },
              ),
              _field(
                controller: _holder,
                label: 'Titular',
                hint: 'NOMBRE APELLIDO',
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Ingresá el titular' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _expiry,
                      label: 'Vence (MM/AA)',
                      hint: '12/29',
                      keyboard: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpiryFormatter(),
                      ],
                      validator: (v) => (v ?? '').length < 5 ? 'MM/AA' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _cvc,
                      label: 'CVC',
                      hint: '123',
                      keyboard: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (v) => (v ?? '').length < 3 ? 'CVC' : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _processing ? null : _pay,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _processing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Pagar ${_plan!.priceLabel}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Pago simulado · no se realiza ningún cobro real',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: formatters,
        validator: validator,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: cs.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _successView(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppTheme.success,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '¡Bienvenido a Premium!',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ya tenés acceso a todas las lecciones, el feedback con IA, '
              'el coach por cámara y más.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.go('/lessons'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Empezar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inserta un espacio cada 4 dígitos en el número de tarjeta.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Formatea MM/AA.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
