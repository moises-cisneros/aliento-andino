import { Routes } from '@angular/router';

export const fingeringsRoutes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./fingering-catalog/fingering-catalog.component').then(
        (m) => m.FingeringCatalogComponent,
      ),
  },
];
