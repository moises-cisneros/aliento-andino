import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile/features/profile/data/repositories/profile_repository.dart';
import 'package:mobile/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:mobile/features/profile/presentation/widgets/breath_profile_card.dart';
import 'package:mobile/features/rankings/data/models/achievement_model.dart';
import 'package:mobile/features/rankings/data/models/user_xp_model.dart';
import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/data/models/user_profile_model.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthBloc extends Mock implements AuthBloc {}

const _mockUser = UserEntity(
  id: 'usr-123',
  email: 'sikuri@example.com',
  username: 'sikuri_andino',
  fullName: 'Sikuri Altiplano',
  avatarUrl: null,
  bio: 'Músico de siku y quena.',
  isActive: true,
  isAdmin: false,
  isVerified: true,
  authProvider: 'local',
  skillLevel: 'intermediate',
  preferredInstruments: ['quena', 'zampona'],
  breathSensitivityRms: 0.0425,
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-11-17T12:00:00Z',
);

const _mockSocialProfile = UserProfileModel(
  id: 'usr-123',
  username: 'sikuri_andino',
  fullName: 'Sikuri Altiplano',
  followersCount: 15,
  followingCount: 8,
  postsCount: 3,
  isFollowedByMe: false,
  createdAt: '2026-01-01T00:00:00Z',
);

const _mockXp = UserXPModel(level: 3, totalXp: 1200, xpForNextLevel: 2000);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProfileRepository mockProfileRepository;
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    mockAuthBloc = MockAuthBloc();

    when(
      () => mockAuthBloc.state,
    ).thenReturn(const AuthAuthenticated(user: _mockUser));
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());

    when(() => mockProfileRepository.getMyProfile()).thenAnswer(
      (_) async => {
        'user': _mockUser,
        'xp_data': _mockXp,
        'recent_achievements': <AchievementModel>[],
      },
    );

    when(
      () => mockProfileRepository.getSocialProfile(any()),
    ).thenAnswer((_) async => _mockSocialProfile);

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

  group('ProfileEditScreen Integration Tests [SUB-19-A]', () {
    testWidgets(
      'Carga datos iniciales en formulario, selector de instrumentos y tarjeta de soplo',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

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

        // Esperar resolución de carga de perfil
        await tester.pumpAndSettle();

        // Verificar que los campos iniciales tienen los datos del usuario
        final nameField = tester.widget<TextFormField>(
          find.byKey(const Key('full_name_field')),
        );
        expect(nameField.controller?.text, 'Sikuri Altiplano');
        final usernameField = tester.widget<TextFormField>(
          find.byKey(const Key('username_field')),
        );
        expect(usernameField.controller?.text, 'sikuri_andino');
        final bioField = tester.widget<TextFormField>(
          find.byKey(const Key('bio_field')),
        );
        expect(bioField.controller?.text, 'Músico de siku y quena.');

        // Verificar tarjeta de calibración de soplo
        expect(find.byType(BreathProfileCard), findsOneWidget);
        expect(find.text('0.0425 RMS'), findsOneWidget);

        // Verificar instrumentos andinos
        expect(find.text('Quena'), findsOneWidget);
        expect(find.text('Zampoña'), findsOneWidget);
        expect(find.text('Tarka'), findsOneWidget);
      },
    );

    testWidgets(
      'Modificar campos y guardar interactúa con ProfileBloc y Repository',
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
            username: any(named: 'username'),
            bio: any(named: 'bio'),
            avatarUrl: any(named: 'avatarUrl'),
            preferredInstruments: any(named: 'preferredInstruments'),
            breathSensitivityRms: any(named: 'breathSensitivityRms'),
          ),
        ).thenAnswer((_) async => _mockUser);

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

        // Activar Tarka como instrumento preferido
        final tarkaTile = find.byKey(const Key('instrument_tile_tarka'));
        await tester.ensureVisible(tarkaTile);
        await tester.tap(tarkaTile);
        await tester.pumpAndSettle();

        // Guardar cambios con el botón superior
        final saveButton = find.byKey(const Key('save_profile_button'));
        await tester.tap(saveButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockProfileRepository.updateProfile(
            fullName: 'Sikuri Altiplano',
            username: 'sikuri_andino',
            bio: 'Músico de siku y quena.',
            avatarUrl: null,
            preferredInstruments: any(
              named: 'preferredInstruments',
              that: contains('tarka'),
            ),
            breathSensitivityRms: 0.0425,
          ),
        ).called(1);
      },
    );
  });
}
