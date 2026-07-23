import 'package:equatable/equatable.dart';

/// Eventos de autenticación para el AuthBloc.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Verificar si hay sesión activa al abrir la app.
class AuthCheckRequested extends AuthEvent {}

/// Login con email y contraseña.
class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// Registro de nuevo usuario.
class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String username;
  final String fullName;
  final String password;
  final String passwordConfirm;
  final String? skillLevel;

  const AuthRegisterRequested({
    required this.email,
    required this.username,
    required this.fullName,
    required this.password,
    required this.passwordConfirm,
    this.skillLevel,
  });

  @override
  List<Object?> get props => [
    email,
    username,
    fullName,
    password,
    passwordConfirm,
    skillLevel,
  ];
}

/// Iniciar flujo de Google Sign-In.
class AuthGoogleSignInRequested extends AuthEvent {}

/// Solicitar recuperación de contraseña.
class AuthForgotPasswordRequested extends AuthEvent {
  final String email;

  const AuthForgotPasswordRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

/// Restablecer contraseña con token.
class AuthResetPasswordRequested extends AuthEvent {
  final String token;
  final String newPassword;
  final String newPasswordConfirm;

  const AuthResetPasswordRequested({
    required this.token,
    required this.newPassword,
    required this.newPasswordConfirm,
  });

  @override
  List<Object?> get props => [token, newPassword, newPasswordConfirm];
}

/// Cerrar sesión.
class AuthLogoutRequested extends AuthEvent {}

/// Actualizar perfil del usuario.
class AuthProfileUpdateRequested extends AuthEvent {
  final String? fullName;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String? skillLevel;
  final bool? notificationsPushEnabled;
  final bool? notificationsEmailEnabled;

  const AuthProfileUpdateRequested({
    this.fullName,
    this.username,
    this.bio,
    this.avatarUrl,
    this.skillLevel,
    this.notificationsPushEnabled,
    this.notificationsEmailEnabled,
  });

  @override
  List<Object?> get props => [
    fullName,
    username,
    bio,
    avatarUrl,
    skillLevel,
    notificationsPushEnabled,
    notificationsEmailEnabled,
  ];
}
