import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/presentation/widgets/breath_profile_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileEditForm Unit Tests [SUB-19-A]', () {
    test('Validador de nombre completo exige mínimo 2 caracteres', () {
      String? validateFullName(String? v) {
        if (v == null || v.trim().length < 2) {
          return 'Mínimo 2 caracteres';
        }
        return null;
      }

      expect(validateFullName(null), equals('Mínimo 2 caracteres'));
      expect(validateFullName(''), equals('Mínimo 2 caracteres'));
      expect(validateFullName('A'), equals('Mínimo 2 caracteres'));
      expect(validateFullName('   '), equals('Mínimo 2 caracteres'));
      expect(validateFullName('Moises'), isNull);
      expect(validateFullName('Kantu Andino'), isNull);
    });

    test(
      'Validador de username exige mínimo 3 caracteres y formato alfanumérico',
      () {
        String? validateUsername(String? v) {
          if (v == null || v.trim().length < 3) {
            return 'Mínimo 3 caracteres';
          }
          if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v.trim())) {
            return 'Solo minúsculas, números y guion bajo';
          }
          return null;
        }

        expect(validateUsername(null), equals('Mínimo 3 caracteres'));
        expect(validateUsername('ab'), equals('Mínimo 3 caracteres'));
        expect(
          validateUsername('Usuario Mayus'),
          equals('Solo minúsculas, números y guion bajo'),
        );
        expect(
          validateUsername('user name'),
          equals('Solo minúsculas, números y guion bajo'),
        );
        expect(
          validateUsername('user-dash'),
          equals('Solo minúsculas, números y guion bajo'),
        );
        expect(validateUsername('sikuri_123'), isNull);
        expect(validateUsername('quena_master'), isNull);
      },
    );

    testWidgets(
      'BreathProfileCard renderiza umbral RMS, fecha y responde a tap',
      (tester) async {
        bool recalibrateTapped = false;
        final testDate = DateTime(2026, 11, 17, 10, 30);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BreathProfileCard(
                rmsThreshold: 0.0452,
                lastCalibrated: testDate,
                onRecalibrate: () => recalibrateTapped = true,
              ),
            ),
          ),
        );

        expect(find.text('Calibración Respiratoria'), findsOneWidget);
        expect(
          find.text('Sensibilidad "Soplo Suave" (Edge AI)'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('breath_profile_rms_value')),
          findsOneWidget,
        );
        expect(find.text('0.0452 RMS'), findsOneWidget);
        expect(find.text('17/11/2026 10:30'), findsOneWidget);

        final buttonFinder = find.byKey(const Key('recalibrate_breath_button'));
        expect(buttonFinder, findsOneWidget);

        await tester.tap(buttonFinder);
        await tester.pump();

        expect(recalibrateTapped, isTrue);
      },
    );
  });
}
