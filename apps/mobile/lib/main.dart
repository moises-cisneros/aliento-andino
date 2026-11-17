import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/connectivity/connectivity_service.dart';
import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/network/upload_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/practice_reminder_service.dart';
import 'core/storage/secure_storage.dart';
import 'core/sync/practice_sync_service.dart';
import 'firebase_options.dart';
import 'features/lessons/data/datasources/local_lesson_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/data/services/email_verification_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/lessons/data/repositories/lesson_repository.dart';
import 'features/lessons/data/services/lesson_download_service.dart';
import 'features/lessons/data/repositories/practice_repository.dart';
import 'features/notifications/data/notification_repository.dart';
import 'features/onboarding/data/onboarding_storage.dart';
import 'features/profile/data/repositories/profile_repository.dart';
import 'features/rankings/data/repositories/ranking_repository.dart';
import 'features/social/data/repositories/social_repository.dart';
import 'features/social/data/repositories/user_repository.dart';
import 'features/subscription/data/repositories/subscription_repository.dart';
import 'features/tutor/data/tutor_repository.dart';
import 'features/tutor/offline/offline_faq_assistant.dart';

/// Handler de mensajes FCM en background/terminado. Debe ser una función de
/// nivel superior con `@pragma('vm:entry-point')` porque corre en un isolate
/// separado. En Android, los mensajes de tipo "notification" se muestran solos
/// en la bandeja del sistema; este handler garantiza la inicialización de
/// Firebase en ese isolate y es el punto de extensión para mensajes data-only.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init (background) falló: $e');
  }
  debugPrint('FCM background recibido: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase (FCM, etc.). No bloqueante si falla.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Registrar el handler de notificaciones en background/terminado.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase.initializeApp falló: $e');
  }

  // Preferencias locales (tema, etc.)
  final prefs = await SharedPreferences.getInstance();

  // Storage del onboarding (flag completado + skill_level temporal)
  final onboardingStorage = OnboardingStorage(prefs);

  // Inicializar dependencias
  final secureStorage = SecureStorageService();

  late final AuthBloc authBloc;

  final apiClient = ApiClient(secureStorage: secureStorage);
  apiClient.onAuthError = () {
    authBloc.add(AuthLogoutRequested());
  };

  final remoteDatasource = AuthRemoteDatasource(apiClient: apiClient);
  final authRepository = AuthRepository(remoteDatasource: remoteDatasource);

  // Base de datos local (cache offline de lecciones + outbox de prácticas)
  final appDatabase = AppDatabase();
  final localLessonDataSource = LocalLessonDataSource(appDatabase);

  // Repositorios de lecciones (cache-aware)
  final lessonDownloadService = LessonDownloadService(
    api: apiClient.dio,
    db: appDatabase,
    audioDirectory: getApplicationDocumentsDirectory,
  );
  final lessonRepository = LessonRepository(
    apiClient: apiClient,
    local: localLessonDataSource,
    downloads: lessonDownloadService,
  );
  final practiceRepository = PracticeRepository(
    apiClient: apiClient,
    db: appDatabase,
  );

  // Sincronización: vacía el outbox de prácticas al recuperar conexión.
  final connectivityService = ConnectivityService();
  final practiceSyncService = PracticeSyncService(
    db: appDatabase,
    apiClient: apiClient,
    connectivity: connectivityService,
  )..start();
  unawaited(practiceSyncService.syncPending()); // intento inicial al arrancar

  // Repositorios sociales (feed cache-aware)
  final socialRepository = SocialRepository(
    apiClient: apiClient,
    db: appDatabase,
  );
  final userRepository = UserRepository(apiClient: apiClient);

  // Repositorio de rankings (leaderboards cache-aware)
  final rankingRepository = RankingRepository(
    apiClient: apiClient,
    db: appDatabase,
  );

  // Repositorio de perfil (cache-aware para offline)
  final profileRepository = ProfileRepository(
    apiClient: apiClient,
    db: appDatabase,
  );

  // Repositorio de suscripción (pago simulado / gating premium)
  final subscriptionRepository = SubscriptionRepository(apiClient: apiClient);

  // Servicio de uploads a Cloud Storage (via backend)
  final uploadService = UploadService(apiClient: apiClient);

  // Servicio de verificación de email
  final emailVerificationService = EmailVerificationService(
    apiClient: apiClient,
  );

  // Servicio de notificaciones FCM
  final notificationService = NotificationService(apiClient: apiClient);

  // Reprogramar el recordatorio diario de práctica si el usuario lo activó.
  unawaited(PracticeReminderService().rescheduleIfEnabled());

  // Repositorio de notificaciones in-app
  final notificationRepository = NotificationRepository(apiClient: apiClient);

  // Repositorio del agente tutor de IA (router: nube Gemini + FAQ offline)
  final tutorRepository = TutorRepository(
    apiClient: apiClient,
    connectivity: connectivityService,
    offlineAssistant: OfflineFaqAssistant(),
  );

  authBloc = AuthBloc(
    authRepository: authRepository,
    secureStorage: secureStorage,
  )..add(AuthCheckRequested());

  runApp(
    App(
      authBloc: authBloc,
      authRepository: authRepository,
      appDatabase: appDatabase,
      connectivityService: connectivityService,
      lessonRepository: lessonRepository,
      practiceRepository: practiceRepository,
      socialRepository: socialRepository,
      userRepository: userRepository,
      subscriptionRepository: subscriptionRepository,
      rankingRepository: rankingRepository,
      profileRepository: profileRepository,
      uploadService: uploadService,
      emailVerificationService: emailVerificationService,
      notificationService: notificationService,
      notificationRepository: notificationRepository,
      tutorRepository: tutorRepository,
      onboardingStorage: onboardingStorage,
      prefs: prefs,
    ),
  );
}
