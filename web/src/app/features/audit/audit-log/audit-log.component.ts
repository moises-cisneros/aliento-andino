import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  LucideScrollText,
  LucideChevronLeft,
  LucideChevronRight,
  LucideLoader,
  LucideX,
} from '@lucide/angular';

import {
  AuditAdminService,
  AuditLogEntry,
} from '../../../core/services/audit-admin.service';

interface ActionMeta {
  label: string;
  chip: string; // clase de color del chip
}

@Component({
  selector: 'app-audit-log',
  standalone: true,
  imports: [
    CommonModule, FormsModule,
    LucideScrollText, LucideChevronLeft, LucideChevronRight, LucideLoader, LucideX,
  ],
  template: `
    <div class="page-header">
      <h2 class="page-title"><svg lucideScrollText [size]="20"></svg> Auditoría</h2>
      <span class="total-badge">{{ total() }} registros</span>
    </div>

    <div class="notice">
      Registro de las acciones del panel admin: bans, cambios de rol, suscripciones,
      moderación, configuración y anuncios. Las acciones nuevas aparecen primero.
    </div>

    <!-- Filtros -->
    <div class="filters-row">
      <div class="form-group filter-field">
        <select class="form-select" [(ngModel)]="filterAction" (change)="applyFilters()">
          <option value="">Todas las acciones</option>
          @for (a of knownActions; track a) {
            <option [value]="a">{{ actionMeta(a).label }}</option>
          }
        </select>
      </div>
      <div class="form-group filter-field">
        <select class="form-select" [(ngModel)]="filterTarget" (change)="applyFilters()">
          <option value="">Todos los objetivos</option>
          <option value="user">Usuario</option>
          <option value="subscription">Suscripción</option>
          <option value="post">Post</option>
          <option value="comment">Comentario</option>
          <option value="report">Reporte</option>
          <option value="config">Configuración</option>
          <option value="announcement">Anuncio</option>
        </select>
      </div>
      <button class="btn btn-ghost" (click)="clearFilters()">
        <svg lucideX [size]="16"></svg> Limpiar
      </button>
    </div>

    @if (loading()) {
      <div class="loading-container"><svg lucideLoader [size]="32" class="spinner icon-primary"></svg></div>
    } @else {
      <div class="table-container">
        <table class="table">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Admin</th>
              <th>Acción</th>
              <th>Objetivo</th>
              <th>Detalle</th>
            </tr>
          </thead>
          <tbody>
            @for (e of entries(); track e.id) {
              <tr>
                <td class="nowrap">{{ e.created_at | date: 'dd/MM/yyyy HH:mm' }}</td>
                <td>{{ e.admin_email || '—' }}</td>
                <td><span class="chip" [class]="actionMeta(e.action).chip">{{ actionMeta(e.action).label }}</span></td>
                <td>
                  @if (e.target_type) {
                    <span class="target-type">{{ e.target_type }}</span>
                    @if (e.target_id) { <span class="target-id">{{ e.target_id }}</span> }
                  } @else { — }
                </td>
                <td class="detail">{{ formatDetail(e.detail) }}</td>
              </tr>
            }
            @if (entries().length === 0) {
              <tr><td colspan="5" class="empty">Sin registros de auditoría.</td></tr>
            }
          </tbody>
        </table>
      </div>

      <div class="pagination">
        <span>{{ total() }} resultados</span>
        <button [disabled]="currentPage <= 1" (click)="changePage(-1)">
          <svg lucideChevronLeft [size]="16"></svg>
        </button>
        <span>{{ currentPage }} / {{ totalPages() }}</span>
        <button [disabled]="currentPage >= totalPages()" (click)="changePage(1)">
          <svg lucideChevronRight [size]="16"></svg>
        </button>
      </div>
    }
  `,
  styles: [`
    :host { display: block; }
    .page-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }
    .page-title { color: var(--color-primary); font-size: 22px; margin: 0; display: flex; align-items: center; gap: 8px; }
    .total-badge { font-size: 13px; color: var(--text-muted); background: var(--bg-elevated); padding: 4px 12px; border-radius: 12px; }
    .notice { font-size: 13px; color: var(--text-muted); background: var(--bg-surface-alt); border: 1px solid var(--bg-border); border-radius: 10px; padding: 10px 14px; margin-bottom: 20px; }

    .filters-row { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; margin-bottom: 16px; }
    .filter-field { width: 220px; }

    .loading-container { display: flex; justify-content: center; padding: 64px; }
    .spinner { animation: spin 1s linear infinite; }
    @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

    .nowrap { white-space: nowrap; color: var(--text-muted); font-size: 13px; }
    .chip { padding: 2px 10px; border-radius: 10px; font-size: 12px; font-weight: 600; white-space: nowrap; }
    .chip-danger { background: var(--color-warning-subtle); color: var(--color-warning); }
    .chip-success { background: var(--color-success-subtle); color: var(--color-success); }
    .chip-info { background: var(--color-primary-subtle); color: var(--color-primary); }
    .chip-neutral { background: var(--bg-elevated); color: var(--text-secondary); }

    .target-type { font-size: 12px; color: var(--text-secondary); text-transform: capitalize; }
    .target-id { display: block; font-size: 11px; color: var(--text-dimmed); font-family: monospace; }
    .detail { font-size: 12px; color: var(--text-muted); max-width: 320px; }
    .empty { text-align: center; color: var(--text-dimmed); padding: 32px; }
  `],
})
export class AuditLogComponent implements OnInit {
  private readonly svc = inject(AuditAdminService);

  readonly entries = signal<AuditLogEntry[]>([]);
  readonly total = signal(0);
  readonly pages = signal(1);
  readonly loading = signal(true);

  currentPage = 1;
  filterAction = '';
  filterTarget = '';

  readonly knownActions = [
    'user.ban', 'user.unban', 'user.grant_admin', 'user.revoke_admin',
    'user.reset_password', 'subscription.grant', 'subscription.cancel',
    'post.delete', 'comment.delete', 'report.update', 'config.update',
    'announcement.send',
  ];

  private readonly meta: Record<string, ActionMeta> = {
    'user.ban': { label: 'Baneo de usuario', chip: 'chip-danger' },
    'user.unban': { label: 'Desbaneo de usuario', chip: 'chip-success' },
    'user.grant_admin': { label: 'Otorga admin', chip: 'chip-info' },
    'user.revoke_admin': { label: 'Quita admin', chip: 'chip-neutral' },
    'user.reset_password': { label: 'Reset de contraseña', chip: 'chip-neutral' },
    'subscription.grant': { label: 'Otorga premium', chip: 'chip-success' },
    'subscription.cancel': { label: 'Cancela suscripción', chip: 'chip-danger' },
    'post.delete': { label: 'Elimina post', chip: 'chip-danger' },
    'comment.delete': { label: 'Elimina comentario', chip: 'chip-danger' },
    'report.update': { label: 'Actualiza reporte', chip: 'chip-info' },
    'config.update': { label: 'Cambia configuración', chip: 'chip-info' },
    'announcement.send': { label: 'Envía anuncio', chip: 'chip-info' },
  };

  ngOnInit(): void {
    this.load();
  }

  actionMeta(action: string): ActionMeta {
    return this.meta[action] ?? { label: action, chip: 'chip-neutral' };
  }

  formatDetail(detail: Record<string, unknown> | null): string {
    if (!detail) return '—';
    return Object.entries(detail)
      .map(([k, v]) => `${k}: ${v}`)
      .join(' · ');
  }

  totalPages(): number {
    return Math.max(1, this.pages());
  }

  applyFilters(): void {
    this.currentPage = 1;
    this.load();
  }

  clearFilters(): void {
    this.filterAction = '';
    this.filterTarget = '';
    this.currentPage = 1;
    this.load();
  }

  changePage(delta: number): void {
    this.currentPage += delta;
    this.load();
  }

  private load(): void {
    this.loading.set(true);
    this.svc.list({
      page: this.currentPage,
      limit: 30,
      action: this.filterAction || undefined,
      target_type: this.filterTarget || undefined,
    }).subscribe({
      next: (res) => {
        this.entries.set(res.items);
        this.total.set(res.total);
        this.pages.set(res.pages);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }
}
