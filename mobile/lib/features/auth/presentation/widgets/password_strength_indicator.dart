import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Indicador visual de fortaleza de contraseña.
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength(context, password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: strength.value,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                color: strength.color,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 12),
            Text(
              strength.label,
              style: TextStyle(
                color: strength.color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  _PasswordStrength _calculateStrength(BuildContext context, String password) {
    if (password.isEmpty) {
      return _PasswordStrength(
        '',
        0,
        Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }

    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) {
      return _PasswordStrength(
        'Débil',
        0.33,
        Theme.of(context).colorScheme.error,
      );
    } else if (score <= 3) {
      return _PasswordStrength('Media', 0.66, Colors.orange);
    } else {
      return _PasswordStrength('Fuerte', 1.0, AppTheme.success);
    }
  }
}

class _PasswordStrength {
  final String label;
  final double value;
  final Color color;

  const _PasswordStrength(this.label, this.value, this.color);
}
