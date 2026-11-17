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
import 'package:mobile/features/profile/data/models/achievement_model.dart'
    as showcase;
import 'package:mobile/features/profile/data/repositories/profile_repository.dart';
import 'package:mobile/features/profile/presentation/screens/achievements_screen.dart'
    as showcase_screen;
import 'package:mobile/features/profile/presentation/screens/my_profile_screen.dart';
import 'package:mobile/features/profile/presentation/widgets/badge_item_widget.dart';
import 'package:mobile/features/rankings/data/models/achievement_model.dart'
    as ranking;
import 'package:mobile/features/rankings/data/models/user_xp_model.dart';
import 'package:mobile/features/rankings/data/repositories/ranking_repository.dart';
import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/data/models/user_profile_model.dart';
import 'package:mocktail/mocktail.dart';

class MockRankingRepository extends Mock implements RankingRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockPracticeRepository extends Mock implements PracticeRepository {}

class MockAuthBloc extends Mock implements AuthBloc {}

class MockActiveInstrumentBloc extends Mock implements ActiveInstrumentBloc {}

class _OnlineConnectivity extends Fake implements ConnectivityService {
  @override
  Stream<bool> get statusStream => Stream<bool>.value(true);
}

ranking.AchievementModel _api({
  required String code,
  required String name,
  bool unlocked = false,
  String? unlockedAt,
}) => ranking.AchievementModel(
  id: 'id-$code',
  code: code,
  name: name,
  description: 'Descripción de $name',
  icon: 'music_note',
  category: 'andean',
  requirementType: 'andean',
  requirementValue: 1,
  isUnlocked: unlocked,
  unlockedAt: unlockedAt,
);

final _catalog = [
  _api(
    code: 'andean_first_clean_breath',
    name: 'Primer Soplo Limpio',
    unlocked: true,
    unlockedAt: '2026-11-02T10:30:00Z',
  ),
  _api(code: 'andean_siku_master', name: 'Maestro del Siku'),
  _api(code: 'andean_air_control_30s', name: 'Control de Aire 30s'),
  _api(code: 'andean_pentatonic_scale', name: 'Escala Pentatónica Completa'),
];

const _user = UserEntity(
  id: 'usr-1',
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

  group('AchievementModel (vitrina) mapping', () {
    test('maps an unlocked badge with its obtained date', () {
      final m = showcase.AchievementModel.fromRanking(_catalog.first);
      expect(m.id, 'id-andean_first_clean_breath');
      expect(m.title, 'Primer Soplo Limpio');
      expect(m.description, 'Descripción de Primer Soplo Limpio');
      expect(m.iconAsset, 'assets/badges/andean_first_clean_breath.png');
      expect(m.isUnlocked, isTrue);
      expect(m.unlockedAt, DateTime.parse('2026-11-02T10:30:00Z'));
    });

    test('maps a locked badge without date', () {
      final m = showcase.AchievementModel.fromRanking(_catalog[1]);
      expect(m.isUnlocked, isFalse);
      expect(m.unlockedAt, isNull);
    });

    test('an invalid date degrades to null instead of throwing', () {
      final m = showcase.AchievementModel.fromRanking(
        _api(code: 'x', name: 'X', unlocked: true, unlockedAt: 'no-date'),
      );
      expect(m.unlockedAt, isNull);
    });

    test('unlockedOnly keeps only unlocked badges', () {
      final unlocked = showcase.AchievementModel.unlockedOnly(
        _catalog.map(showcase.AchievementModel.fromRanking).toList(),
      );
      expect(unlocked.map((a) => a.title), ['Primer Soplo Limpio']);
    });
  });

  group('BadgeItemWidget', () {
    Widget host(showcase.AchievementModel a) => MaterialApp(
      home: Scaffold(body: BadgeItemWidget(achievement: a)),
    );

    testWidgets('unlocked shows title and obtained date', (tester) async {
      await tester.pumpWidget(
        host(showcase.AchievementModel.fromRanking(_catalog.first)),
      );
      expect(find.text('Primer Soplo Limpio'), findsOneWidget);
      expect(find.text('Obtenida el 02/11/2026'), findsOneWidget);
      expect(find.byKey(const Key('badge_locked_icon')), findsNothing);
    });

    testWidgets('locked shows lock state and no date', (tester) async {
      await tester.pumpWidget(
        host(showcase.AchievementModel.fromRanking(_catalog[1])),
      );
      expect(find.text('Maestro del Siku'), findsOneWidget);
      expect(find.text('Bloqueada'), findsOneWidget);
      expect(find.byKey(const Key('badge_locked_icon')), findsOneWidget);
    });

    testWidgets('missing icon asset falls back to the generic Andean medal', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(showcase.AchievementModel.fromRanking(_catalog.first)),
      );
      await tester.pump();
      expect(find.byKey(const Key('badge_fallback_medal')), findsOneWidget);
    });
  });

  group('AchievementsScreen (vitrina)', () {
    Widget screen(MockRankingRepository repo) =>
        RepositoryProvider<RankingRepository>.value(
          value: repo,
          child: const MaterialApp(home: showcase_screen.AchievementsScreen()),
        );

    testWidgets('lists the four Andean badges with counter', (tester) async {
      final repo = MockRankingRepository();
      when(() => repo.getAllAchievements()).thenAnswer(
        (_) async => {
          'achievements': _catalog,
          'total_unlocked': 1,
          'total_available': 4,
        },
      );
      await tester.pumpWidget(screen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Primer Soplo Limpio'), findsOneWidget);
      expect(find.text('Maestro del Siku'), findsOneWidget);
      expect(find.text('Control de Aire 30s'), findsOneWidget);
      expect(find.text('Escala Pentatónica Completa'), findsOneWidget);
      expect(find.text('1/4 insignias desbloqueadas'), findsOneWidget);
    });

    testWidgets('shows an error message when loading fails', (tester) async {
      final repo = MockRankingRepository();
      when(() => repo.getAllAchievements()).thenThrow(Exception('sin red'));
      await tester.pumpWidget(screen(repo));
      await tester.pumpAndSettle();
      expect(find.text('Error al cargar logros'), findsOneWidget);
    });
  });

  testWidgets('E2E: del perfil a la vitrina de insignias [SUB-13-B]', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final profileRepo = MockProfileRepository();
    final practiceRepo = MockPracticeRepository();
    final rankingRepo = MockRankingRepository();
    final authBloc = MockAuthBloc();
    final instrumentBloc = MockActiveInstrumentBloc();
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
        'recent_achievements': <ranking.AchievementModel>[],
      },
    );
    when(() => profileRepo.getSocialProfile(any())).thenAnswer(
      (_) async => const UserProfileModel(
        id: 'usr-1',
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
    when(() => rankingRepo.getAllAchievements()).thenAnswer(
      (_) async => {
        'achievements': _catalog,
        'total_unlocked': 1,
        'total_available': 4,
      },
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MyProfileScreen()),
        GoRoute(
          path: '/profile/achievements',
          builder: (_, _) => const showcase_screen.AchievementsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ProfileRepository>.value(value: profileRepo),
          RepositoryProvider<PracticeRepository>.value(value: practiceRepo),
          RepositoryProvider<RankingRepository>.value(value: rankingRepo),
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

    final entry = find.byKey(const Key('profile_achievements'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Primer Soplo Limpio'), findsOneWidget);
    expect(find.text('Obtenida el 02/11/2026'), findsOneWidget);
    expect(find.text('Maestro del Siku'), findsOneWidget);
  });
}
