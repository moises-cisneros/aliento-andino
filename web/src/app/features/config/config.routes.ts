import { Routes } from '@angular/router';

export const configRoutes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./config-form/config-form.component').then((m) => m.ConfigFormComponent),
  },
];
