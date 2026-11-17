import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../network/api_client.dart';
import '../router/app_router.dart';

/// Servicio que pide permisos de notificación, obtiene el token FCM y lo
/// sincroniza con el backend. También renderiza notificaciones locales para
/// que sean visibles cuando la app está en foreground.
class NotificationService {
  final ApiClient _apiClient;
  String? _currentToken;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  bool _localNotifReady = false;

  static const _androidChannel = AndroidNotificationChannel(
    'aliento_andino_default',
    'Notificaciones Aliento Andino',
    description: 'Notificaciones generales de la app',
    importance: Importance.high,
  );

  NotificationService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<void> _ensureLocalNotifReady() async {
    if (_localNotifReady) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
    _localNotifReady = true;
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    await _ensureLocalNotifReady();
    await _localNotif.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  /// Inicializar tras el login: pedir permisos, obtener token, registrarlo
  /// en el backend y subscribirse al refresh automático.
  Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await _ensureLocalNotifReady();

      // Pedir el permiso de notificaciones de UNA sola forma por plataforma.
      // El sistema solo muestra el diálogo una vez; mezclar el pedido de
      // firebase_messaging con el de flutter_local_notifications en Android
      // "consumía" el diálogo y dejaba el permiso sin conceder.
      if (Platform.isAndroid) {
        // Android 13+: POST_NOTIFICATIONS vía flutter_local_notifications
        // (la vía que sí dispara el diálogo del sistema de forma confiable).
        final granted = await _localNotif
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        debugPrint('Permiso POST_NOTIFICATIONS (Android): $granted');
      } else {
        // iOS: el diálogo lo maneja firebase_messaging / APNs.
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('Permiso notif (iOS): ${settings.authorizationStatus}');
      }

      // Obtener y registrar el token SIEMPRE, sin importar si la notificación
      // se mostrará: el token es necesario para RECIBIR el push; el permiso
      // solo controla si se MUESTRA. Así el dispositivo queda registrado.
      final token = await messaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      } else {
        debugPrint('getToken() devolvió null (¿Play Services?)');
      }

      // Refresh automático del token (caduca cada tanto)
      messaging.onTokenRefresh.listen(_sendTokenToBackend);

      // Foreground: mostrar como notificación local visible (banner + sonido).
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('FCM foreground: ${message.notification?.title}');
        _showLocal(message);
      });

      // Background → foreground: el usuario tocó la notificación y la app
      // estaba en segundo plano. Navegamos al destino correspondiente.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Terminada → abierta: la app se abrió desde cero al tocar la
      // notificación. getInitialMessage() trae ese mensaje inicial (si hubo).
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('NotificationService.initialize falló: $e');
    }
  }

  /// Navega al destino de una notificación push según su `data.type`,
  /// reutilizando el mismo mapeo que la pantalla de notificaciones in-app.
  void _handleNotificationTap(RemoteMessage message) {
    final route = _routeForData(message.data);
    if (route == null) return;
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      context.push(route);
    }
  }

  String? _routeForData(Map<String, dynamic> data) {
    final type = data['type'];
    final postId = data['post_id'];
    final userId = data['user_id'];
    switch (type) {
      case 'like':
      case 'comment':
      case 'comment_reply':
      case 'comment_like':
      case 'mention':
        return postId != null ? '/social/post/$postId' : null;
      case 'follow':
        return userId != null ? '/social/user/$userId' : null;
      case 'achievement':
      case 'level_up':
        return '/achievements';
      default:
        return null;
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    if (_currentToken == token) return;
    try {
      await _apiClient.dio.post(
        '/notifications/register-token',
        data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );
      _currentToken = token;
      debugPrint('Token FCM registrado: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('Error registrando token FCM: $e');
    }
  }

  /// Llamar antes del logout para borrar el token del backend.
  Future<void> unregister() async {
    if (_currentToken == null) return;
    try {
      await _apiClient.dio.delete(
        '/notifications/unregister-token',
        data: {'token': _currentToken},
      );
    } catch (e) {
      debugPrint('Error al desregistrar token: $e');
    } finally {
      _currentToken = null;
    }
  }
}
