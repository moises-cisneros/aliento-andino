import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/notifications/local_notification_service.dart';
import 'package:mobile/core/notifications/practice_reminder_service.dart';
import 'package:mobile/core/practice/daily_goal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Programación simulada: registra las llamadas sin tocar el plugin real.
class FakeReminders extends PracticeReminderService {
  FakeReminders({this.grant = true});

  final bool grant;
  bool enabled = false;
  final List<TimeOfDay> scheduled = [];
  final List<int> nightSyncs = [];
  int cancels = 0;

  @override
  Future<bool> enable(TimeOfDay time) async {
    if (!grant) return false;
    enabled = true;
    scheduled.add(time);
    return true;
  }

  @override
  Future<void> disable() async {
    enabled = false;
    cancels++;
  }

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> syncNightAlert({required int todayMinutes}) async {
    nightSyncs.add(todayMinutes);
  }

  @override
  Future<void> rescheduleIfEnabled() async {}
}

String _todayKey() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'scheduleDailyReminder programa la hora y sincroniza la alerta',
    () async {
      SharedPreferences.setMockInitialValues({});
      final fake = FakeReminders();
      final service = LocalNotificationService(reminders: fake);

      await service.scheduleDailyReminder(
        time: const TimeOfDay(hour: 8, minute: 5),
      );

      expect(fake.scheduled, [const TimeOfDay(hour: 8, minute: 5)]);
      expect(fake.nightSyncs, [0]);
    },
  );

  test('permiso denegado lanza excepción y no programa nada', () async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeReminders(grant: false);
    final service = LocalNotificationService(reminders: fake);

    await expectLater(
      service.scheduleDailyReminder(time: const TimeOfDay(hour: 8, minute: 0)),
      throwsA(isA<NotificationPermissionDeniedException>()),
    );
    expect(fake.scheduled, isEmpty);
    expect(fake.nightSyncs, isEmpty);
  });

  test('cancelDailyReminder cancela el recordatorio', () async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeReminders()..enabled = true;
    await LocalNotificationService(reminders: fake).cancelDailyReminder();
    expect(fake.enabled, isFalse);
    expect(fake.cancels, 1);
  });

  test('alerta nocturna sin práctica hoy recibe 0 minutos', () async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeReminders();
    await LocalNotificationService(reminders: fake).syncNightAlert();
    expect(fake.nightSyncs, [0]);
  });

  test(
    'alerta nocturna con práctica hoy recibe los minutos practicados',
    () async {
      SharedPreferences.setMockInitialValues({
        'daily_goal_date': _todayKey(),
        'daily_goal_today_seconds': 600,
      });
      final fake = FakeReminders();
      final service = LocalNotificationService(
        reminders: fake,
        dailyGoal: DailyGoalService(),
      );
      await service.syncNightAlert();
      expect(fake.nightSyncs, [10]);
    },
  );
}
