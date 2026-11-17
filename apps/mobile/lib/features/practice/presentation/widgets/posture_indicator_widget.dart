import 'package:flutter/material.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/practice/posture/presentation/bloc/posture_bloc.dart';

/// Nivel de estabilidad postural que determina la semántica de color del visor.
enum PostureStability {
  /// Postura alineada y ergonómica.
  aligned,

  /// Desviación leve: corrección sugerida, sin urgencia.
  minorAlert,

  /// Corrección crítica: vicio ergonómico marcado.
  critical,

  /// Sin señal (usuario fuera de encuadre o cámara inactiva): visor congelado.
  inactive,
}

/// [SUB-06-B] Visor ergonómico minimalista de postura.
///
/// Dibuja un marco sutil en el borde de la pantalla cuyo color cambia según la
/// estabilidad postural, evitando saturación cognitiva durante la práctica.
/// Consume exclusivamente los tokens de [`apps/mobile/DESIGN.md`] vía
/// [AppTheme]: alineado `#10B981` ([AppTheme.success]), alerta menor `#F97316`
/// ([AppTheme.orange]) y corrección crítica `#EF4444` ([AppTheme.error]).
///
/// Si la cámara se desconecta o la app pasa a segundo plano ([isActive] = false),
/// el indicador se congela en estado [PostureStability.inactive] sin crashear.
class PostureIndicatorWidget extends StatelessWidget {
  /// Puntuación de postura 0–100 (`posture_score_percentage`).
  final double scorePercentage;

  /// `true` si la cámara mantiene visibilidad del músico (usuario en encuadre).
  final bool isTracking;

  /// `true` mientras la cámara está conectada y la app en primer plano.
  final bool isActive;

  const PostureIndicatorWidget({
    super.key,
    required this.scorePercentage,
    required this.isTracking,
    this.isActive = true,
  });

  /// Umbral de score para considerar la postura alineada.
  static const double alignedThreshold = 75.0;

  /// Umbral de score por debajo del cual la corrección es crítica.
  static const double criticalThreshold = 50.0;

  /// Deriva la estabilidad a partir del score y el estado de la cámara.
  static PostureStability stabilityFor({
    required double score,
    required bool isTracking,
    required bool isActive,
  }) {
    if (!isActive || !isTracking) return PostureStability.inactive;
    if (score >= alignedThreshold) return PostureStability.aligned;
    if (score >= criticalThreshold) return PostureStability.minorAlert;
    return PostureStability.critical;
  }

  /// Color semántico (token de DESIGN.md) para cada nivel de estabilidad.
  static Color colorForStability(PostureStability stability) {
    switch (stability) {
      case PostureStability.aligned:
        return AppTheme.success; // #10B981
      case PostureStability.minorAlert:
        return AppTheme.orange; // #F97316
      case PostureStability.critical:
        return AppTheme.error; // #EF4444
      case PostureStability.inactive:
        return AppTheme.muted; // neutro: visor congelado
    }
  }

  static String _labelFor(PostureStability stability) {
    switch (stability) {
      case PostureStability.aligned:
        return 'Alineado';
      case PostureStability.minorAlert:
        return 'Ajustá tu postura';
      case PostureStability.critical:
        return 'Corregí la postura';
      case PostureStability.inactive:
        return 'Sin señal postural';
    }
  }

  /// Construye el visor a partir del estado del [PostureBloc].
  ///
  /// Congela el indicador ([isActive] = false) cuando el estado no es de
  /// evaluación activa (p. ej. cámara desconectada, permiso denegado o error).
  factory PostureIndicatorWidget.fromState(PostureState state, {Key? key}) {
    if (state is PostureAlignmentEvaluated) {
      return PostureIndicatorWidget(
        key: key,
        scorePercentage: state.postureScorePercentage,
        isTracking: state.isTracking,
        isActive: true,
      );
    }
    return PostureIndicatorWidget(
      key: key,
      scorePercentage: 0.0,
      isTracking: false,
      isActive: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stability = stabilityFor(
      score: scorePercentage,
      isTracking: isTracking,
      isActive: isActive,
    );
    final color = colorForStability(stability);
    final label = _labelFor(stability);

    return IgnorePointer(
      child: Semantics(
        label: 'Estabilidad postural: $label',
        child: Stack(
          children: [
            // Marco sutil en el borde de la pantalla.
            Positioned.fill(
              child: Container(
                key: const Key('posture-indicator-frame'),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 4),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // Pastilla discreta con punto de color y etiqueta.
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
