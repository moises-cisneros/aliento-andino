import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucidePlus,
  LucidePencil,
  LucideTrash2,
  LucideFolderOpen,
} from '@lucide/angular';

import { CategoryService } from '../../../core/services/category.service';
import { CategoryWithCount } from '../../../core/models/category.model';
import { CategoryFormDialogComponent } from '../category-form-dialog/category-form-dialog.component';

@Component({
  selector: 'app-category-list',
  standalone: true,
  imports: [
    CommonModule,
    LucidePlus, LucidePencil, LucideTrash2, LucideFolderOpen,
  ],
  template: `
    <div class="category-list">
      <div class="header-row">
        <h2>Categorías</h2>
        <button class="btn btn-primary" (click)="openCreate()">
          <svg lucidePlus [size]="16"></svg> Nueva Categoría
        </button>
      </div>

      <div class="table-container">
        <table class="table">
          <thead>
            <tr>
              <th>Ícono</th>
              <th>Nombre</th>
              <th>Descripción</th>
              <th>Lecciones</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            @for (cat of categories(); track cat.id) {
              <tr>
                <td>
                  <svg lucideFolderOpen [size]="18" class="icon-primary"></svg>
                </td>
                <td>{{ cat.name }}</td>
                <td>{{ cat.description }}</td>
                <td>{{ cat.lessons_count }}</td>
                <td>
                  <span class="chip" [class]="cat.is_active ? 'chip-success' : 'chip-error'">
                    {{ cat.is_active ? 'Activa' : 'Inactiva' }}
                  </span>
                </td>
                <td>
                  <div class="action-buttons">
                    <button class="btn-icon" title="Editar" (click)="openEdit(cat)">
                      <svg lucidePencil [size]="16"></svg>
                    </button>
                    <button class="btn-icon danger" title="Eliminar" (click)="confirmDelete(cat)">
                      <svg lucideTrash2 [size]="16"></svg>
                    </button>
                  </div>
                </td>
              </tr>
            }
          </tbody>
        </table>
      </div>

      @if (categories().length === 0 && !categoryService.isLoading()) {
        <div class="empty-state">
          <svg lucideFolderOpen [size]="48" class="text-muted"></svg>
          <p>No hay categorías creadas</p>
        </div>
      }
    </div>
  `,
  styles: [`
    .header-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    .header-row h2 { color: var(--text-secondary); margin: 0; }
    .action-buttons { display: flex; gap: 2px; }
    .empty-state { text-align: center; padding: 48px; color: var(--text-muted); }
    .empty-state p { margin-top: 12px; }
  `],
})
export class CategoryListComponent implements OnInit {
  readonly categoryService = inject(CategoryService);
  private readonly dialog = inject(MatDialog);
  private readonly snackBar = inject(MatSnackBar);

  readonly categories = this.categoryService.categories;

  ngOnInit(): void {
    this.loadData();
  }

  loadData(): void {
    this.categoryService.loadCategories().subscribe();
  }

  openCreate(): void {
    const dialogRef = this.dialog.open(CategoryFormDialogComponent, {
      width: '480px',
    });
    dialogRef.afterClosed().subscribe((result) => {
      if (result) this.loadData();
    });
  }

  openEdit(cat: CategoryWithCount): void {
    const dialogRef = this.dialog.open(CategoryFormDialogComponent, {
      width: '480px',
      data: cat,
    });
    dialogRef.afterClosed().subscribe((result) => {
      if (result) this.loadData();
    });
  }

  confirmDelete(cat: CategoryWithCount): void {
    if (confirm('¿Eliminar la categoría "' + cat.name + '"?')) {
      this.categoryService.delete(cat.id).subscribe({
        next: () => {
          this.snackBar.open('Categoría eliminada', 'OK', { duration: 3000 });
          this.loadData();
        },
        error: (err) => {
          this.snackBar.open(err.error?.detail || 'Error al eliminar', 'OK', { duration: 3000 });
        },
      });
    }
  }
}
