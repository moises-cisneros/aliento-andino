import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/notifications/practice_reminder_service.dart';
import 'clean_switch.dart';

/// Recordatorio diario de práctica: switch + hora. Si el permiso de
/// notificaciones está denegado muestra un diálogo informativo que guía a los
/// ajustes del sistema (sin bloquear la app).
class NotificationSettingsTile extends StatefulWidget {
  const NotificationSettingsTile({super.key, this.service, this.openSettings});

  /// Inyectable para pruebas; por defecto usa el servicio real.
  final LocalNotificationService? service;

  /// Abre los ajustes del sistema. Por defecto [openAppSettings].
  final Future<bool> Function()? openSettings;

  @override
  State<NotificationSettingsTile> createState() =>
      _NotificationSettingsTileState();
}

class _NotificationSettingsTileState extends State<NotificationSettingsTile> {
  late final LocalNotificationService _service =
      widget.service ?? LocalNotificationService();
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _service.isEnabled();
    final time = await _service.getTime();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _time = time;
      });
    }
  }

  Future<void> _toggle(bool val) async {
    if (!val) {
      setState(() => _enabled = false);
      await _service.cancelDailyReminder();
      return;
    }
    try {
      await _service.scheduleDailyReminder(time: _time);
      if (mounted) setState(() => _enabled = true);
    } on NotificationPermissionDeniedException {
      if (!mounted) return;
      setState(() => _enabled = false);
      await _showPermissionDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _enabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo activar el recordatorio: $e')),
      );
    }
  }

  Future<void> _showPermissionDialog() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notificaciones desactivadas'),
        content: const Text(
          'Para recibir el recordatorio de práctica, permití las '
          'notificaciones de Aliento Andino en los ajustes del sistema. '
          'Podés seguir usando la app sin ellas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              (widget.openSettings ?? openAppSettings)();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    setState(() => _time = picked);
    if (!_enabled) return;
    try {
      await _service.scheduleDailyReminder(time: picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reprogramar el recordatorio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _toggle(!_enabled),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.alarm, color: cs.primary, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Recordatorio de práctica',
                      style: TextStyle(color: cs.onSurface, fontSize: 15),
                    ),
                  ),
                  CleanSwitch(value: _enabled, onChanged: _toggle),
                ],
              ),
            ),
          ),
          if (_enabled)
            InkWell(
              onTap: _pickTime,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(52, 0, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hora del recordatorio',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      PracticeReminderService.formatReminderTime(_time),
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: cs.onSurfaceVariant,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
