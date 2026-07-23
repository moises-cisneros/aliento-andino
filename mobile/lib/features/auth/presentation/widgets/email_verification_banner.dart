import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/services/email_verification_service.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../domain/entities/user_entity.dart';

/// Banner amarillo que aparece en la home si el email del usuario no está
/// verificado. Tap → abre dialog para meter el código de 6 dígitos.
class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  State<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  bool _sending = false;
  bool _dismissed = false;

  Future<void> _sendCode() async {
    setState(() => _sending = true);
    try {
      await context.read<EmailVerificationService>().sendCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código enviado a tu email'),
          backgroundColor: AppTheme.success,
        ),
      );
      _openCodeDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openCodeDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verificá tu email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Te enviamos un código de 6 dígitos. Ingresalo acá:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Verificar'),
          ),
        ],
      ),
    );

    if (code == null || code.length != 6 || !mounted) return;
    await _verifyCode(code);
  }

  Future<void> _verifyCode(String code) async {
    try {
      await context.read<EmailVerificationService>().verify(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Email verificado! 🎉'),
          backgroundColor: AppTheme.success,
        ),
      );
      // Refrescar el user del AuthBloc para que oculte el banner
      context.read<AuthBloc>().add(AuthCheckRequested());
    } catch (e) {
      if (!mounted) return;
      String msg = 'Código incorrecto o expirado';
      try {
        final detail = (e as dynamic).response?.data?['detail'];
        if (detail is String) msg = detail;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        UserEntity? user;
        if (state is AuthAuthenticated) user = state.user;
        if (state is AuthRegistered) user = state.user;
        if (state is AuthProfileUpdated) user = state.user;
        if (user == null || user.isVerified) return const SizedBox.shrink();

        return Material(
          color: const Color(0xFFFEF3C7),
          child: InkWell(
            onTap: _sending ? null : _sendCode,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    color: Color(0xFFB45309),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Verificá tu email para asegurar tu cuenta',
                      style: TextStyle(
                        color: Color(0xFF78350F),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_sending)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFB45309),
                      ),
                    )
                  else
                    const Text(
                      'Verificar',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: const Color(0xFF78350F),
                    onPressed: () => setState(() => _dismissed = true),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
