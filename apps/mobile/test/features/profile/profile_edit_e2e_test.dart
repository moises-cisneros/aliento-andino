import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile/features/profile/data/repositories/profile_repository.dart';
import 'package:mobile/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:mobile/features/rankings/data/models/achievement_model.dart';
import 'package:mobile/features/rankings/data/models/user_xp_model.dart';
import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/data/models/user_profile_model.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthBloc extends Mock implements AuthBloc {}

const _initialUser = UserEntity(
  id: 'usr-456',
  email: 'musico@aliento.com',
  username: 'apodo_antiguo',
  fullName: 'Nombre Antiguo',
  avatarUrl: null,
  bio: 'Estudiante de quena',
  isActive: true,
  isAdmin: false,
  isVerified: true,
  authProvider: 'local',
  preferredInstruments: ['quena'],
  breathSensitivityRms: 0.0350,
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-11-17T00:00:00Z',
);

const _updatedUser = UserEntity(
  id: 'usr-456',
  email: 'musico@aliento.com',
  username: 'nuevo_apodo_andino',
  fullName: 'Nombre Actualizado',
  avatarUrl: null,
  bio: 'Estudiante de quena',
  isActive: true,
  isAdmin: false,
  isVerified: true,
  authProvider: 'local',
  preferredInstruments: ['quena', 'tarka'],
  breathSensitivityRms: 0.0350,
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-11-17T01:00:00Z',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProfileRepository mockProfileRepository;
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    mockAuthBloc = MockAuthBloc();

    when(
      () => mockAuthBloc.state,
    ).thenReturn(const AuthAuthenticated(user: _initialUser));
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());

    when(() => mockProfileRepository.getMyProfile()).thenAnswer(
      (_) async => {
        'user': _initialUser,
        'xp_data': const UserXPModel(
          level: 1,
          totalXp: 100,
          xpForNextLevel: 500,
        ),
        'recent_achievements': <AchievementModel>[],
      },
    );

    when(() => mockProfileRepository.getSocialProfile(any())).thenAnswer(
      (_) async => const UserProfileModel(
        id: 'usr-456',
        username: 'apodo_antiguo',
        fullName: 'Nombre Antiguo',
        followersCount: 10,
        followingCount: 5,
        postsCount: 2,
        isFollowedByMe: false,
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );

    when(
      () =>
          mockProfileRepository.getMyPosts(any(), cursor: any(named: 'cursor')),
    ).thenAnswer(
      (_) async => {
        'items': <PostModel>[],
        'next_cursor': null,
        'has_more': false,
      },
    );
  });

  group('ProfileEdit E2E Flow [SUB-19-A]', () {
    testWidgets(
      'Edición de apodo y verificación de actualización inmediata en UI',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        when(
          () => mockProfileRepository.updateProfile(
            fullName: any(named: 'fullName'),
            username: 'nuevo_apodo_andino',
            bio: any(named: 'bio'),
            avatarUrl: any(named: 'avatarUrl'),
            preferredInstruments: any(named: 'preferredInstruments'),
            breathSensitivityRms: any(named: 'breathSensitivityRms'),
          ),
        ).thenAnswer((_) async => _updatedUser);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiRepositoryProvider(
              providers: [
                RepositoryProvider<ProfileRepository>.value(
                  value: mockProfileRepository,
                ),
              ],
              child: MultiBlocProvider(
                providers: [BlocProvider<AuthBloc>.value(value: mockAuthBloc)],
                child: const ProfileEditScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verificar que el apodo inicial es visible
        final usernameFinder = find.byKey(const Key('username_field'));
        expect(usernameFinder, findsOneWidget);

        // Editar el apodo (username)
        await tester.enterText(usernameFinder, 'nuevo_apodo_andino');
        await tester.pumpAndSettle();

        // Verificar actualización inmediata en el controller del widget
        final usernameField = tester.widget<TextFormField>(usernameFinder);
        expect(usernameField.controller?.text, 'nuevo_apodo_andino');

        // Guardar con el botón superior o botón principal
        final saveButtonFinder = find.byKey(const Key('save_profile_button'));
        await tester.tap(saveButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verificar que el repositorio fue invocado con el nuevo apodo
        verify(
          () => mockProfileRepository.updateProfile(
            fullName: 'Nombre Antiguo',
            username: 'nuevo_apodo_andino',
            bio: 'Estudiante de quena',
            avatarUrl: null,
            preferredInstruments: any(named: 'preferredInstruments'),
            breathSensitivityRms: 0.0350,
          ),
        ).called(1);

        // Verificar que se emite confirmación visual (SnackBar)
        expect(find.text('Perfil y preferencias actualizados'), findsOneWidget);
      },
    );
  });
}
