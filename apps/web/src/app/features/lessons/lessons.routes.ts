import { Routes } from '@angular/router';

/// Rutas del módulo de lecciones (admin).
export const lessonsRoutes: Routes = [
  {
    path: 'dashboard',
    loadComponent: () =>
      import('./lessons-dashboard/lessons-dashboard.component').then(
        (m) => m.LessonsDashboardComponent,
      ),
  },
  {
    path: 'categories',
    loadComponent: () =>
      import('./category-list/category-list.component').then((m) => m.CategoryListComponent),
  },
  {
    path: 'list',
    loadComponent: () =>
      import('./lesson-list/lesson-list.component').then((m) => m.LessonListComponent),
  },
  {
    path: 'new',
    loadComponent: () =>
      import('./lesson-form/lesson-form.component').then((m) => m.LessonFormComponent),
  },
  {
    path: ':id/edit',
    loadComponent: () =>
      import('./lesson-form/lesson-form.component').then((m) => m.LessonFormComponent),
  },
  {
    path: ':id/notes',
    loadComponent: () =>
      import('./notes-editor/notes-editor.component').then((m) => m.NotesEditorComponent),
  },
  {
    path: 'fingerings',
    loadComponent: () =>
      import('../fingerings/fingering-catalog/fingering-catalog.component').then(
        (m) => m.FingeringCatalogComponent,
      ),
  },
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
];
