import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/notifications/practice_reminder_service.dart';

void main() {
  group('PracticeReminderService.formatReminderTime', () {
    test('formatea la hora como HH:mm con ceros a la izquierda', () {
      expect(
        PracticeReminderService.formatReminderTime(
          const TimeOfDay(hour: 19, minute: 0),
        ),
        '19:00',
      );
      expect(
        PracticeReminderService.formatReminderTime(
          const TimeOfDay(hour: 9, minute: 5),
        ),
        '09:05',
      );
      expect(
        PracticeReminderService.formatReminderTime(
          const TimeOfDay(hour: 0, minute: 0),
        ),
        '00:00',
      );
    });
  });

  group('PracticeReminderService.nextReminderInstance', () {
    test('hora de hoy aún por venir → se agenda hoy', () {
      final now = DateTime(2026, 1, 15, 10, 0);
      final next = PracticeReminderService.nextReminderInstance(
        const TimeOfDay(hour: 19, minute: 0),
        now: now,
      );
      expect(next, DateTime(2026, 1, 15, 19, 0));
    });

    test('hora de hoy ya pasada → se agenda mañana', () {
      final now = DateTime(2026, 1, 15, 20, 30);
      final next = PracticeReminderService.nextReminderInstance(
        const TimeOfDay(hour: 19, minute: 0),
        now: now,
      );
      expect(next, DateTime(2026, 1, 16, 19, 0));
    });

    test(
      'hora exactamente igual a ahora → se agenda mañana (no vuelve a disparar hoy)',
      () {
        final now = DateTime(2026, 1, 15, 19, 0, 0);
        final next = PracticeReminderService.nextReminderInstance(
          const TimeOfDay(hour: 19, minute: 0),
          now: now,
        );
        expect(next, DateTime(2026, 1, 16, 19, 0));
      },
    );

    test('cruce de fin de mes se resuelve correctamente', () {
      final now = DateTime(2026, 1, 31, 23, 30);
      final next = PracticeReminderService.nextReminderInstance(
        const TimeOfDay(hour: 23, minute: 0),
        now: now,
      );
      expect(next, DateTime(2026, 2, 1, 23, 0));
    });
  });
}
