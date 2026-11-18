import 'package:flutter/material.dart';

import '../practice/daily_goal_service.dart';
import 'practice_reminder_service.dart';

/// El usuario (o el sistema) rechazó el permiso de notificaciones.
class NotificationPermissionDeniedException implements Exception {
  const NotificationPermissionDeniedException();

  @override
  String toString() => 'Permiso de notificaciones denegado';
}

/// Contrato de HU-20: recordatorio diario local + alerta nocturna.
///
/// Delega la programación en [PracticeReminderService] y consulta la práctica
/// de hoy en [DailyGoalService] (fuente local existente), sin duplicar lógica.
class LocalNotificationService {
  LocalNotificationService({
    PracticeReminderService? reminders,
    DailyGoalService? dailyGoal,
  }) : _reminders = reminders ?? PracticeReminderService(),
       _dailyGoal = dailyGoal ?? DailyGoalService();

  final PracticeReminderService _reminders;
  final DailyGoalService _dailyGoal;

  Future<bool> isEnabled() => _reminders.isEnabled();

  Future<TimeOfDay> getTime() => _reminders.getTime();

  /// Programa (o reprograma) el recordatorio diario a [time] y la alerta
  /// nocturna. Lanza [NotificationPermissionDeniedException] si el permiso fue
  /// rechazado: nunca finge éxito.
  Future<void> scheduleDailyReminder({required TimeOfDay time}) async {
    final granted = await _reminders.enable(time);
    if (!granted) throw const NotificationPermissionDeniedException();
    await syncNightAlert();
  }

  /// Cancela el recordatorio diario y la alerta nocturna.
  Future<void> cancelDailyReminder() => _reminders.disable();

  /// Reprograma la alerta nocturna según la práctica registrada hoy.
  Future<void> syncNightAlert() async {
    final minutes = await _dailyGoal.getTodayMinutes();
    await _reminders.syncNightAlert(todayMinutes: minutes);
  }

  /// Reprograma todo tras un arranque (el SO puede limpiar alarmas).
  Future<void> restore() async {
    await _reminders.rescheduleIfEnabled();
    await syncNightAlert();
  }
}

/// Reprograma la alerta nocturna cuando la app pasa a segundo plano (por si
/// el usuario acaba de practicar) y al volver a primer plano.
class NightAlertLifecycleObserver with WidgetsBindingObserver {
  NightAlertLifecycleObserver(this._service);

  final LocalNotificationService _service;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      _service.syncNightAlert().catchError((Object e) {
        debugPrint('No se pudo reprogramar la alerta nocturna: $e');
      });
    }
  }
}
