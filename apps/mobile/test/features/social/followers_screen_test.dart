import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile/features/social/data/models/user_summary_model.dart';
import 'package:mobile/features/social/data/repositories/user_repository.dart';
import 'package:mobile/features/social/presentation/screens/followers_screen.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

const _me = UserEntity(
  id: 'me',
  email: 'me@example.com',
  username: 'me',
  fullName: 'Me',
  isActive: true,
  isAdmin: false,
  isVerified: true,
  authProvider: 'local',
  notificationsPushEnabled: true,
  notificationsEmailEnabled: true,
  createdAt: '2026-01-01T00:00:00Z',
);

void main() {
  // Reproduce el ancho del emulador donde fallaba la aserción del ListTile.
  testWidgets('FollowersScreen renderiza la lista a 440px sin crashear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440 * 3, 914 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repo = MockUserRepository();
    final users = List.generate(
      8,
      (i) => UserSummaryModel(
        id: '$i',
        username: 'usuario_largo_$i',
        fullName: 'Nombre Bastante Largo $i',
        isFollowedByMe: i.isEven,
      ),
    );
    when(
      () => repo.getFollowers(any()),
    ).thenAnswer((_) async => {'items': users});
    when(
      () => repo.getFollowing(any()),
    ).thenAnswer((_) async => {'items': users});

    final authBloc = MockAuthBloc();
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(user: _me));

    await tester.pumpWidget(
      MaterialApp(
        // Tema REAL: fuerza minimumSize de botones a ancho completo, que es lo
        // que disparaba el crash. Sin esto el test no reproduce el bug.
        theme: AppTheme.lightTheme,
        home: MultiRepositoryProvider(
          providers: [RepositoryProvider<UserRepository>.value(value: repo)],
          child: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const FollowersScreen(userId: 'x'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Nombre Bastante Largo 0'), findsOneWidget);
  });
}
