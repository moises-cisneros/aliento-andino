import { Injectable } from '@angular/core';

/// Wrapper sobre sessionStorage para almacenamiento de tokens y datos de sesión.
/// El refresh token se maneja via httpOnly cookie (no almacenado en el cliente).
@Injectable({ providedIn: 'root' })
export class StorageService {
  private readonly ACCESS_TOKEN_KEY = 'pv_access_token';
  private readonly USER_KEY = 'pv_user';

  // --- Token ---

  getAccessToken(): string | null {
    return sessionStorage.getItem(this.ACCESS_TOKEN_KEY);
  }

  setAccessToken(token: string): void {
    sessionStorage.setItem(this.ACCESS_TOKEN_KEY, token);
  }

  saveTokens(accessToken: string): void {
    this.setAccessToken(accessToken);
    // Refresh token es manejado como httpOnly cookie por el backend
  }

  // --- Usuario ---

  getUser(): string | null {
    return sessionStorage.getItem(this.USER_KEY);
  }

  setUser(user: object): void {
    sessionStorage.setItem(this.USER_KEY, JSON.stringify(user));
  }

  // --- Limpieza ---

  clearAll(): void {
    sessionStorage.removeItem(this.ACCESS_TOKEN_KEY);
    sessionStorage.removeItem(this.USER_KEY);
  }
}
