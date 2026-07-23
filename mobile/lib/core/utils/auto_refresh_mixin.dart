import 'package:flutter/widgets.dart';

/// Mixin para `State` que dispara un refresco SILENCIOSO cuando la app vuelve
/// del segundo plano (`AppLifecycleState.resumed`) y esta pantalla es la que
/// está arriba. Así las pantallas se actualizan solas al reabrir la app, sin
/// que el usuario tenga que deslizar de arriba hacia abajo.
///
/// Uso:
/// ```dart
/// class _MiPantallaState extends State<MiPantalla> with AutoRefreshOnResume {
///   @override
///   void onAutoRefresh() {
///     context.read<MiBloc>().add(const MiRefresh()); // refresco sin spinner
///   }
/// }
/// ```
///
/// No reemplaza al pull-to-refresh (que se mantiene como respaldo manual) ni
/// usa timers/polling: es refresco por evento (reanudar la app).
mixin AutoRefreshOnResume<T extends StatefulWidget> on State<T> {
  late final _AutoRefreshObserver _autoRefreshObserver;

  @override
  void initState() {
    super.initState();
    _autoRefreshObserver = _AutoRefreshObserver(_handleResumed);
    WidgetsBinding.instance.addObserver(_autoRefreshObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_autoRefreshObserver);
    super.dispose();
  }

  void _handleResumed() {
    if (!mounted) return;
    // Solo si esta pantalla es la actual (no hay un detalle/modal encima).
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrent) onAutoRefresh();
  }

  /// Implementar: disparar el refresco silencioso (sin loading de pantalla
  /// completa). Se llama al reanudar la app si la pantalla está visible.
  void onAutoRefresh();
}

/// Observer liviano que solo nos avisa del estado `resumed`. Se mantiene aparte
/// para no obligar a cada State a implementar toda la interfaz del observer.
class _AutoRefreshObserver with WidgetsBindingObserver {
  final VoidCallback onResumed;
  _AutoRefreshObserver(this.onResumed);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}
