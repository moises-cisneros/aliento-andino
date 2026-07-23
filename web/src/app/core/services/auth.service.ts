import { Injectable, inject, signal, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { BehaviorSubject, Observable, firstValueFrom, tap } from 'rxjs';

import { environment } from '../../../environments/environment';
import { StorageService } from './storage.service';
import { User, AuthResponse, RefreshResponse, MessageResponse } from '../models/user.model';

/// Servicio principal de autenticación.
/// Maneja login, logout, refresh, estado del usuario y verificación de permisos.
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly storage = inject(StorageService);
  private readonly router = inject(Router);

  private readonly apiUrl = `${environment.apiBaseUrl}/auth`;

  // Estado reactivo con BehaviorSubject (para suscripciones RxJS)
  readonly currentUser$ = new BehaviorSubject<User | null>(null);
  readonly isLoggedIn$ = new BehaviorSubject<boolean>(false);

  // Signals para uso en templates
  readonly currentUser = signal<User | null>(null);
  readonly isLoading = signal(false);

  // Signal computado
  readonly isAdmin = computed(() => this.currentUser()?.is_admin === true);

  /// Login con email y contraseña.
  login(email: string, password: string): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/login`, { email, password }).pipe(
      tap((res) => this._handleAuthSuccess(res)),
    );
  }

  /// Cerrar sesión: limpiar estado local, revocar tokens en servidor y limpiar cookie.
  logout(): void {
    const token = this.storage.getAccessToken();
    this.storage.clearAll();
    this.currentUser.set(null);
    this.currentUser$.next(null);
    this.isLoggedIn$.next(false);
    this.router.navigate(['/auth/login']);

    // Server-side: revocar tokens y limpiar httpOnly cookie (fire and forget)
    if (token) {
      this.http.post(`${this.apiUrl}/logout`, {}, {
        headers: { Authorization: `Bearer ${token}` },
        withCredentials: true,
      }).subscribe({ error: () => { /* ignore */ } });
    }
  }

  /// Refrescar el access token via httpOnly cookie (rotación).
  refreshToken(): Observable<RefreshResponse> {
    return this.http
      .post<RefreshResponse>(`${this.apiUrl}/refresh`, {})
      .pipe(
        tap((res) => {
          this.storage.saveTokens(res.access_token);
        }),
      );
  }

  /// Solicitar email de recuperación de contraseña.
  forgotPassword(email: string): Observable<MessageResponse> {
    return this.http.post<MessageResponse>(`${this.apiUrl}/forgot-password`, { email });
  }

  /// Restablecer contraseña con código de 6 dígitos → auto-login.
  resetPassword(token: string, newPassword: string, newPasswordConfirm: string): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/reset-password`, {
      token,
      new_password: newPassword,
      new_password_confirm: newPasswordConfirm,
    }).pipe(
      tap((res) => this._handleAuthSuccess(res)),
    );
  }

  /// Verificar si hay token almacenado.
  isAuthenticated(): boolean {
    return !!this.storage.getAccessToken();
  }

  /// Verificar si el usuario actual es admin.
  isAdminUser(): boolean {
    const user = this.currentUser();
    return user?.is_admin === true;
  }

  /// Obtener el usuario actual del signal.
  getCurrentUser(): User | null {
    return this.currentUser();
  }

  /// Restaurar sesión al iniciar la app (async).
  /// Verifica con el backend que el token sigue válido antes de mostrar la UI.
  async autoLogin(): Promise<boolean> {
    const token = this.storage.getAccessToken();
    const userJson = this.storage.getUser();

    if (!token || !userJson) {
      this._clearState();
      return false;
    }

    try {
      const user: User = JSON.parse(userJson);
      this.currentUser.set(user);
      this.currentUser$.next(user);
      this.isLoggedIn$.next(true);

      // Verificar con el backend que el token sigue válido
      const verifiedUser = await firstValueFrom(
        this.http.get<User>(`${this.apiUrl}/me`),
      );

      this.currentUser.set(verifiedUser);
      this.currentUser$.next(verifiedUser);
      this.storage.setUser(verifiedUser);

      // Si el usuario no es admin, forzar logout
      if (!verifiedUser.is_admin) {
        this.logout();
        return false;
      }

      return true;
    } catch {
      this._clearState();
      return false;
    }
  }

  /// Manejar respuesta exitosa de login.
  private _handleAuthSuccess(res: AuthResponse): void {
    this.storage.saveTokens(res.access_token);
    this.storage.setUser(res.user);
    this.currentUser.set(res.user);
    this.currentUser$.next(res.user);
    this.isLoggedIn$.next(true);
  }

  /// Limpiar todo el estado de autenticación.
  private _clearState(): void {
    this.storage.clearAll();
    this.currentUser.set(null);
    this.currentUser$.next(null);
    this.isLoggedIn$.next(false);
  }
}
