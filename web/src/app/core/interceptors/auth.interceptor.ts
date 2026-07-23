import { HttpInterceptorFn, HttpRequest, HttpHandlerFn, HttpErrorResponse, HttpEvent } from '@angular/common/http';
import { inject } from '@angular/core';
import { BehaviorSubject, Observable, catchError, filter, switchMap, take, throwError } from 'rxjs';

import { StorageService } from '../services/storage.service';
import { AuthService } from '../services/auth.service';

/// Rutas que no requieren token de autenticación.
const PUBLIC_PATHS = ['/auth/login', '/auth/register', '/auth/refresh', '/auth/forgot-password', '/auth/reset-password'];

// Estado compartido para evitar múltiples refresh simultáneos
let isRefreshing = false;
const refreshTokenSubject = new BehaviorSubject<string | null>(null);

/// Interceptor funcional de autenticación.
/// - Adjunta withCredentials a todas las peticiones (para httpOnly cookie)
/// - Adjunta Authorization: Bearer {token} a peticiones protegidas
/// - Si recibe 401 → intenta refresh con cola (evita race condition)
/// - Si refresh falla → logout + redirect a /auth/login
export const authInterceptor: HttpInterceptorFn = (req: HttpRequest<unknown>, next: HttpHandlerFn) => {
  const storage = inject(StorageService);
  const authService = inject(AuthService);

  // Incluir credentials en todas las peticiones (para httpOnly cookie)
  let authReq = req.clone({ withCredentials: true });

  // No agregar Authorization a rutas públicas de auth
  if (PUBLIC_PATHS.some((path) => req.url.includes(path))) {
    return next(authReq);
  }

  // Adjuntar token si existe
  const token = storage.getAccessToken();
  if (token) {
    authReq = authReq.clone({ setHeaders: { Authorization: `Bearer ${token}` } });
  }

  return next(authReq).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401 && token) {
        return handle401(req, next, authService);
      }
      return throwError(() => error);
    }),
  );
};

function handle401(
  req: HttpRequest<unknown>,
  next: HttpHandlerFn,
  authService: AuthService,
): Observable<HttpEvent<unknown>> {
  if (!isRefreshing) {
    isRefreshing = true;
    refreshTokenSubject.next(null);

    return authService.refreshToken().pipe(
      switchMap((res) => {
        isRefreshing = false;
        refreshTokenSubject.next(res.access_token);
        const retryReq = req.clone({
          setHeaders: { Authorization: `Bearer ${res.access_token}` },
          withCredentials: true,
        });
        return next(retryReq);
      }),
      catchError((refreshError) => {
        isRefreshing = false;
        authService.logout();
        return throwError(() => refreshError);
      }),
    );
  }

  // Ya hay un refresh en curso — esperar a que termine y reintentar
  return refreshTokenSubject.pipe(
    filter((token) => token !== null),
    take(1),
    switchMap((newToken) => {
      const retryReq = req.clone({
        setHeaders: { Authorization: `Bearer ${newToken}` },
        withCredentials: true,
      });
      return next(retryReq);
    }),
  );
}
