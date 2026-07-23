import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';

import { AuthService } from '../services/auth.service';

/// Guard funcional: requiere que el usuario sea administrador (is_admin=true).
/// Si no es admin, redirige a /auth/login.
export const adminGuard: CanActivateFn = () => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (authService.isAuthenticated() && authService.isAdminUser()) {
    return true;
  }

  return router.createUrlTree(['/auth/login'], {
    queryParams: { error: 'admin_required' },
  });
};
