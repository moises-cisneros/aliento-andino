import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorio diario de práctica con una notificación local programada
/// (sin servidor, sin polling). El usuario elige la hora; se repite cada día.
class PracticeReminderService {
  static const _enabledKey = 'practice_reminder_enabled';
  static const _hourKey = 'practice_reminder_hour';
  static const _minuteKey = 'practice_reminder_minute';
  static const int _reminderId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fallback: elegir una zona con el MISMO offset actual del dispositivo
      // (así el recordatorio no se dispara a la hora UTC equivocada).
      tz.setLocalLocation(_zoneForCurrentOffset());
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);
    await _plugin.initialize(init);
    _ready = true;
  }

  tz.Location _zoneForCurrentOffset() {
    final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.currentTimeZone.offset == offsetMs) return loc;
    }
    return tz.getLocation('UTC');
  }

  /// Pide el permiso de notificaciones (Android 13+ / iOS). Devuelve true si
  /// quedó concedido (o si la plataforma no lo requiere).
  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    }
    return true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<TimeOfDay> getTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_hourKey) ?? 19,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
  }

  /// Activa (o reprograma) el recordatorio diario a la hora dada. Devuelve
  /// false si el usuario rechazó el permiso de notificaciones.
  Future<bool> enable(TimeOfDay time) async {
    await _ensureReady();
    final granted = await _requestPermission();
    if (!granted) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);
    await _schedule(time);
    return true;
  }

  Future<void> disable() async {
    await _ensureReady();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await _plugin.cancel(_reminderId);
  }

  /// Reprograma en el arranque de la app si quedó activado (el SO puede limpiar
  /// las alarmas tras reinicios/updates). No vuelve a pedir permiso: el usuario
  /// ya lo concedió al activarlo.
  Future<void> rescheduleIfEnabled() async {
    if (!await isEnabled()) return;
    await _ensureReady();
    await _schedule(await getTime());
  }

  Future<void> _schedule(TimeOfDay time) async {
    await _plugin.cancel(_reminderId);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'practice_reminders',
        'Recordatorios de práctica',
        channelDescription: 'Aviso diario para practicar piano',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.zonedSchedule(
      _reminderId,
      '¡Hora de practicar! 🎹',
      'Mantené tu racha: unos minutos al día hacen la diferencia.',
      _nextInstanceOf(time),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // se repite cada día
    );
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
