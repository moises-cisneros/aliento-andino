import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';

import { CategoryService } from '../../../core/services/category.service';
import { Category } from '../../../core/models/category.model';

@Component({
  selector: 'app-category-form-dialog',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatDialogModule,
  ],
  template: `
    <h2 mat-dialog-title>{{ isEdit ? 'Editar Categoría' : 'Nueva Categoría' }}</h2>

    <mat-dialog-content>
      <form [formGroup]="form" class="form-grid">
        <div class="form-group">
          <label>Nombre</label>
          <input class="form-input" formControlName="name" placeholder="Ej: Escalas" />
          @if (form.get('name')?.hasError('required') && form.get('name')?.touched) {
            <span class="form-error">El nombre es obligatorio</span>
          }
        </div>

        <div class="form-group">
          <label>Descripción</label>
          <textarea class="form-textarea" formControlName="description" rows="3" placeholder="Descripción de la categoría"></textarea>
        </div>

        <div class="row-2">
          <div class="form-group">
            <label>Ícono</label>
            <input class="form-input" formControlName="icon" placeholder="music" />
          </div>

          <div class="form-group">
            <label>Orden</label>
            <input class="form-input" formControlName="order" type="number" />
          </div>
        </div>
      </form>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button class="btn btn-ghost" mat-dialog-close>Cancelar</button>
      <button class="btn btn-primary" (click)="save()" [disabled]="form.invalid || saving()">
        {{ saving() ? 'Guardando...' : (isEdit ? 'Actualizar' : 'Crear') }}
      </button>
    </mat-dialog-actions>
  `,
  styles: [`
    .form-grid { display: flex; flex-direction: column; gap: 4px; min-width: 400px; }
    .form-group { margin-bottom: 12px; }
    .row-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    mat-dialog-content { color: var(--text-secondary); }
  `],
})
export class CategoryFormDialogComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly categoryService = inject(CategoryService);
  private readonly dialogRef = inject(MatDialogRef<CategoryFormDialogComponent>);
  private readonly data: Category | null = inject(MAT_DIALOG_DATA, { optional: true });
  private readonly snackBar = inject(MatSnackBar);

  readonly isEdit = !!this.data;
  readonly saving = signal(false);

  form!: FormGroup;

  ngOnInit(): void {
    this.form = this.fb.group({
      name: [this.data?.name ?? '', Validators.required],
      description: [this.data?.description ?? ''],
      icon: [this.data?.icon ?? ''],
      order: [this.data?.order ?? 0],
    });
  }

  save(): void {
    if (this.form.invalid) return;
    this.saving.set(true);

    const payload = this.form.value;

    const op = this.isEdit
      ? this.categoryService.update(this.data!.id, payload)
      : this.categoryService.create(payload);

    op.subscribe({
      next: () => {
        this.snackBar.open(
          this.isEdit ? 'Categoría actualizada' : 'Categoría creada', 'OK', { duration: 3000 });
        this.dialogRef.close(true);
      },
      error: (err) => {
        this.saving.set(false);
        this.snackBar.open(err.error?.detail || 'Error al guardar', 'OK', { duration: 3000 });
      },
    });
  }
}
