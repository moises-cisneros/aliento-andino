import { Routes } from '@angular/router';

/// Rutas del módulo de moderación social (admin).
export const moderationRoutes: Routes = [
  {
    path: 'reports',
    loadComponent: () =>
      import('./reports-list/reports-list.component').then(
        (m) => m.ReportsListComponent,
      ),
  },
  {
    path: 'reported-posts',
    loadComponent: () =>
      import('./reported-posts/reported-posts.component').then(
        (m) => m.ReportedPostsComponent,
      ),
  },
  {
    path: 'banned-users',
    loadComponent: () =>
      import('./banned-users/banned-users.component').then(
        (m) => m.BannedUsersComponent,
      ),
  },
  {
    path: 'stats',
    loadComponent: () =>
      import('./social-stats/social-stats.component').then(
        (m) => m.SocialStatsComponent,
      ),
  },
  { path: '', redirectTo: 'reports', pathMatch: 'full' },
];
