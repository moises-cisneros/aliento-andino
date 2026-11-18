import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Una entrada de la leyenda: ícono + nombre + qué hace.
class _HelpEntry {
  final IconData icon;
  final String label;
  final String description;
  final bool premium;
  const _HelpEntry(
    this.icon,
    this.label,
    this.description, {
    this.premium = false,
  });
}

/// Leyenda de las herramientas de la barra superior de la pantalla de práctica.
/// Se muestra automáticamente la primera vez que se entra a practicar y se puede
/// reabrir cuando se quiera con el botón "?" de la barra.
///
/// Es contenido de referencia estático (no usa el tutor con IA "Vivi", que es
/// conversacional): una hoja inferior con la lista de íconos y su función.
class PracticeToolbarHelpSheet extends StatelessWidget {
  const PracticeToolbarHelpSheet({super.key});

  /// Abre la leyenda como hoja inferior (mismo patrón que el panel de filtros
  /// de Lecciones). Devuelve cuando el usuario la cierra.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PracticeToolbarHelpSheet(),
    );
  }

  static const _entries = <_HelpEntry>[
    _HelpEntry(
      Icons.close,
      'Salir',
      'Cerrás la práctica. Te pregunta antes para no perder el progreso.',
    ),
    _HelpEntry(
      Icons.timer_outlined,
      'Cronómetro',
      'El "0s" muestra el tiempo que llevás practicando.',
    ),
    _HelpEntry(
      Icons.view_agenda,
      'Cambiar vista',
      'Alterná entre Secuencia, Cascada (notas que caen) y Partitura.',
    ),
    _HelpEntry(
      Icons.fiber_manual_record,
      'Grabar mi audio',
      'Graba tu interpretación por el micrófono para reescucharte en los resultados. '
          'Funciona también con el micrófono encendido: tocás en vivo y se '
          'graba a la vez.',
    ),
    _HelpEntry(
      Icons.av_timer,
      'Metrónomo',
      'Marca el pulso al tempo de la lección, con cuenta de entrada 4-3-2-1.',
    ),
    _HelpEntry(
      Icons.mic,
      'Micrófono',
      'La app escucha tu instrumento andino y detecta sola si acertás cada nota.',
    ),
    _HelpEntry(
      Icons.cable,
      'Entrada MIDI',
      'Conectá tu instrumento digital (USB o Bluetooth) para la máxima precisión.',
    ),
    _HelpEntry(
      Icons.videocam,
      'Cámara (coach)',
      'Analiza tu embocadura y manos: postura y digitación mientras tocás.',
      premium: true,
    ),
    _HelpEntry(
      Icons.pause,
      'Pausar',
      'Pausás la práctica y ves tu progreso: correctas, errores y precisión.',
    ),
    _HelpEntry(
      Icons.repeat,
      'Repetir sección (A-B)',
      'Elegí un rango de notas para practicarlo en bucle.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra para arrastrar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.help_outline, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Herramientas de práctica',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tocá un ícono de la barra de arriba para activarlo. Cuando está '
              'activo se pone celeste.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (final e in _entries) _HelpRow(entry: e),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de la leyenda: badge con el ícono + nombre (con chip Premium opcional)
/// + descripción de una línea.
class _HelpRow extends StatelessWidget {
  final _HelpEntry entry;
  const _HelpRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.label,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (entry.premium) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Premium',
                          style: TextStyle(
                            color: AppTheme.warning,
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
                  entry.description,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
