import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/connectivity/connectivity_service.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile/features/instrument_select/bloc/active_instrument_bloc.dart';
import 'package:mobile/features/lessons/data/repositories/practice_repository.dart';
import 'package:mobile/features/profile/data/repositories/profile_repository.dart';
import 'package:mobile/features/profile/presentation/screens/my_profile_screen.dart';
import 'package:mobile/features/profile/presentation/screens/practice_history_screen.dart';
import 'package:mobile/features/rankings/data/models/achievement_model.dart';
import 'package:mobile/features/rankings/data/models/user_xp_model.dart';
import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/data/models/user_profile_model.dart';
import 'package:mocktail/mocktail.dart';

import 'practice_history_test_helpers.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockPracticeRepository extends Mock implements PracticeRepository {}

class MockAuthBloc extends Mock implements AuthBloc {}

class MockActiveInstrumentBloc extends Mock implements ActiveInstrumentBloc {}

class _OnlineConnectivity extends Fake implements ConnectivityService {
  @override
  Stream<bool> get statusStream => Stream<bool>.value(true);
}

const _user = UserEntity(
  id: 'usr-456',
  email: 'musico@aliento.com',
  username: 'apodo',
  fullName: 'Nombre',
  avatarUrl: null,
  bio: null,
  isActive: true,
  isAdmin: false,
  isVerified: true,
  authProvider: 'local',
  preferredInstruments: ['quena'],
  breathSensitivityRms: 0.0350,
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-11-17T00:00:00Z',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProfileRepository profileRepo;
  late MockPracticeRepository practiceRepo;
  late MockAuthBloc authBloc;
  late MockActiveInstrumentBloc instrumentBloc;

  setUp(() {
    profileRepo = MockProfileRepository();
    practiceRepo = MockPracticeRepository();
    authBloc = MockAuthBloc();
    instrumentBloc = MockActiveInstrumentBloc();

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(user: _user));
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => instrumentBloc.state,
    ).thenReturn(const ActiveInstrumentState(InstrumentType.quena));
    when(() => instrumentBloc.stream).thenAnswer((_) => const Stream.empty());

    when(() => profileRepo.getMyProfile()).thenAnswer(
      (_) async => {
        'user': _user,
        'xp_data': const UserXPModel(
          level: 1,
          totalXp: 100,
          xpForNextLevel: 500,
        ),
        'recent_achievements': <AchievementModel>[],
      },
    );
    when(() => profileRepo.getSocialProfile(any())).thenAnswer(
      (_) async => const UserProfileModel(
        id: 'usr-456',
        username: 'apodo',
        fullName: 'Nombre',
        followersCount: 0,
        followingCount: 0,
        postsCount: 0,
        isFollowedByMe: false,
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );
    when(
      () => profileRepo.getMyPosts(any(), cursor: any(named: 'cursor')),
    ).thenAnswer(
      (_) async => {
        'items': <PostModel>[],
        'next_cursor': null,
        'has_more': false,
      },
    );
    when(
      () => practiceRepo.getPracticeHistory(
        page: 1,
        size: 20,
        offlineFallback: false,
      ),
    ).thenAnswer(
      (_) async => historyPage([
        historySession('a', score: 88, title: 'Sikuri Inicial'),
        historySession(
          'b',
          score: 64,
          createdAt: '2026-11-02T10:00:00Z',
          title: 'Escala de Sol',
        ),
      ]),
    );
  });

  testWidgets(
    'E2E: del perfil al historial historico de practicas [SUB-10-A]',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const MyProfileScreen()),
          GoRoute(
            path: '/practice-history',
            builder: (_, _) => const PracticeHistoryScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ProfileRepository>.value(value: profileRepo),
            RepositoryProvider<PracticeRepository>.value(value: practiceRepo),
            RepositoryProvider<ConnectivityService>.value(
              value: _OnlineConnectivity(),
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<ActiveInstrumentBloc>.value(value: instrumentBloc),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final entry = find.byKey(const Key('profile_practice_history'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.text('Historial de prácticas'), findsWidgets);
      expect(find.text('Sikuri Inicial'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('Escala de Sol'), findsOneWidget);
      expect(find.byKey(const Key('accuracy_chart_canvas')), findsOneWidget);
    },
  );
}
