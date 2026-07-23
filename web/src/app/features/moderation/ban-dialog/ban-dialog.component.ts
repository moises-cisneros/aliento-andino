import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogModule, MatDialogRef } from '@angular/material/dialog';

@Component({
  selector: 'app-ban-dialog',
  standalone: true,
  imports: [CommonModule, FormsModule, MatDialogModule],
  template: `
    <h2 mat-dialog-title>Banear usuario</h2>
    <mat-dialog-content>
      <p class="text-body">¿Estás seguro de banear a este usuario? No podrá acceder a la plataforma.</p>
      <div class="form-group">
        <label>Motivo del baneo</label>
        <textarea class="form-textarea" [(ngModel)]="reason" rows="3" placeholder="Ingresa el motivo..."></textarea>
      </div>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button class="btn btn-ghost" mat-dialog-close>Cancelar</button>
      <button class="btn btn-danger" [disabled]="!reason.trim()" (click)="confirm()">
        Banear
      </button>
    </mat-dialog-actions>
  `,
  styles: [`
    .text-body { color: var(--text-muted); margin-bottom: 12px; }
  `],
})
export class BanDialogComponent {
  private readonly dialogRef = inject(MatDialogRef<BanDialogComponent>);
  reason = '';

  confirm(): void {
    if (this.reason.trim()) {
      this.dialogRef.close(this.reason.trim());
    }
  }
}
