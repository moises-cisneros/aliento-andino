import { Routes } from '@angular/router';

export const businessRoutes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./business-dashboard/business-dashboard.component').then(
        (m) => m.BusinessDashboardComponent,
      ),
  },
];
