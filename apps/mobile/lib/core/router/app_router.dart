import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../router/splash_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/onboarding/data/onboarding_storage.dart';
import '../../features/onboarding/presentation/screens/assessment_result_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/skill_assessment_screen.dart';
import '../../features/lessons/data/repositories/lesson_repository.dart';
import '../../features/lessons/presentation/bloc/lesson_detail/lesson_detail_bloc.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/lessons/presentation/screens/ear_training_screen.dart';
import '../../features/lessons/presentation/screens/lesson_detail_screen.dart';
import '../../features/lessons/presentation/screens/lesson_list_screen.dart';
import '../../features/lessons/presentation/screens/lesson_player_screen.dart';
import '../../features/lessons/presentation/screens/offline_lessons_screen.dart';
import '../../features/lessons/presentation/screens/sight_reading_screen.dart';
import '../../features/lessons/presentation/screens/theory_hub_screen.dart';
import '../../features/lessons/presentation/screens/theory_quiz_screen.dart';
import '../../features/lessons/presentation/screens/lessons_home_screen.dart';
import '../../features/lessons/presentation/screens/practice_result_screen.dart';
import '../../features/lessons/presentation/screens/practice_screen.dart';
import '../../features/lessons/presentation/screens/progress_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/my_profile_screen.dart';
import '../../features/profile/presentation/screens/practice_history_screen.dart';
import '../../features/profile/presentation/screens/privacy_policy_screen.dart';
import '../../features/profile/presentation/screens/recordings_list_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/terms_screen.dart';
import '../../features/profile/presentation/screens/achievements_screen.dart'
    as profile_achievements;
import '../../features/instrument_select/bloc/active_instrument_bloc.dart';
import '../../features/rankings/presentation/screens/achievements_screen.dart';
import '../../features/rankings/presentation/screens/leaderboard_screen.dart';
import '../../features/rankings/presentation/screens/lesson_ranking_screen.dart';
import '../../features/rankings/presentation/screens/my_xp_screen.dart';
import '../../features/rankings/presentation/screens/rankings_screen.dart';
import '../../features/social/presentation/screens/create_post_screen.dart';
import '../../features/social/presentation/screens/explore_screen.dart';
import '../../features/social/presentation/screens/social_feed_screen.dart';
import '../../features/social/presentation/screens/followers_screen.dart';
import '../../features/social/presentation/screens/hashtag_feed_screen.dart';
import '../../features/social/presentation/screens/mention_resolver_screen.dart';
import '../../features/social/presentation/screens/post_detail_screen.dart';
import '../../features/social/presentation/screens/saved_posts_screen.dart';
import '../../features/social/presentation/screens/user_profile_screen.dart';
import '../../features/social/presentation/screens/user_search_screen.dart';
import '../../features/subscription/presentation/screens/paywall_screen.dart';
import '../../features/subscription/presentation/screens/payment_screen.dart';
import '../../features/tutor/presentation/tutor_button.dart';

/// Navigator raíz global. Permite navegar desde fuera del árbol de widgets,
/// por ejemplo al tocar una notificación push (FCM) cuando la app vuelve del
/// background o se abre desde estado terminado.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Shell con Bottom Navigation Bar.
class _ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  const _ScaffoldWithNavBar({required this.child});

  static int _indexFromLocation(String location) {
    if (location.startsWith('/social')) return 0;
    if (location.startsWith('/lessons')) return 1;
    if (location.startsWith('/rankings')) return 2;
    if (location.startsWith('/progress')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFromLocation(location);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          // Botón del tutor IA, flotando a la izquierda para no chocar con los
          // FAB de pantalla (ej. crear publicación, a la derecha).
          const Positioned(left: 16, bottom: 16, child: TutorButton()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        indicatorColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.2),
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/social');
              break;
            case 1:
              context.go('/lessons');
              break;
            case 2:
              context.go('/rankings');
              break;
            case 3:
              context.go('/progress');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        // No usar GlobalKeys en los iconos: NavigationBar reconstruye cada icono
        // en varios estados durante la animación de selección y duplicaría la
        // key (corrompe el árbol). El tutor navega con navigate_to en su lugar.
        destinations: const [
          NavigationDestination(icon: Icon(Icons.feed), label: 'Social'),
          NavigationDestination(
            icon: Icon(Icons.music_note),
            label: 'Lecciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard),
            label: 'Rankings',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Progreso'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

/// Configuración del router principal de la app.
class AppRouter {
  final AuthBloc authBloc;
  final OnboardingStorage onboardingStorage;

  AppRouter({required this.authBloc, required this.onboardingStorage});

  late final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _AuthBlocListenable(authBloc),
    redirect: _redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/skill-assessment',
        builder: (context, state) {
          final isRetake = state.uri.queryParameters['retake'] == '1';
          return SkillAssessmentScreen(isRetake: isRetake);
        },
      ),
      GoRoute(
        path: '/assessment-result',
        builder: (context, state) {
          final level = state.uri.queryParameters['level'] ?? 'beginner';
          final isRetake = state.uri.queryParameters['retake'] == '1';
          return AssessmentResultScreen(level: level, isRetake: isRetake);
        },
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return ResetPasswordScreen(token: token);
        },
      ),
      // Shell con bottomNav para tabs principales
      ShellRoute(
        builder: (context, state, child) => _ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const MyProfileScreen(),
          ),
          GoRoute(
            path: '/social',
            builder: (context, state) => const SocialFeedScreen(),
          ),
          GoRoute(
            path: '/lessons',
            builder: (context, state) => const LessonsHomeScreen(),
          ),
          GoRoute(
            path: '/rankings',
            builder: (context, state) => const RankingsScreen(),
          ),
          GoRoute(
            path: '/progress',
            builder: (context, state) => const ProgressScreen(),
          ),
        ],
      ),
      // Pantalla de notificaciones (campanita)
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Rutas de perfil fuera del shell (sin bottomNav)
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/practice-history',
        builder: (context, state) => const PracticeHistoryScreen(),
      ),
      GoRoute(
        path: '/recordings',
        builder: (context, state) => const RecordingsListScreen(),
      ),
      GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      // Rutas de rankings fuera del shell (sin bottomNav)
      GoRoute(path: '/my-xp', builder: (context, state) => const MyXPScreen()),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => LeaderboardScreen(
          initialInstrument: context
              .read<ActiveInstrumentBloc>()
              .state
              .activeInstrument,
        ),
      ),
      GoRoute(
        path: '/profile/achievements',
        builder: (context, state) =>
            const profile_achievements.AchievementsScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/offline-lessons',
        builder: (context, state) => const OfflineLessonsScreen(),
      ),
      GoRoute(
        path: '/lessons/:id/ranking',
        builder: (context, state) {
          final lessonId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? '';
          return LessonRankingScreen(lessonId: lessonId, lessonTitle: title);
        },
      ),
      // Rutas sociales fuera del shell (sin bottomNav)
      GoRoute(
        path: '/social/explore',
        builder: (context, state) => const ExploreScreen(),
      ),
      GoRoute(
        path: '/social/create-post',
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/social/search',
        builder: (context, state) => const UserSearchScreen(),
      ),
      GoRoute(
        path: '/social/saved',
        builder: (context, state) => const SavedPostsScreen(),
      ),
      GoRoute(
        path: '/social/post/:id',
        builder: (context, state) {
          final postId = state.pathParameters['id']!;
          return PostDetailScreen(postId: postId);
        },
      ),
      GoRoute(
        path: '/social/user/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return UserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/social/user/:id/followers',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return FollowersScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/social/hashtag/:tag',
        builder: (context, state) =>
            HashtagFeedScreen(tag: state.pathParameters['tag']!),
      ),
      GoRoute(
        path: '/social/u/:username',
        builder: (context, state) =>
            MentionResolverScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/subscription/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/subscription/payment',
        builder: (context, state) => PaymentScreen(
          planId: state.uri.queryParameters['plan'] ?? 'monthly',
        ),
      ),
      GoRoute(
        path: '/lesson-catalog',
        builder: (context, state) => const LessonListScreen(),
      ),
      GoRoute(
        path: '/lesson-player/:id',
        builder: (context, state) {
          final lessonId = state.pathParameters['id']!;
          return LessonPlayerScreen(lessonId: lessonId);
        },
      ),
      GoRoute(
        path: '/lessons/:id',
        builder: (context, state) {
          final lessonId = state.pathParameters['id']!;
          return BlocProvider(
            create: (ctx) => LessonDetailBloc(
              lessonRepository: ctx.read<LessonRepository>(),
            ),
            child: LessonDetailScreen(lessonId: lessonId),
          );
        },
      ),
      GoRoute(
        path: '/ear-training',
        builder: (context, state) => const EarTrainingScreen(),
      ),
      GoRoute(
        path: '/theory',
        builder: (context, state) => const TheoryHubScreen(),
      ),
      GoRoute(
        path: '/theory/sight-reading',
        builder: (context, state) => const SightReadingScreen(),
      ),
      GoRoute(
        path: '/theory/quiz',
        builder: (context, state) => const TheoryQuizScreen(),
      ),
      GoRoute(
        path: '/practice/:lessonId',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return PracticeScreen(lessonId: lessonId);
        },
      ),
      GoRoute(
        path: '/practice/:lessonId/result',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          final resultData =
              state.extra as Map<String, dynamic>? ?? <String, dynamic>{};
          return PracticeResultScreen(
            lessonId: lessonId,
            resultData: resultData,
          );
        },
      ),
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final authState = authBloc.state;
    final isAuth =
        authState is AuthAuthenticated ||
        authState is AuthRegistered ||
        authState is AuthProfileUpdated;
    final isLoading = authState is AuthInitial || authState is AuthLoading;
    final onboardingDone = onboardingStorage.isCompleted;

    final loc = state.matchedLocation;
    final isOnSplash = loc == '/splash';
    final isOnLoginOrRegister = loc == '/login' || loc == '/register';
    final isOnOnboardingFlow =
        loc == '/onboarding' ||
        loc == '/skill-assessment' ||
        loc == '/assessment-result';

    // Rutas públicas (no requieren auth)
    final isPublicRoute = loc == '/forgot-password' || loc == '/reset-password';

    // Mientras se verifica la sesión, mantener en splash
    if (isLoading && isOnSplash) return null;

    // Si ya está autenticado, mandar al feed desde splash/login/onboarding
    // inicial. OJO: /skill-assessment y /assessment-result NO se redirigen acá
    // porque son el flujo de "retomar evaluación" (Configuración → Mi nivel) de
    // un usuario logueado; redirigirlos rompía con un page-key duplicado al
    // chocar /social (ya en la pila) durante el push.
    if (isAuth && (isOnSplash || isOnLoginOrRegister || loc == '/onboarding')) {
      return '/social';
    }

    // No autenticado y onboarding pendiente → mostrar onboarding
    if (!isAuth && !isLoading && !onboardingDone) {
      if (isOnOnboardingFlow) return null; // dejar navegar dentro del flow
      return '/onboarding';
    }

    // Onboarding hecho pero no autenticado: en splash → login
    if (!isAuth && !isLoading && isOnSplash) {
      return '/login';
    }

    // No autenticado y ya pasó onboarding: solo se permite login/register/público
    if (!isAuth &&
        !isLoading &&
        !isOnLoginOrRegister &&
        !isPublicRoute &&
        !isOnOnboardingFlow) {
      return '/login';
    }

    return null;
  }
}

/// Convierte AuthBloc en un ChangeNotifier para GoRouter.refreshListenable.
class _AuthBlocListenable extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  _AuthBlocListenable(AuthBloc bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
