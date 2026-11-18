import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/notifications/local_notification_service.dart';
import 'package:mobile/features/profile/presentation/widgets/notification_settings_tile.dart';

class _FakeService implements LocalNotificationService {
  _FakeService({this.deny = false, this.fail = false});

  final bool deny;
  final bool fail;
  bool enabled = false;
  final List<TimeOfDay> scheduled = [];

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<TimeOfDay> getTime() async => const TimeOfDay(hour: 19, minute: 0);

  @override
  Future<void> scheduleDailyReminder({required TimeOfDay time}) async {
    if (deny) throw const NotificationPermissionDeniedException();
    if (fail) throw StateError('alarma exacta no disponible');
    enabled = true;
    scheduled.add(time);
  }

  @override
  Future<void> cancelDailyReminder() async => enabled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('activar el recordatorio lo programa y muestra la hora', (
    tester,
  ) async {
    final service = _FakeService();
    await tester.pumpWidget(_host(NotificationSettingsTile(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('19:00'), findsNothing);

    await tester.tap(find.text('Recordatorio de práctica'));
    await tester.pumpAndSettle();

    expect(service.scheduled, [const TimeOfDay(hour: 19, minute: 0)]);
    expect(find.text('Hora del recordatorio'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
  });

  testWidgets('permiso denegado muestra diálogo que abre los ajustes', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        NotificationSettingsTile(
          service: _FakeService(deny: true),
          openSettings: () async {
            opened++;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recordatorio de práctica'));
    await tester.pumpAndSettle();

    expect(find.text('Notificaciones desactivadas'), findsOneWidget);
    expect(find.text('Hora del recordatorio'), findsNothing);

    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('Notificaciones desactivadas'), findsNothing);
  });

  testWidgets('Ahora no cierra el diálogo sin abrir ajustes', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        NotificationSettingsTile(
          service: _FakeService(deny: true),
          openSettings: () async {
            opened++;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recordatorio de práctica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(find.text('Notificaciones desactivadas'), findsNothing);
  });

  testWidgets('un error real se muestra con su causa y deja el switch en off', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(NotificationSettingsTile(service: _FakeService(fail: true))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recordatorio de práctica'));
    await tester.pumpAndSettle();

    expect(find.textContaining('alarma exacta no disponible'), findsOneWidget);
    expect(find.text('Hora del recordatorio'), findsNothing);
  });
}
