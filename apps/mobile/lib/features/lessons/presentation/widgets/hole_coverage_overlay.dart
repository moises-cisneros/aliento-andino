import 'package:flutter/material.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/practice/hands/fingering_evaluator.dart';

/// [SUB-07-B] Indicadores cromáticos de oclusión y alertas de embocadura.
///
/// Widget reactivo enlazado al stream de [HandCoverageEvaluation]: pinta los
/// orificios teóricos del instrumento sobre el visor de cámara en **verde**
/// (`#10B981`, cubierto hermético) o **rojo** (`#EF4444`, fuga de aire), según
/// la cobertura detectada por [FingeringEvaluator]. Consume exclusivamente los
/// tokens de `apps/mobile/DESIGN.md` vía [AppTheme].
///
/// Manejo de errores: si no hay una lectura confiable ([HandCoverageEvaluation]
/// nula, de baja confianza o sin orificios) hace *fallback* a la visualización
/// estática de digitación (contornos neutros), sin inventar oclusión ni
/// crashear.
class HoleCoverageOverlay extends StatelessWidget {
  /// Flujo de evaluaciones de agarre emitido por el pipeline de manos.
  final Stream<HandCoverageEvaluation> evaluationStream;

  /// Instrumento activo; determina el mapa geométrico de orificios a pintar.
  final InstrumentType instrument;

  /// Evaluación inicial opcional mientras llega el primer evento del stream.
  final HandCoverageEvaluation? initial;

  const HoleCoverageOverlay({
    super.key,
    required this.evaluationStream,
    required this.instrument,
    this.initial,
  });

  /// Color semántico (token de DESIGN.md) según el estado de oclusión.
  ///
  /// - Orificio requerido y cubierto → [AppTheme.success] (`#10B981`).
  /// - Orificio requerido con fuga → [AppTheme.error] (`#EF4444`).
  /// - Orificio no requerido (abierto, no se juzga) → [AppTheme.muted].
  static Color colorForHole(HoleCoverage hole) {
    if (!hole.required) return AppTheme.muted;
    return hole.covered ? AppTheme.success : AppTheme.error;
  }

  /// `true` cuando la evaluación no es apta para pintar oclusión y se debe caer
  /// a la visualización estática de digitación.
  static bool shouldFallbackToStatic(HandCoverageEvaluation? evaluation) =>
      evaluation == null ||
      evaluation.confidence == HandTrackingConfidence.low ||
      evaluation.holes.isEmpty;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: StreamBuilder<HandCoverageEvaluation>(
        stream: evaluationStream,
        initialData: initial,
        builder: (context, snapshot) {
          final evaluation = snapshot.data;
          final useStatic = shouldFallbackToStatic(evaluation);
          return Semantics(
            label: useStatic
                ? 'Digitación de referencia'
                : (evaluation!.hasLeak
                      ? 'Fuga de aire detectada en los orificios'
                      : 'Agarre hermético'),
            child: CustomPaint(
              key: const Key('hole-coverage-overlay'),
              painter: _HoleCoveragePainter(
                instrument: instrument,
                evaluation: useStatic ? null : evaluation,
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

/// Pintor de los círculos de orificios sobre el eje normalizado del instrumento.
class _HoleCoveragePainter extends CustomPainter {
  final InstrumentType instrument;

  /// Evaluación vigente; `null` activa la visualización estática (fallback).
  final HandCoverageEvaluation? evaluation;

  const _HoleCoveragePainter({
    required this.instrument,
    required this.evaluation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final holes = InstrumentHoleMap.of(instrument);
    final byId = {
      for (final h in evaluation?.holes ?? const <HoleCoverage>[]) h.holeId: h,
    };
    final radius = size.shortestSide * 0.035;

    for (final hole in holes) {
      final center = Offset(hole.x * size.width, hole.y * size.height);
      final coverage = byId[hole.id];
      final color = coverage != null
          ? HoleCoverageOverlay.colorForHole(coverage)
          : AppTheme.muted; // fallback estático: contorno neutro

      final fill = Paint()
        ..color = color.withValues(alpha: coverage == null ? 0.12 : 0.28)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _HoleCoveragePainter oldDelegate) =>
      oldDelegate.evaluation != evaluation ||
      oldDelegate.instrument != instrument;
}
