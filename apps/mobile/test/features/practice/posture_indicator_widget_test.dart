import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/practice/posture/posture_scorer.dart';
import 'package:mobile/features/practice/posture/presentation/bloc/posture_bloc.dart';
import 'package:mobile/features/practice/presentation/widgets/posture_indicator_widget.dart';

Color _frameBorderColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byKey(const Key('posture-indicator-frame')),
  );
  final decoration = container.decoration as BoxDecoration;
  return (decoration.border as Border).top.color;
}

Future<void> _pump(
  WidgetTester tester, {
  required double score,
  required bool isTracking,
  bool isActive = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PostureIndicatorWidget(
          scorePercentage: score,
          isTracking: isTracking,
          isActive: isActive,
        ),
      ),
    ),
  );
}

PostureAlignmentEvaluated _evaluated(
  double score,
  PostureTrackingStatus status,
) {
  return PostureAlignmentEvaluated(
    evaluation: PostureEvaluation(
      overallScore: score,
      isErgonomic: score >= 75,
      status: status,
      shoulderTiltDegrees: 1.0,
      neckTiltDegrees: 1.0,
      leftElbowDegrees: 90.0,
      rightElbowDegrees: 90.0,
      embouchureDistance: 0.3,
      feedback: const ['x'],
    ),
    framesProcessed: 1,
  );
}

void main() {
  group('PostureIndicatorWidget.stabilityFor [SUB-06-B]', () {
    test('score alto y en encuadre → aligned', () {
      expect(
        PostureIndicatorWidget.stabilityFor(
          score: 90,
          isTracking: true,
          isActive: true,
        ),
        PostureStability.aligned,
      );
    });

    test('score medio → minorAlert', () {
      expect(
        PostureIndicatorWidget.stabilityFor(
          score: 60,
          isTracking: true,
          isActive: true,
        ),
        PostureStability.minorAlert,
      );
    });

    test('score bajo → critical', () {
      expect(
        PostureIndicatorWidget.stabilityFor(
          score: 30,
          isTracking: true,
          isActive: true,
        ),
        PostureStability.critical,
      );
    });

    test('cámara inactiva congela el indicador → inactive', () {
      expect(
        PostureIndicatorWidget.stabilityFor(
          score: 90,
          isTracking: true,
          isActive: false,
        ),
        PostureStability.inactive,
      );
    });

    test('colores mapeados a tokens de DESIGN.md', () {
      expect(
        PostureIndicatorWidget.colorForStability(PostureStability.aligned),
        AppTheme.success,
      );
      expect(
        PostureIndicatorWidget.colorForStability(PostureStability.minorAlert),
        AppTheme.orange,
      );
      expect(
        PostureIndicatorWidget.colorForStability(PostureStability.critical),
        AppTheme.error,
      );
    });
  });

  group('PostureIndicatorWidget render condicional [SUB-06-B]', () {
    testWidgets('alineado: borde verde #10B981 y etiqueta', (tester) async {
      await _pump(tester, score: 92, isTracking: true);
      expect(_frameBorderColor(tester), AppTheme.success);
      expect(find.text('Alineado'), findsOneWidget);
    });

    testWidgets('alerta leve: borde naranja #F97316', (tester) async {
      await _pump(tester, score: 60, isTracking: true);
      expect(_frameBorderColor(tester), AppTheme.orange);
      expect(find.text('Ajustá tu postura'), findsOneWidget);
    });

    testWidgets('crítico: borde rojo #EF4444', (tester) async {
      await _pump(tester, score: 25, isTracking: true);
      expect(_frameBorderColor(tester), AppTheme.error);
      expect(find.text('Corregí la postura'), findsOneWidget);
    });

    testWidgets('fuera de encuadre: visor neutro, sin crash', (tester) async {
      await _pump(tester, score: 90, isTracking: false);
      expect(_frameBorderColor(tester), AppTheme.muted);
      expect(find.text('Sin señal postural'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cámara desconectada: congela sin crashear', (tester) async {
      await _pump(tester, score: 90, isTracking: true, isActive: false);
      expect(_frameBorderColor(tester), AppTheme.muted);
      expect(tester.takeException(), isNull);
    });
  });

  group('PostureIndicatorWidget.fromState [SUB-06-B]', () {
    testWidgets('mapea PostureAlignmentEvaluated en tracking', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostureIndicatorWidget.fromState(
              _evaluated(90, PostureTrackingStatus.tracking),
            ),
          ),
        ),
      );
      expect(_frameBorderColor(tester), AppTheme.success);
    });

    testWidgets('estado no evaluado → indicador congelado', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostureIndicatorWidget.fromState(const PostureInitial()),
          ),
        ),
      );
      expect(_frameBorderColor(tester), AppTheme.muted);
    });
  });
}
