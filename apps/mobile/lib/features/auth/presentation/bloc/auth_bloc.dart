import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC principal de autenticación.
/// Maneja login, registro, Google OAuth, refresh, logout y actualización de perfil.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final SecureStorageService secureStorage;

  bool _googleInitialized = false;

  AuthBloc({required this.authRepository, required this.secureStorage})
    : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignIn);
    on<AuthForgotPasswordRequested>(_onForgotPassword);
    on<AuthResetPasswordRequested>(_onResetPassword);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthProfileUpdateRequested>(_onProfileUpdate);
  }

  /// Verificar si hay sesión activa al abrir la app.
  ///
  /// Distingue dos casos al fallar la verificación del perfil:
  /// - Token inválido/expirado (401/403) → la sesión ya no sirve: se limpia
  ///   todo y se manda al login.
  /// - Sin internet / error de red → NO se borran los tokens: se restaura la
  ///   sesión con el perfil cacheado para que el usuario siga logueado offline.
  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final token = await secureStorage.getAccessToken();
    if (token == null) {
      emit(AuthUnauthenticated());
      return;
    }
    try {
      // Verificar que el token siga válido consultando el perfil (online).
      final user = await authRepository.getCurrentUser();
      await _cacheUser(user);
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      if (_isAuthError(e)) {
        // Token genuinamente inválido → logout real.
        await secureStorage.clearAll();
        emit(AuthUnauthenticated());
        return;
      }
      // Sin conexión: mantener la sesión con el perfil cacheado.
      final cached = await _loadCachedUser();
      if (cached != null) {
        emit(AuthAuthenticated(user: cached));
      } else {
        // Sesión previa al cacheo de perfil: NO borrar tokens (al reconectar
        // seguirá logueado); por ahora se pide login.
        emit(AuthUnauthenticated());
      }
    }
  }

  /// True solo si el error es de autenticación (401/403), no de red.
  bool _isAuthError(Object e) {
    return e is DioException &&
        (e.response?.statusCode == 401 || e.response?.statusCode == 403);
  }

  /// Guarda el perfil del usuario para poder restaurar la sesión sin internet.
  Future<void> _cacheUser(UserEntity user) async {
    try {
      await secureStorage.saveUser(
        jsonEncode(UserModel.fromEntity(user).toJson()),
      );
    } catch (_) {
      // Cachear el perfil no debe romper el login.
    }
  }

  /// Carga el perfil cacheado (o null si no hay / falla el parseo).
  Future<UserEntity?> _loadCachedUser() async {
    try {
      final raw = await secureStorage.getUser();
      if (raw == null) return null;
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Login con email y contraseña.
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final (user, accessToken, refreshToken) = await authRepository.login(
        event.email,
        event.password,
      );
      await secureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await _cacheUser(user);
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  /// Registro de nuevo usuario.
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final (user, accessToken, refreshToken) = await authRepository.register(
        event.email,
        event.username,
        event.fullName,
        event.password,
        event.passwordConfirm,
        skillLevel: event.skillLevel,
      );
      await secureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await _cacheUser(user);
      emit(AuthRegistered(user: user));
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  /// Autenticación con Google Sign-In (v7 API).
  Future<void> _onGoogleSignIn(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // Inicializar Google Sign-In si no se ha hecho
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: AppConfig.googleWebClientId,
        );
        _googleInitialized = true;
      }

      // Escuchar el stream ANTES de autenticar (evita race condition)
      final eventFuture = GoogleSignIn.instance.authenticationEvents.first;

      // Autenticar con Google
      await GoogleSignIn.instance.authenticate();

      // Obtener el evento de autenticación (ya capturado por el future)
      final authEvent = await eventFuture;

      if (authEvent is! GoogleSignInAuthenticationEventSignIn) {
        emit(const AuthError(message: 'Inicio de sesión con Google cancelado'));
        return;
      }

      final googleUser = authEvent.user;

      // Obtener el ID token (no access token) para verificar con el backend
      final authentication = googleUser.authentication;
      final idToken = authentication.idToken;
      if (idToken == null) {
        emit(
          const AuthError(message: 'No se pudo obtener el ID token de Google'),
        );
        return;
      }

      // Enviar token al backend
      final (user, accessToken, refreshToken) = await authRepository
          .googleSignIn(idToken);
      await secureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await _cacheUser(user);
      emit(AuthAuthenticated(user: user));
    } on GoogleSignInException catch (e) {
      final desc = (e.description ?? '').toLowerCase();
      if (e.code == GoogleSignInExceptionCode.canceled) {
        emit(const AuthError(message: 'Inicio de sesión con Google cancelado'));
      } else if (desc.contains('no credential') ||
          desc.contains('no credentials')) {
        // Credential Manager no encontró ninguna cuenta de Google en el
        // dispositivo (caso típico en emuladores sin cuenta agregada).
        emit(
          const AuthError(
            message:
                'No hay una cuenta de Google en este dispositivo. Agregá una en '
                'Ajustes → Cuentas del dispositivo, o iniciá sesión con tu email.',
          ),
        );
      } else {
        emit(
          const AuthError(
            message:
                'No se pudo iniciar sesión con Google. Probá de nuevo o usá tu '
                'email y contraseña.',
          ),
        );
      }
    } catch (e) {
      // Error logged only in debug builds
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  /// Solicitar recuperación de contraseña.
  Future<void> _onForgotPassword(
    AuthForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.forgotPassword(event.email);
      emit(
        const AuthPasswordResetSent(
          message:
              'Si el email existe, recibirás instrucciones para restablecer tu contraseña',
        ),
      );
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  /// Restablecer contraseña con token → auto-login.
  Future<void> _onResetPassword(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final (user, accessToken, refreshToken) = await authRepository
          .resetPassword(
            event.token,
            event.newPassword,
            event.newPasswordConfirm,
          );
      await secureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await _cacheUser(user);
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  /// Cerrar sesión.
  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await secureStorage.clearAll();
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.disconnect();
      }
    } catch (_) {
      // Ignorar error de disconnect de Google
    }
    emit(AuthUnauthenticated());
  }

  /// Actualizar perfil del usuario.
  Future<void> _onProfileUpdate(
    AuthProfileUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.updateProfile(
        fullName: event.fullName,
        username: event.username,
        bio: event.bio,
        avatarUrl: event.avatarUrl,
        skillLevel: event.skillLevel,
        notificationsPushEnabled: event.notificationsPushEnabled,
        notificationsEmailEnabled: event.notificationsEmailEnabled,
      );
      await _cacheUser(user);
      emit(AuthProfileUpdated(user: user));
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  /// Extraer mensaje de error legible de distintas excepciones.
  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('detail')) {
        return data['detail'] as String;
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Error de conexión. Verificá tu internet.';
      }
      return 'Error de conexión con el servidor';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
