import { Routes } from '@angular/router';

import { authGuard } from './core/guards/auth.guard';
import { adminGuard } from './core/guards/admin.guard';
import { AdminLayoutComponent } from './shared/components/admin-layout/admin-layout.component';

export const routes: Routes = [
  // Rutas públicas de autenticación
  {
    path: 'auth/login',
    loadComponent: () =>
      import('./features/auth/login/login.component').then((m) => m.LoginComponent),
  },
  {
    path: 'auth/forgot-password',
    loadComponent: () =>
      import('./features/auth/forgot-password/forgot-password.component').then(
        (m) => m.ForgotPasswordComponent,
      ),
  },
  {
    path: 'auth/reset-password',
    loadComponent: () =>
      import('./features/auth/reset-password/reset-password.component').then(
        (m) => m.ResetPasswordComponent,
      ),
  },

  // Layout admin con sidebar y navbar
  {
    path: 'admin',
    component: AdminLayoutComponent,
    canActivate: [authGuard, adminGuard],
    children: [
      {
        path: 'dashboard',
        loadComponent: () =>
          import('./features/dashboard/dashboard.component').then((m) => m.DashboardComponent),
      },
      {
        path: 'lessons',
        loadChildren: () =>
          import('./features/lessons/lessons.routes').then((m) => m.lessonsRoutes),
      },
      {
        path: 'fingerings',
        loadChildren: () =>
          import('./features/fingerings/fingerings.routes').then((m) => m.fingeringsRoutes),
      },
      {
        path: 'moderation',
        loadChildren: () =>
          import('./features/moderation/moderation.routes').then((m) => m.moderationRoutes),
      },
      {
        path: 'rankings',
        loadChildren: () =>
          import('./features/rankings/rankings.routes').then((m) => m.rankingsRoutes),
      },
      {
        path: 'users',
        loadChildren: () => import('./features/users/users.routes').then((m) => m.usersRoutes),
      },
      {
        path: 'subscriptions',
        loadChildren: () =>
          import('./features/subscriptions/subscriptions.routes').then(
            (m) => m.subscriptionsRoutes,
          ),
      },
      {
        path: 'announcements',
        loadChildren: () =>
          import('./features/announcements/announcements.routes').then(
            (m) => m.announcementsRoutes,
          ),
      },
      {
        path: 'business',
        loadChildren: () =>
          import('./features/business/business.routes').then((m) => m.businessRoutes),
      },
      {
        path: 'reports',
        loadChildren: () =>
          import('./features/reports/reports.routes').then((m) => m.reportsRoutes),
      },
      {
        path: 'config',
        loadChildren: () => import('./features/config/config.routes').then((m) => m.configRoutes),
      },
      {
        path: 'audit',
        loadChildren: () => import('./features/audit/audit.routes').then((m) => m.auditRoutes),
      },
      {
        path: 'profile',
        loadComponent: () =>
          import('./features/profile/profile.component').then((m) => m.ProfileComponent),
      },
      { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
    ],
  },

  // Redirects
  { path: '', redirectTo: 'admin/dashboard', pathMatch: 'full' },
  { path: '**', redirectTo: 'auth/login' },
];
