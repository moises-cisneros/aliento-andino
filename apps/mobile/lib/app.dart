import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/connectivity/connectivity_service.dart';
import 'core/database/app_database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/instrument_select/bloc/active_instrument_bloc.dart';
import 'features/lessons/data/repositories/lesson_repository.dart';
import 'features/lessons/data/repositories/practice_repository.dart';
import 'features/lessons/presentation/bloc/lessons/lessons_bloc.dart';
import 'features/lessons/presentation/bloc/progress/progress_bloc.dart';
import 'core/network/upload_service.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/data/services/email_verification_service.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/notifications/data/notification_repository.dart';
import 'features/onboarding/data/onboarding_storage.dart';
import 'features/profile/data/repositories/profile_repository.dart';
import 'features/rankings/data/repositories/ranking_repository.dart';
import 'features/social/data/repositories/social_repository.dart';
import 'features/social/data/repositories/user_repository.dart';
import 'features/subscription/data/repositories/subscription_repository.dart';
import 'features/tutor/data/tutor_repository.dart';

/// Widget raíz de la aplicación Aliento Andino.
class App extends StatelessWidget {
  final AuthBloc authBloc;
  final AuthRepository authRepository;
  final AppDatabase appDatabase;
  final ConnectivityService connectivityService;
  final LessonRepository lessonRepository;
  final PracticeRepository practiceRepository;
  final SocialRepository socialRepository;
  final UserRepository userRepository;
  final SubscriptionRepository subscriptionRepository;
  final RankingRepository rankingRepository;
  final ProfileRepository profileRepository;
  final UploadService uploadService;
  final EmailVerificationService emailVerificationService;
  final NotificationService notificationService;
  final NotificationRepository notificationRepository;
  final TutorRepository tutorRepository;
  final OnboardingStorage onboardingStorage;
  final SharedPreferences prefs;

  const App({
    super.key,
    required this.authBloc,
    required this.authRepository,
    required this.appDatabase,
    required this.connectivityService,
    required this.lessonRepository,
    required this.practiceRepository,
    required this.socialRepository,
    required this.userRepository,
    required this.subscriptionRepository,
    required this.rankingRepository,
    required this.profileRepository,
    required this.uploadService,
    required this.emailVerificationService,
    required this.notificationService,
    required this.notificationRepository,
    required this.tutorRepository,
    required this.onboardingStorage,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter(
      authBloc: authBloc,
      onboardingStorage: onboardingStorage,
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: appDatabase),
        RepositoryProvider.value(value: connectivityService),
        RepositoryProvider.value(value: lessonRepository),
        RepositoryProvider.value(value: practiceRepository),
        RepositoryProvider.value(value: socialRepository),
        RepositoryProvider.value(value: userRepository),
        RepositoryProvider.value(value: subscriptionRepository),
        RepositoryProvider.value(value: rankingRepository),
        RepositoryProvider.value(value: profileRepository),
        RepositoryProvider.value(value: uploadService),
        RepositoryProvider.value(value: emailVerificationService),
        RepositoryProvider.value(value: notificationService),
        RepositoryProvider.value(value: notificationRepository),
        RepositoryProvider.value(value: tutorRepository),
        RepositoryProvider.value(value: onboardingStorage),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit(prefs)),
          BlocProvider(create: (_) => ActiveInstrumentBloc(prefs: prefs)),
          BlocProvider.value(value: authBloc),
          BlocProvider(
            create: (_) => LessonsBloc(lessonRepository: lessonRepository),
          ),
          BlocProvider(
            create: (_) => ProgressBloc(practiceRepository: practiceRepository),
          ),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          // Sincronizar token FCM con backend al autenticarse / desautenticarse
          listenWhen: (prev, curr) =>
              prev.runtimeType != curr.runtimeType &&
              (curr is AuthAuthenticated ||
                  curr is AuthRegistered ||
                  curr is AuthUnauthenticated),
          listener: (context, state) {
            if (state is AuthAuthenticated || state is AuthRegistered) {
              notificationService.initialize();
            } else if (state is AuthUnauthenticated) {
              notificationService.unregister();
            }
          },
          child: BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, themeState) {
              return MaterialApp.router(
                title: 'Aliento Andino',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeState.themeMode,
                routerConfig: appRouter.router,
              );
            },
          ),
        ),
      ),
    );
  }
}
