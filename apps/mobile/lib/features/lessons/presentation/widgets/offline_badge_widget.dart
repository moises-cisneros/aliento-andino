import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Distinctive icon telling whether a lesson is available without a
/// connection. Rendered as an empty box when the lesson is not downloaded so
/// callers can place it in a row without conditionals.
class OfflineBadgeWidget extends StatelessWidget {
  final bool isDownloaded;
  final double size;

  const OfflineBadgeWidget({
    super.key,
    required this.isDownloaded,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDownloaded) return const SizedBox.shrink();
    return Tooltip(
      message: 'Disponible sin conexión',
      child: Icon(
        Icons.offline_pin_rounded,
        key: const ValueKey('offline-badge-icon'),
        color: AppTheme.success,
        size: size,
        semanticLabel: 'Disponible sin conexión',
      ),
    );
  }
}
