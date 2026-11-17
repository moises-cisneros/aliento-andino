import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _user() => {
  'id': 'u1',
  'email': 'ana@test.dev',
  'username': 'ana',
  'full_name': 'Ana Quena',
  'created_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> _auth() => {
  'access_token': 'acc',
  'refresh_token': 'ref',
  'user': _user(),
};

void main() {
  late FakeAdapter adapter;
  late AuthRemoteDatasource datasource;
  late AuthRepository repo;

  setUp(() {
    adapter = FakeAdapter();
    datasource = AuthRemoteDatasource(apiClient: fakeApiClient(adapter));
    repo = AuthRepository(remoteDatasource: datasource);
  });

  group('AuthRemoteDatasource', () {
    test('login posts credentials and parses tokens and user', () async {
      adapter.on('POST /auth/login', _auth());

      final response = await datasource.login('ana@test.dev', 'secret');

      expect(adapter.last.data, {
        'email': 'ana@test.dev',
        'password': 'secret',
      });
      expect(response.accessToken, 'acc');
      expect(response.refreshToken, 'ref');
      expect(response.tokenType, 'bearer');
      expect(response.user.username, 'ana');
    });

    test('register sends skill_level only when provided', () async {
      adapter.on('POST /auth/register', _auth());

      await datasource.register('a@b.c', 'ana', 'Ana', 'pw', 'pw');
      expect(adapter.last.data.containsKey('skill_level'), isFalse);

      await datasource.register(
        'a@b.c',
        'ana',
        'Ana',
        'pw',
        'pw',
        skillLevel: 'beginner',
      );
      expect(adapter.last.data['skill_level'], 'beginner');
      expect(adapter.last.data['password_confirm'], 'pw');
    });

    test('googleSignIn sends the Google token', () async {
      adapter.on('POST /auth/google', _auth());

      await datasource.googleSignIn('gtoken');

      expect(adapter.last.data, {'google_token': 'gtoken'});
    });

    test('getCurrentUser and updateProfile parse the user', () async {
      adapter
        ..on('GET /auth/me', _user())
        ..on('PUT /auth/me', {..._user(), 'bio': 'nueva'});

      expect((await datasource.getCurrentUser()).email, 'ana@test.dev');

      final updated = await datasource.updateProfile(
        fullName: 'Ana M.',
        username: 'ana',
        bio: 'nueva',
        avatarUrl: 'http://a/x.png',
        skillLevel: 'advanced',
        notificationsPushEnabled: false,
        notificationsEmailEnabled: true,
      );
      expect(updated.bio, 'nueva');
      expect(adapter.last.data, {
        'full_name': 'Ana M.',
        'username': 'ana',
        'bio': 'nueva',
        'avatar_url': 'http://a/x.png',
        'skill_level': 'advanced',
        'notifications_push_enabled': false,
        'notifications_email_enabled': true,
      });

      await datasource.updateProfile(bio: 'solo');
      expect(adapter.last.data, {'bio': 'solo'});
    });

    test('refreshToken returns both rotated tokens', () async {
      adapter.on('POST /auth/refresh', {
        'access_token': 'a2',
        'refresh_token': 'r2',
      });

      expect(await datasource.refreshToken('r1'), ('a2', 'r2'));
      expect(adapter.last.data, {'refresh_token': 'r1'});
    });

    test('password and account operations hit their endpoints', () async {
      adapter
        ..on('PUT /auth/change-password', {'message': 'ok'})
        ..on('DELETE /auth/me', {'message': 'ok'})
        ..on('POST /auth/forgot-password', {'message': 'ok'})
        ..on('POST /auth/reset-password', _auth());

      await datasource.changePassword('old', 'new');
      expect(adapter.last.data, {
        'current_password': 'old',
        'new_password': 'new',
      });

      await datasource.deleteAccount();
      expect(adapter.last.data, <String, dynamic>{});
      await datasource.deleteAccount(password: 'pw');
      expect(adapter.last.data, {'password': 'pw'});

      await datasource.forgotPassword('ana@test.dev');
      expect(adapter.last.data, {'email': 'ana@test.dev'});

      final reset = await datasource.resetPassword('123456', 'n', 'n');
      expect(reset.accessToken, 'acc');
      expect(adapter.last.data['token'], '123456');
    });

    test('server errors surface as DioException', () async {
      adapter.onError('POST /auth/login', 401);

      await expectLater(
        datasource.login('a', 'b'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('AuthRepository', () {
    test(
      'login, register, google and reset return entity and tokens',
      () async {
        adapter
          ..on('POST /auth/login', _auth())
          ..on('POST /auth/register', _auth())
          ..on('POST /auth/google', _auth())
          ..on('POST /auth/reset-password', _auth());

        final results = [
          await repo.login('a', 'b'),
          await repo.register(
            'a@b.c',
            'ana',
            'Ana',
            'pw',
            'pw',
            skillLevel: 'x',
          ),
          await repo.googleSignIn('gt'),
          await repo.resetPassword('t', 'n', 'n'),
        ];

        for (final (user, access, refresh) in results) {
          expect(user.username, 'ana');
          expect(access, 'acc');
          expect(refresh, 'ref');
        }
      },
    );

    test('profile, token and password operations delegate', () async {
      adapter
        ..on('GET /auth/me', _user())
        ..on('PUT /auth/me', _user())
        ..on('POST /auth/refresh', {'access_token': 'a', 'refresh_token': 'r'})
        ..on('POST /auth/forgot-password', {'message': 'ok'})
        ..on('PUT /auth/change-password', {'message': 'ok'})
        ..on('DELETE /auth/me', {'message': 'ok'});

      expect((await repo.getCurrentUser()).id, 'u1');
      expect((await repo.updateProfile(fullName: 'Ana')).id, 'u1');
      expect(await repo.refreshToken('r0'), ('a', 'r'));
      await repo.forgotPassword('a@b.c');
      await repo.changePassword('o', 'n');
      await repo.deleteAccount(password: 'pw');

      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /auth/me',
        'PUT /auth/me',
        'POST /auth/refresh',
        'POST /auth/forgot-password',
        'PUT /auth/change-password',
        'DELETE /auth/me',
      ]);
    });
  });
}
