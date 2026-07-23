import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucideCheckCircle,
  LucideTrash2,
  LucideXCircle,
} from '@lucide/angular';

import { ModerationService } from '../../../core/services/moderation.service';
import { Report } from '../../../core/models/social.model';

@Component({
  selector: 'app-reported-posts',
  standalone: true,
  imports: [CommonModule, LucideCheckCircle, LucideTrash2, LucideXCircle],
  template: `
    <div class="reported-posts">
      <div class="header-row">
        <h2>Posts reportados</h2>
      </div>

      @if (reportedPosts().length === 0) {
        <div class="empty-state">
          <svg lucideCheckCircle [size]="48" class="icon-success"></svg>
          <p>No hay posts reportados pendientes</p>
        </div>
      } @else {
        <div class="table-container">
          <table class="table">
            <thead>
              <tr>
                <th>Autor</th>
                <th>Contenido</th>
                <th>Motivo</th>
                <th>Reportes</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              @for (r of reportedPosts(); track r.id) {
                <tr>
                  <td>{{ r.reported_username ?? r.reporter.full_name }}</td>
                  <td class="content-cell">
                    {{ (r.post_content ?? '') | slice:0:80 }}{{ (r.post_content?.length ?? 0) > 80 ? '...' : '' }}
                  </td>
                  <td><span class="chip chip-warning">{{ reasonLabel(r.reason) }}</span></td>
                  <td>1</td>
                  <td>
                    <div class="action-buttons">
                      <button class="btn-icon danger" title="Eliminar post" (click)="deletePost(r)">
                        <svg lucideTrash2 [size]="16"></svg>
                      </button>
                      <button class="btn-icon" title="Descartar reporte" (click)="dismissReport(r)">
                        <svg lucideXCircle [size]="16"></svg>
                      </button>
                    </div>
                  </td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      }
    </div>
  `,
  styles: [`
    .reported-posts { }
    .header-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
    .header-row h2 { margin: 0; color: var(--color-primary); font-size: 22px; }
    .content-cell { max-width: 300px; }
    .empty-state { text-align: center; padding: 48px; color: var(--text-dimmed); }
    .icon-success { color: var(--color-success); }
    .action-buttons { display: flex; gap: 2px; }
  `],
})
export class ReportedPostsComponent implements OnInit {
  readonly moderationService = inject(ModerationService);
  private readonly snackBar = inject(MatSnackBar);

  readonly reportedPosts = signal<Report[]>([]);

  private readonly reasonLabels: Record<string, string> = {
    spam: 'Spam', inappropriate: 'Inapropiado', harassment: 'Acoso',
    hate_speech: 'Discurso de odio', misinformation: 'Desinformación', other: 'Otro',
  };

  reasonLabel(key: string): string { return this.reasonLabels[key] ?? key; }

  ngOnInit(): void {
    this.loadData();
  }

  loadData(): void {
    this.moderationService.loadReports({ status: 'pending', limit: 50 }).subscribe({
      next: (res) => {
        this.reportedPosts.set(res.items.filter((r) => r.post_id !== null));
      },
    });
  }

  deletePost(report: Report): void {
    if (!report.post_id) return;
    if (!confirm('¿Eliminar este post permanentemente?')) return;
    this.moderationService.deletePost(report.post_id).subscribe({
      next: () => {
        this.moderationService.updateReportStatus(report.id, 'resolved').subscribe();
        this.snackBar.open('Post eliminado', 'OK', { duration: 3000 });
        this.loadData();
      },
      error: (err) => this.snackBar.open(err.error?.detail || 'Error', 'OK', { duration: 3000 }),
    });
  }

  dismissReport(report: Report): void {
    this.moderationService.updateReportStatus(report.id, 'dismissed').subscribe({
      next: () => {
        this.snackBar.open('Reporte descartado', 'OK', { duration: 3000 });
        this.loadData();
      },
      error: (err) => this.snackBar.open(err.error?.detail || 'Error', 'OK', { duration: 3000 }),
    });
  }
}
