import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucidePlus,
  LucideSearch,
  LucidePencil,
  LucideMusic,
  LucideTrash2,
  LucideChevronLeft,
  LucideChevronRight,
} from '@lucide/angular';

import { LessonService } from '../../../core/services/lesson.service';
import { CategoryService } from '../../../core/services/category.service';
import { Lesson } from '../../../core/models/lesson.model';

@Component({
  selector: 'app-lesson-list',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    LucidePlus, LucideSearch, LucidePencil, LucideMusic, LucideTrash2,
    LucideChevronLeft, LucideChevronRight,
  ],
  template: `
    <div class="lesson-list">
      <div class="header-row">
        <h2>Lecciones</h2>
        <button class="btn btn-primary" (click)="navigateToCreate()">
          <svg lucidePlus [size]="16"></svg> Nueva Lección
        </button>
      </div>

      <!-- Filtros -->
      <div class="filters-row">
        <div class="form-group filter-field">
          <div class="input-wrapper">
            <input
              class="form-input"
              [(ngModel)]="searchTerm"
              (keyup.enter)="applyFilters()"
              placeholder="Buscar por título..."
            />
            <svg lucideSearch [size]="16" class="input-trail-icon"></svg>
          </div>
        </div>

        <div class="form-group filter-field">
          <select class="form-select" [(ngModel)]="selectedCategory" (change)="applyFilters()">
            <option value="">Todas las categorías</option>
            @for (cat of categoryService.categories(); track cat.id) {
              <option [value]="cat.id">{{ cat.name }}</option>
            }
          </select>
        </div>

        <div class="form-group filter-field">
          <select class="form-select" [(ngModel)]="selectedDifficulty" (change)="applyFilters()">
            <option value="">Todas las dificultades</option>
            <option value="principiante">Principiante</option>
            <option value="intermedio">Intermedio</option>
            <option value="avanzado">Avanzado</option>
          </select>
        </div>
      </div>

      <!-- Tabla -->
      <div class="table-container">
        <table class="table">
          <thead>
            <tr>
              <th>Título</th>
              <th>Categoría</th>
              <th>Dificultad</th>
              <th>BPM</th>
              <th>Notas</th>
              <th>Plays</th>
              <th>Score</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            @for (l of lessonService.lessons(); track l.id) {
              <tr>
                <td>{{ l.title }}</td>
                <td>{{ l.category_name || '—' }}</td>
                <td>
                  <span class="chip" [class]="'chip-' + l.difficulty">
                    {{ l.difficulty | titlecase }}
                  </span>
                </td>
                <td>{{ l.tempo_bpm }}</td>
                <td>{{ l.notes_count }}</td>
                <td>{{ l.total_plays }}</td>
                <td>{{ l.average_score | number:'1.0-0' }}%</td>
                <td>
                  <span class="chip" [class]="l.is_active ? 'chip-success' : 'chip-error'">
                    {{ l.is_active ? 'Activa' : 'Inactiva' }}
                  </span>
                </td>
                <td>
                  <div class="action-buttons">
                    <button class="btn-icon" title="Editar" (click)="navigateToEdit(l.id)">
                      <svg lucidePencil [size]="16"></svg>
                    </button>
                    <button class="btn-icon" title="Editar Notas" (click)="navigateToNotes(l.id)">
                      <svg lucideMusic [size]="16"></svg>
                    </button>
                    <button class="btn-icon danger" title="Eliminar" (click)="confirmDelete(l)">
                      <svg lucideTrash2 [size]="16"></svg>
                    </button>
                  </div>
                </td>
              </tr>
            }
          </tbody>
        </table>
      </div>

      <!-- Paginación -->
      <div class="pagination">
        <span>{{ lessonService.totalLessons() }} resultados</span>
        <select [(ngModel)]="pageSize" (change)="applyFilters()">
          <option [value]="10">10</option>
          <option [value]="25">25</option>
          <option [value]="50">50</option>
        </select>
        <span>por página</span>
        <button [disabled]="currentPage <= 1" (click)="changePage(-1)">
          <svg lucideChevronLeft [size]="16"></svg>
        </button>
        <span>{{ currentPage }} / {{ totalPages() }}</span>
        <button [disabled]="currentPage >= totalPages()" (click)="changePage(1)">
          <svg lucideChevronRight [size]="16"></svg>
        </button>
      </div>
    </div>
  `,
  styles: [`
    .lesson-list { padding: 0; }
    .header-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    .header-row h2 { color: var(--text-secondary); margin: 0; }

    .filters-row { display: flex; gap: 12px; margin-bottom: 16px; flex-wrap: wrap; }
    .filter-field { min-width: 180px; }

    .input-wrapper { position: relative; }
    .input-trail-icon {
      position: absolute; right: 12px; top: 50%; transform: translateY(-50%);
      color: var(--text-dimmed); pointer-events: none;
    }

    .action-buttons { display: flex; gap: 2px; }

    .chip-principiante { background: var(--color-success-subtle); color: var(--color-success); }
    .chip-intermedio { background: var(--color-warning-subtle); color: var(--color-warning); }
    .chip-avanzado { background: var(--color-error-subtle); color: var(--color-error); }
  `],
})
export class LessonListComponent implements OnInit {
  readonly lessonService = inject(LessonService);
  readonly categoryService = inject(CategoryService);
  private readonly router = inject(Router);
  private readonly snackBar = inject(MatSnackBar);

  searchTerm = '';
  selectedCategory = '';
  selectedDifficulty = '';
  pageSize = 10;
  currentPage = 1;

  ngOnInit(): void {
    this.categoryService.loadCategories().subscribe();
    this.loadData();
  }

  totalPages(): number {
    return Math.max(1, Math.ceil(this.lessonService.totalLessons() / this.pageSize));
  }

  loadData(): void {
    this.lessonService.loadLessons({
      page: this.currentPage,
      limit: this.pageSize,
      category_id: this.selectedCategory || undefined,
      difficulty: this.selectedDifficulty || undefined,
      search: this.searchTerm || undefined,
    }).subscribe();
  }

  applyFilters(): void {
    this.currentPage = 1;
    this.loadData();
  }

  changePage(delta: number): void {
    this.currentPage += delta;
    this.loadData();
  }

  navigateToCreate(): void {
    this.router.navigate(['/admin/lessons/new']);
  }

  navigateToEdit(id: string): void {
    this.router.navigate(['/admin/lessons', id, 'edit']);
  }

  navigateToNotes(id: string): void {
    this.router.navigate(['/admin/lessons', id, 'notes']);
  }

  confirmDelete(lesson: Lesson): void {
    if (confirm('¿Eliminar la lección "' + lesson.title + '"?')) {
      this.lessonService.delete(lesson.id).subscribe({
        next: () => {
          this.snackBar.open('Lección eliminada', 'OK', { duration: 3000 });
          this.loadData();
        },
        error: (err) => {
          this.snackBar.open(err.error?.detail || 'Error al eliminar', 'OK', { duration: 3000 });
        },
      });
    }
  }
}
