import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'connectivity_service.dart';

/// Franja que aparece cuando no hay conexión, para avisar que lo que se ve son
/// los últimos datos guardados (pueden estar desactualizados). Va dentro del
/// body, debajo del AppBar. No ocupa espacio cuando hay conexión.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.read<ConnectivityService>();
    return StreamBuilder<bool>(
      stream: connectivity.statusStream,
      builder: (context, snapshot) {
        final online = snapshot.data ?? true; // sin evento aún: asumimos online
        if (online) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          color: cs.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Sin conexión · mostrando lo último guardado',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
