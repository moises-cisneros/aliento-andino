import { Routes } from '@angular/router';

export const announcementsRoutes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./announcement-compose/announcement-compose.component').then(
        (m) => m.AnnouncementComposeComponent,
      ),
  },
];
