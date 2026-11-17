import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/tutor/tutor_prompt_builder.dart';
import 'package:mobile/features/tutor/presentation/widgets/tutor_feedback_card.dart';

void main() {
  group('TutorFeedbackCard - Pruebas de Integración de Widget', () {
    testWidgets(
      'Muestra correctamente el texto generado y el badge del instrumento',
      (WidgetTester tester) async {
        bool acknowledged = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TutorFeedbackCard(
                feedback:
                    'Excelente ejecución en Quena. Cubre bien el 3er orificio para estabilizar la octava.',
                instrument: InstrumentType.quena,
                onAcknowledge: () {
                  acknowledged = true;
                },
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('tutor_feedback_card')), findsOneWidget);
        expect(find.text('Tutor Pedagógico'), findsOneWidget);
        expect(find.text('Consejo para Quena'), findsOneWidget);
        expect(find.text('On-Device'), findsOneWidget);

        final feedbackFinder = find.byKey(const Key('tutor_feedback_text'));
        expect(feedbackFinder, findsOneWidget);
        expect(
          tester.widget<Text>(feedbackFinder).data,
          contains('Cubre bien el 3er orificio'),
        );

        // Verificación de ergonomía (Ley de Fitts: altura >= 48px)
        final acknowledgeButtonFinder = find.byKey(
          const Key('tutor_acknowledge_button'),
        );
        expect(acknowledgeButtonFinder, findsOneWidget);
        final buttonSize = tester.getSize(acknowledgeButtonFinder);
        expect(buttonSize.height, greaterThanOrEqualTo(48.0));

        await tester.tap(acknowledgeButtonFinder);
        await tester.pump();
        expect(acknowledged, isTrue);
      },
    );

    testWidgets('Muestra consejo predeterminado ante respuesta nula o vacía', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TutorFeedbackCard(
              feedback: '',
              instrument: InstrumentType.zampona,
            ),
          ),
        ),
      );

      final feedbackFinder = find.byKey(const Key('tutor_feedback_text'));
      expect(feedbackFinder, findsOneWidget);
      expect(
        tester.widget<Text>(feedbackFinder).data,
        equals(TutorPromptBuilder.defaultPedagogicalAdvice),
      );
      expect(find.text('Consejo para Zampoña'), findsOneWidget);
    });

    testWidgets(
      'Muestra consejo predeterminado y botón de reintento ante error',
      (WidgetTester tester) async {
        bool retried = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TutorFeedbackCard(
                errorMessage: 'Timeout en inferencia',
                instrument: InstrumentType.tarka,
                onRetry: () {
                  retried = true;
                },
              ),
            ),
          ),
        );

        final feedbackFinder = find.byKey(const Key('tutor_feedback_text'));
        expect(
          tester.widget<Text>(feedbackFinder).data,
          equals(TutorPromptBuilder.defaultPedagogicalAdvice),
        );

        final retryButton = find.byKey(const Key('tutor_retry_button'));
        expect(retryButton, findsOneWidget);
        final retrySize = tester.getSize(retryButton);
        expect(retrySize.height, greaterThanOrEqualTo(48.0));

        await tester.tap(retryButton);
        await tester.pump();
        expect(retried, isTrue);
      },
    );

    testWidgets('Muestra estado de carga mientras se ejecuta el SLM local', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TutorFeedbackCard(
              isLoading: true,
              instrument: InstrumentType.quena,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('tutor_loading_indicator')), findsOneWidget);
      expect(
        find.text('Sintetizando análisis con SLM local...'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('tutor_feedback_text')), findsNothing);
      expect(find.byKey(const Key('tutor_acknowledge_button')), findsNothing);
    });
  });
}
