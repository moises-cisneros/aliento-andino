import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucideTrash2,
  LucideBan,
  LucideCheckCircle,
} from '@lucide/angular';

import { ModerationService } from '../../../core/services/moderation.service';
import { Report } from '../../../core/models/social.model';

@Component({
  selector: 'app-report-detail-dialog',
  standalone: true,
  imports: [
    CommonModule,
    MatDialogModule,
    LucideTrash2, LucideBan, LucideCheckCircle,
  ],
  template: `
    <h2 mat-dialog-title>Detalle del reporte</h2>
    <mat-dialog-content>
      <div class="detail-section">
        <h4>Reportado por</h4>
        <p>{{ data.reporter.full_name }} (&#64;{{ data.reporter.username }})</p>
      </div>

      <div class="detail-section">
        <h4>Motivo</h4>
        <span class="chip" [class]="'chip-reason-' + data.reason">{{ data.reason }}</span>
        @if (data.description) {
          <p class="description">{{ data.description }}</p>
        }
      </div>

      <div class="detail-section">
        <h4>Estado</h4>
        <span class="chip" [class]="'chip-status-' + data.status">{{ data.status }}</span>
      </div>

      @if (data.post_id) {
        <div class="detail-section">
          <h4>Post reportado</h4>
          <div class="content-preview">
            <p>{{ data.post_content }}</p>
          </div>
        </div>
      }

      @if (data.comment_id) {
        <div class="detail-section">
          <h4>Comentario reportado</h4>
          <div class="content-preview">
            <p>{{ data.comment_content }}</p>
          </div>
        </div>
      }

      @if (data.reported_user_id) {
        <div class="detail-section">
          <h4>Usuario reportado</h4>
          <p>&#64;{{ data.reported_username }}</p>
        </div>
      }

      <div class="detail-section">
        <small class="date">Reportado: {{ data.created_at | date:'medium' }}</small>
      </div>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      @if (data.status === 'pending') {
        @if (data.post_id) {
          <button class="btn btn-danger btn-sm" (click)="deleteReportedPost()">
            <svg lucideTrash2 [size]="14"></svg> Eliminar post
          </button>
        }
        @if (data.reported_user_id) {
          <button class="btn btn-danger btn-sm" (click)="banReportedUser()">
            <svg lucideBan [size]="14"></svg> Banear usuario
          </button>
        }
        <button class="btn btn-primary btn-sm" (click)="resolveReport()">
          <svg lucideCheckCircle [size]="14"></svg> Resolver
        </button>
        <button class="btn btn-ghost btn-sm" (click)="dismissReport()">Descartar</button>
      }
      <button class="btn btn-ghost btn-sm" mat-dialog-close>Cerrar</button>
    </mat-dialog-actions>
  `,
  styles: [`
    .detail-section { margin-bottom: 16px; }
    .detail-section h4 { color: var(--text-muted); margin: 0 0 4px 0; font-size: 12px; text-transform: uppercase; }
    .detail-section p { color: var(--text-secondary); margin: 4px 0; }
    .content-preview { background: var(--bg-elevated); padding: 12px; border-radius: 8px; border-left: 3px solid var(--color-primary); }
    .description { color: var(--text-muted); font-style: italic; margin-top: 8px; }
    .date { color: var(--text-dimmed); }

    .chip-reason-spam { background: var(--color-error-subtle); color: var(--color-error); }
    .chip-reason-harassment { background: rgba(249, 115, 22, 0.15); color: var(--color-orange); }
    .chip-reason-inappropriate { background: var(--color-warning-subtle); color: var(--color-warning); }
    .chip-reason-misinformation { background: var(--color-primary-subtle); color: var(--color-primary); }
    .chip-reason-other { background: var(--bg-muted); color: var(--text-secondary); }

    .chip-status-pending { background: var(--color-warning-subtle); color: var(--color-warning); }
    .chip-status-reviewed { background: var(--color-primary-subtle); color: var(--color-primary); }
    .chip-status-resolved { background: var(--color-success-subtle); color: var(--color-success); }
    .chip-status-dismissed { background: var(--bg-muted); color: var(--text-secondary); }
  `],
})
export class ReportDetailDialogComponent {
  readonly data: Report = inject(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<ReportDetailDialogComponent>);
  private readonly moderationService = inject(ModerationService);
  private readonly snackBar = inject(MatSnackBar);

  resolveReport(): void {
    this.moderationService.updateReportStatus(this.data.id, 'resolved').subscribe({
      next: () => {
        this.snackBar.open('Reporte resuelto', 'OK', { duration: 3000 });
        this.dialogRef.close(true);
      },
      error: (err) => this.snackBar.open(err.error?.detail || 'Error', 'OK', { duration: 3000 }),
    });
  }

  dismissReport(): void {
    this.moderationService.updateReportStatus(this.data.id, 'dismissed').subscribe({
      next: () => {
        this.snackBar.open('Reporte descartado', 'OK', { duration: 3000 });
        this.dialogRef.close(true);
      },
      error: (err) => this.snackBar.open(err.error?.detail || 'Error', 'OK', { duration: 3000 }),
    });
  }

  deleteReportedPost(): void {
    if (!this.data.post_id) return;
    if (!confirm('¿Eliminar este post permanentemente?')) return;
    this.moderationService.deletePost(this.data.post_id).subscribe({
      next: () => {
        this.snackBar.open('Post eliminado', 'OK', { duration: 3000 });
        this.resolveReport();
      },
      error: (err) => this.snackBar.open(err.error?.detail || 'Error', 'OK', { duration: 3000 }),
    });
  }

  banReportedUser(): void {
    if (!this.data.reported_user_id) return;
    const reason = prompt('Motivo del baneo:');
    if (!reason) return;
    this.moderationService.banUser(this.data.reported_user_id, reason).subscribe({
      next: () => {
        this.snackBar.open('Usuario baneado', 'OK', { duration: 3000 });
        this.resolveReport();
      },
      error: (err) => this.snackBar.open(err.error?.detail || 'Error', 'OK', { duration: 3000 }),
    });
  }
}
