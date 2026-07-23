import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucideEye,
  LucideCheckCircle,
  LucideXCircle,
  LucideChevronLeft,
  LucideChevronRight,
} from '@lucide/angular';

import { ModerationService } from '../../../core/services/moderation.service';
import { Report } from '../../../core/models/social.model';
import { ReportDetailDialogComponent } from '../report-detail-dialog/report-detail-dialog.component';

@Component({
  selector: 'app-reports-list',
  standalone: true,
  imports: [
    CommonModule, FormsModule,
    LucideEye, LucideCheckCircle, LucideXCircle, LucideChevronLeft, LucideChevronRight,
  ],
  template: `
    <div class="reports-list">
      <div class="header-row">
        <h2>Reportes</h2>
      </div>

      <div class="filters-row">
        <div class="form-group filter-field">
          <label>Estado</label>
          <select class="form-select" [(ngModel)]="selectedStatus" (change)="applyFilters()">
            <option value="">Todos</option>
            <option value="pending">Pendiente</option>
            <option value="reviewed">Revisado</option>
            <option value="resolved">Resuelto</option>
            <option value="dismissed">Descartado</option>
          </select>
        </div>

        <div class="form-group filter-field">
          <label>Motivo</label>
          <select class="form-select" [(ngModel)]="selectedReason" (change)="applyFilters()">
            <option value="">Todos</option>
            <option value="spam">Spam</option>
            <option value="inappropriate">Inapropiado</option>
            <option value="harassment">Acoso</option>
            <option value="misinformation">Desinformación</option>
            <option value="other">Otro</option>
          </select>
        </div>
      </div>

      <div class="table-container">
        <table class="table">
          <thead>
            <tr>
              <th>Reportado por</th>
              <th>Motivo</th>
              <th>Objetivo</th>
              <th>Estado</th>
              <th>Fecha</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            @for (r of moderationService.reports(); track r.id) {
              <tr>
                <td>{{ r.reporter.full_name }}</td>
                <td><span class="chip" [class]="'chip-reason-' + r.reason">{{ reasonLabel(r.reason) }}</span></td>
                <td>
                  @if (r.post_id) {
                    Post: {{ (r.post_content ?? '') | slice:0:40 }}{{ (r.post_content?.length ?? 0) > 40 ? '...' : '' }}
                  } @else if (r.comment_id) {
                    Comentario: {{ (r.comment_content ?? '') | slice:0:40 }}{{ (r.comment_content?.length ?? 0) > 40 ? '...' : '' }}
                  } @else if (r.reported_user_id) {
                    Usuario: &#64;{{ r.reported_username ?? 'desconocido' }}
                  }
                </td>
                <td><span class="chip" [class]="'chip-status-' + r.status">{{ statusLabel(r.status) }}</span></td>
                <td>{{ r.created_at | date:'short' }}</td>
                <td>
                  <div class="action-buttons">
                    <button class="btn-icon" title="Ver detalle" (click)="openDetail(r)">
                      <svg lucideEye [size]="16"></svg>
                    </button>
                    @if (r.status === 'pending') {
                      <button class="btn-icon success" title="Resolver" (click)="resolve(r)">
                        <svg lucideCheckCircle [size]="16"></svg>
                      </button>
                      <button class="btn-icon" title="Descartar" (click)="dismiss(r)">
                        <svg lucideXCircle [size]="16"></svg>
                      </button>
                    }
                  </div>
                </td>
              </tr>
            }
          </tbody>
        </table>
      </div>

      <!-- Paginación -->
      <div class="pagination">
        <span>{{ moderationService.totalReports() }} resultados</span>
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
    .reports-list { }
    .header-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
    .header-row h2 { margin: 0; color: var(--color-primary); font-size: 22px; }
    .filters-row { display: flex; gap: 16px; margin-bottom: 16px; }
    .filter-field { min-width: 180px; }
    .action-buttons { display: flex; gap: 2px; }

    .chip-reason-spam { background: var(--color-error-subtle); color: var(--color-error); }
    .chip-reason-harassment { background: rgba(249, 115, 22, 0.15); color: var(--color-orange); }
    .chip-reason-inappropriate { background: var(--color-warning-subtle); color: var(--color-warning); }
    .chip-reason-hate_speech { background: rgba(239, 68, 68, 0.15); color: #f87171; }
    .chip-reason-misinformation { background: var(--color-primary-subtle); color: var(--color-primary); }
    .chip-reason-other { background: var(--bg-muted); color: var(--text-secondary); }

    .chip-status-pending { background: var(--color-warning-subtle); color: var(--color-warning); }
    .chip-status-reviewed { background: var(--color-primary-subtle); color: var(--color-primary); }
    .chip-status-resolved { background: var(--color-success-subtle); color: var(--color-success); }
    .chip-status-dismissed { background: var(--bg-muted); color: var(--text-secondary); }
  `],
})
export class ReportsListComponent implements OnInit {
  readonly moderationService = inject(ModerationService);
  private readonly snackBar = inject(MatSnackBar);
  private readonly dialog = inject(MatDialog);

  selectedStatus = '';
  selectedReason = '';

  private readonly reasonLabels: Record<string, string> = {
    spam: 'Spam', inappropriate: 'Inapropiado', harassment: 'Acoso',
    hate_speech: 'Discurso de odio', misinformation: 'Desinformación', other: 'Otro',
  };
  private readonly statusLabels: Record<string, string> = {
    pending: 'Pendiente', reviewed: 'Revisado', resolved: 'Resuelto', dismissed: 'Descartado',
  };

  reasonLabel(key: string): string { return this.reasonLabels[key] ?? key; }
  statusLabel(key: string): string { return this.statusLabels[key] ?? key; }
  pageSize = 10;
  currentPage = 1;

  ngOnInit(): void {
    this.loadData();
  }

  totalPages(): number {
    return Math.max(1, Math.ceil(this.moderationService.totalReports() / this.pageSize));
  }

  loadData(): void {
    this.moderationService.loadReports({
      page: this.currentPage,
      limit: this.pageSize,
      status: this.selectedStatus || undefined,
      reason: this.selectedReason || undefined,
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

  openDetail(report: Report): void {
    this.dialog.open(ReportDetailDialogComponent, {
      data: report,
      width: '600px',
    }).afterClosed().subscribe((result) => {
      if (result) this.loadData();
    });
  }

  resolve(report: Report): void {
    this.moderationService.updateReportStatus(report.id, 'resolved').subscribe({
      next: () => {
        this.snackBar.open('Reporte resuelto', 'OK', { duration: 3000 });
        this.loadData();
      },
      error: (err) => this.snackBar.open(err.error?.detail || 'Error', 'OK', { duration: 3000 }),
    });
  }

  dismiss(report: Report): void {
    this.moderationService.updateReportStatus(report.id, 'dismissed').subscribe({
      next: () => {
        this.snackBar.open('Reporte descartado', 'OK', { duration: 3000 });
        this.loadData();
      },
      error: (err) => this.snackBar.open(err.error?.detail || 'Error', 'OK', { duration: 3000 }),
    });
  }
}
