import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';

import { Achievement, AchievementCreate } from '../../../core/models/ranking.model';

@Component({
  selector: 'app-achievement-form-dialog',
  standalone: true,
  imports: [CommonModule, FormsModule, MatDialogModule],
  template: `
    <h2 mat-dialog-title>{{ data ? 'Editar' : 'Crear' }} Logro</h2>

    <mat-dialog-content>
      <div class="form-body">
        <div class="form-group">
          <label>Código</label>
          <input class="form-input" [(ngModel)]="form.code" [disabled]="!!data" placeholder="first_practice">
        </div>

        <div class="form-group">
          <label>Nombre</label>
          <input class="form-input" [(ngModel)]="form.name" placeholder="Primera Práctica">
        </div>

        <div class="form-group">
          <label>Descripción</label>
          <textarea class="form-textarea" [(ngModel)]="form.description" rows="2"></textarea>
        </div>

        <div class="form-group">
          <label>Ícono (emoji o texto)</label>
          <input class="form-input" [(ngModel)]="form.icon" placeholder="🎵">
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Categoría</label>
            <select class="form-select" [(ngModel)]="form.category">
              <option value="practice">Practice</option>
              <option value="streak">Streak</option>
              <option value="score">Score</option>
              <option value="social">Social</option>
              <option value="milestone">Milestone</option>
            </select>
          </div>

          <div class="form-group">
            <label>Rareza</label>
            <select class="form-select" [(ngModel)]="form.rarity">
              <option value="common">Common</option>
              <option value="rare">Rare</option>
              <option value="epic">Epic</option>
              <option value="legendary">Legendary</option>
            </select>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Tipo de requisito</label>
            <select class="form-select" [(ngModel)]="form.requirement_type">
              <option value="total_sessions">Total Sessions</option>
              <option value="current_streak">Current Streak</option>
              <option value="longest_streak">Longest Streak</option>
              <option value="high_score">High Score</option>
              <option value="perfect_sessions">Perfect Sessions</option>
              <option value="total_posts">Total Posts</option>
              <option value="followers_count">Followers Count</option>
              <option value="total_minutes">Total Minutes</option>
              <option value="total_completed">Total Completed</option>
              <option value="level">Level</option>
              <option value="total_xp">Total XP</option>
            </select>
          </div>

          <div class="form-group">
            <label>Valor requerido</label>
            <input class="form-input" type="number" [(ngModel)]="form.requirement_value">
          </div>
        </div>

        <div class="form-group">
          <label>XP de recompensa</label>
          <input class="form-input" type="number" [(ngModel)]="form.xp_reward">
        </div>

        @if (data) {
          <label class="checkbox">
            <input type="checkbox" [(ngModel)]="form.is_active">
            <span>Activo</span>
          </label>
        }
      </div>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button class="btn btn-ghost" mat-dialog-close>Cancelar</button>
      <button class="btn btn-primary" (click)="save()" [disabled]="!isValid()">
        {{ data ? 'Guardar' : 'Crear' }}
      </button>
    </mat-dialog-actions>
  `,
  styles: [`
    .form-body { display: flex; flex-direction: column; gap: 12px; min-width: 420px; padding: 8px 0; }
  `],
})
export class AchievementFormDialogComponent {
  readonly data = inject<Achievement | null>(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<AchievementFormDialogComponent>);

  form: AchievementCreate & { is_active?: boolean } = {
    code: this.data?.code ?? '',
    name: this.data?.name ?? '',
    description: this.data?.description ?? '',
    icon: this.data?.icon ?? '🏆',
    category: this.data?.category ?? 'practice',
    rarity: this.data?.rarity ?? 'common',
    xp_reward: this.data?.xp_reward ?? 50,
    requirement_type: this.data?.requirement_type ?? 'total_sessions',
    requirement_value: this.data?.requirement_value ?? 1,
    is_active: this.data?.is_active ?? true,
  };

  isValid(): boolean {
    return !!(this.form.code && this.form.name && this.form.description &&
      this.form.category && this.form.requirement_type && this.form.requirement_value > 0);
  }

  save(): void {
    this.dialogRef.close(this.form);
  }
}
