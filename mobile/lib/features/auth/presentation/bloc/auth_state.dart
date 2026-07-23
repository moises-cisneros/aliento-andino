import 'package:equatable/equatable.dart';

import '../../domain/entities/user_entity.dart';

/// Estados de autenticación para el AuthBloc.
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial, app recién abierta.
class AuthInitial extends AuthState {}

/// Procesando una operación de auth (login, register, etc.).
class AuthLoading extends AuthState {}

/// Usuario autenticado exitosamente.
class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

/// No hay sesión activa o el token expiró.
class AuthUnauthenticated extends AuthState {}

/// Registro exitoso, navegar a home.
class AuthRegistered extends AuthState {
  final UserEntity user;

  const AuthRegistered({required this.user});

  @override
  List<Object?> get props => [user];
}

/// Email de recuperación de contraseña enviado.
class AuthPasswordResetSent extends AuthState {
  final String message;

  const AuthPasswordResetSent({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Contraseña restablecida exitosamente.
class AuthPasswordResetSuccess extends AuthState {}

/// Perfil del usuario actualizado.
class AuthProfileUpdated extends AuthState {
  final UserEntity user;

  const AuthProfileUpdated({required this.user});

  @override
  List<Object?> get props => [user];
}

/// Error en alguna operación de auth.
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}
