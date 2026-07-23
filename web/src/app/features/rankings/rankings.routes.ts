import { Routes } from '@angular/router';

export const rankingsRoutes: Routes = [
  {
    path: 'dashboard',
    loadComponent: () =>
      import('./rankings-dashboard/rankings-dashboard.component').then(
        (m) => m.RankingsDashboardComponent,
      ),
  },
  {
    path: 'achievements',
    loadComponent: () =>
      import('./achievements-list/achievements-list.component').then(
        (m) => m.AchievementsListComponent,
      ),
  },
  {
    path: 'leaderboard',
    loadComponent: () =>
      import('./leaderboard-view/leaderboard-view.component').then(
        (m) => m.LeaderboardViewComponent,
      ),
  },
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
];
