import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../data/tutor_repository.dart';
import 'tutor_targets.dart';

/// Ejecuta las acciones que decide el agente tutor: navegar entre pantallas,
/// abrir una lección y resaltar elementos con una pista. Usa el navigator raíz
/// para actuar desde fuera del árbol de widgets (igual que las notificaciones).
class TutorActionExecutor {
  // Rutas de las pestañas principales: se navegan con go() (cambian de tab),
  // el resto con push() (apilan sobre la pila actual).
  static const _mainTabs = {
    '/lessons',
    '/social',
    '/rankings',
    '/progress',
    '/profile',
  };

  OverlayEntry? _activeHint;

  /// Ejecuta una lista de acciones en orden, con una pequeña pausa entre cada
  /// una para que el usuario alcance a seguir la guía.
  Future<void> run(List<TutorAction> actions) async {
    for (final action in actions) {
      await _runOne(action);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  Future<void> _runOne(TutorAction action) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    switch (action.tool) {
      case 'navigate_to':
        final route = action.args['route'] as String?;
        if (route != null && route.isNotEmpty) _navigate(context, route);
      case 'start_lesson':
        final id = action.args['lesson_id'] as String?;
        if (id != null && id.isNotEmpty) context.push('/lessons/$id');
      case 'highlight_element':
        final target = action.args['target'] as String? ?? '';
        final hint = action.args['hint'] as String? ?? '';
        if (hint.isNotEmpty) await _highlight(target, hint);
    }
  }

  /// Resalta el elemento real (spotlight) si está en pantalla; si no, muestra
  /// una pista flotante genérica.
  Future<void> _highlight(String target, String hint) async {
    // El elemento puede tardar unos frames en construirse tras navegar.
    RenderBox? box;
    for (var i = 0; i < 8; i++) {
      final ro = TutorTargets.lookup(
        target,
      )?.currentContext?.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize) {
        box = ro;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    // Las funciones de overlay obtienen su context del propio overlay, así que
    // no arrastramos un BuildContext a través de los awaits de arriba.
    if (box != null) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      _showSpotlight(rect, hint);
    } else {
      _showHint(hint);
    }
  }

  void _navigate(BuildContext context, String route) {
    if (_mainTabs.contains(route)) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  /// Spotlight: dibuja un anillo de resaltado sobre el rect del elemento real
  /// y una burbuja con la pista. Se descarta al tocar o tras unos segundos.
  void _showSpotlight(Rect rect, String hint) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _activeHint?.remove();
    final cs = Theme.of(overlay.context).colorScheme;
    final screen = MediaQuery.of(overlay.context).size;
    final ring = rect.inflate(8);
    final showBelow = ring.bottom + 90 < screen.height;

    late final OverlayEntry entry;
    void dismiss() {
      if (_activeHint == entry) {
        entry.remove();
        _activeHint = null;
      }
    }

    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: dismiss,
            ),
          ),
          Positioned(
            left: ring.left,
            top: ring.top,
            width: ring.width,
            height: ring.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.55),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: showBelow ? ring.bottom + 12 : null,
            bottom: showBelow ? null : (screen.height - ring.top + 12),
            child: _hintBubble(cs, hint),
          ),
        ],
      ),
    );

    _activeHint = entry;
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 5), dismiss);
  }

  /// Pista flotante genérica (fallback cuando el elemento no está en pantalla).
  void _showHint(String hint) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _activeHint?.remove();
    final cs = Theme.of(overlay.context).colorScheme;
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 12,
        left: 16,
        right: 16,
        child: _hintBubble(cs, hint),
      ),
    );

    _activeHint = entry;
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (_activeHint == entry) {
        entry.remove();
        _activeHint = null;
      }
    });
  }

  Widget _hintBubble(ColorScheme cs, String hint) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    _activeHint?.remove();
    _activeHint = null;
  }
}
