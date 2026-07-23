import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile/core/storage/secure_storage.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorage extends Mock implements SecureStorageService {}

const _testUser = UserEntity(
  id: '123e4567-e89b-12d3-a456-426614174000',
  email: 'test@example.com',
  username: 'testuser',
  fullName: 'Test User',
  isActive: true,
  isAdmin: false,
  isVerified: true,
  authProvider: 'local',
  createdAt: '2024-01-01T00:00:00Z',
);

/// JSON de un perfil cacheado válido (lo que guarda _cacheUser).
const _cachedUserJson =
    '{"id":"123e4567-e89b-12d3-a456-426614174000","email":"test@example.com",'
    '"username":"testuser","full_name":"Test User","is_active":true,'
    '"is_admin":false,"is_verified":true,"auth_provider":"local",'
    '"created_at":"2024-01-01T00:00:00Z"}';

final _reqOptions = RequestOptions(path: '/users/me');

/// Error de red (sin internet): no hay response.
final _networkError = DioException(
  requestOptions: _reqOptions,
  type: DioExceptionType.connectionError,
);

/// Error de auth real (token inválido tras refresh fallido): 401.
final _authError = DioException(
  requestOptions: _reqOptions,
  response: Response(requestOptions: _reqOptions, statusCode: 401),
);

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockSecureStorage mockSecureStorage;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockSecureStorage = MockSecureStorage();
    // Stubs comunes: persistencia de perfil/tokens (no rompen los flujos).
    when(() => mockSecureStorage.saveUser(any())).thenAnswer((_) async {});
    when(() => mockSecureStorage.getUser()).thenAnswer((_) async => null);
    when(() => mockSecureStorage.clearAll()).thenAnswer((_) async {});
  });

  AuthBloc buildBloc() => AuthBloc(
    authRepository: mockAuthRepository,
    secureStorage: mockSecureStorage,
  );

  group('AuthCheckRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when no token stored',
      setUp: () {
        when(
          () => mockSecureStorage.getAccessToken(),
        ).thenAnswer((_) async => null);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when token is valid',
      setUp: () {
        when(
          () => mockSecureStorage.getAccessToken(),
        ).thenAnswer((_) async => 'valid_token');
        when(
          () => mockAuthRepository.getCurrentUser(),
        ).thenAnswer((_) async => _testUser);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'token inválido (401) → AuthUnauthenticated y limpia los tokens',
      setUp: () {
        when(
          () => mockSecureStorage.getAccessToken(),
        ).thenAnswer((_) async => 'invalid_token');
        when(() => mockAuthRepository.getCurrentUser()).thenThrow(_authError);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
      verify: (_) {
        verify(() => mockSecureStorage.clearAll()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'SIN INTERNET con perfil cacheado → sigue AuthAuthenticated y NO borra tokens',
      setUp: () {
        when(
          () => mockSecureStorage.getAccessToken(),
        ).thenAnswer((_) async => 'valid_token');
        when(() => mockAuthRepository.getCurrentUser()).thenThrow(_networkError);
        when(
          () => mockSecureStorage.getUser(),
        ).thenAnswer((_) async => _cachedUserJson);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
      verify: (_) {
        verifyNever(() => mockSecureStorage.clearAll());
      },
    );

    blocTest<AuthBloc, AuthState>(
      'SIN INTERNET sin perfil cacheado → AuthUnauthenticated pero NO borra tokens',
      setUp: () {
        when(
          () => mockSecureStorage.getAccessToken(),
        ).thenAnswer((_) async => 'valid_token');
        when(() => mockAuthRepository.getCurrentUser()).thenThrow(_networkError);
        when(() => mockSecureStorage.getUser()).thenAnswer((_) async => null);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
      verify: (_) {
        verifyNever(() => mockSecureStorage.clearAll());
      },
    );
  });

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful login',
      setUp: () {
        when(
          () => mockAuthRepository.login('test@example.com', 'Pass123456'),
        ).thenAnswer((_) async => (_testUser, 'access', 'refresh'));
        when(
          () => mockSecureStorage.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'test@example.com',
          password: 'Pass123456',
        ),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
      verify: (_) {
        verify(
          () => mockSecureStorage.saveTokens(
            accessToken: 'access',
            refreshToken: 'refresh',
          ),
        ).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on login failure',
      setUp: () {
        when(
          () => mockAuthRepository.login('test@example.com', 'wrong'),
        ).thenThrow(Exception('Credenciales inválidas'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'test@example.com', password: 'wrong'),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });

  group('AuthRegisterRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthRegistered] on successful register',
      setUp: () {
        when(
          () => mockAuthRepository.register(
            'new@example.com',
            'newuser',
            'New User',
            'SecurePass123',
            'SecurePass123',
          ),
        ).thenAnswer((_) async => (_testUser, 'access', 'refresh'));
        when(
          () => mockSecureStorage.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthRegisterRequested(
          email: 'new@example.com',
          username: 'newuser',
          fullName: 'New User',
          password: 'SecurePass123',
          passwordConfirm: 'SecurePass123',
        ),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthRegistered>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on register failure',
      setUp: () {
        when(
          () => mockAuthRepository.register(
            'existing@example.com',
            'existinguser',
            'Name',
            'Pass123456',
            'Pass123456',
          ),
        ).thenThrow(Exception('Email ya registrado'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthRegisterRequested(
          email: 'existing@example.com',
          username: 'existinguser',
          fullName: 'Name',
          password: 'Pass123456',
          passwordConfirm: 'Pass123456',
        ),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthUnauthenticated] on logout',
      setUp: () {
        when(() => mockSecureStorage.clearAll()).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => [isA<AuthUnauthenticated>()],
      verify: (_) {
        verify(() => mockSecureStorage.clearAll()).called(1);
      },
    );
  });

  group('AuthForgotPasswordRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthPasswordResetSent] on success',
      setUp: () {
        when(
          () => mockAuthRepository.forgotPassword('test@example.com'),
        ).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthForgotPasswordRequested(email: 'test@example.com'),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthPasswordResetSent>()],
    );
  });
}
