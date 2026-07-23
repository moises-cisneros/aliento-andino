import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucideSearch,
  LucideX,
  LucideChevronLeft,
  LucideChevronRight,
  LucideLoader,
  LucideCrown,
  LucideUsers,
  LucideClock,
  LucideTrendingUp,
  LucideDownload,
} from '@lucide/angular';

import { SubscriptionAdminService } from '../../../core/services/subscription-admin.service';
import { CsvExportService } from '../../../core/services/csv-export.service';
import { AdminSubscription } from '../../../core/models/subscription.model';

@Component({
  selector: 'app-subscription-list',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    LucideSearch, LucideX, LucideChevronLeft, LucideChevronRight, LucideLoader,
    LucideCrown, LucideUsers, LucideClock, LucideTrendingUp, LucideDownload,
  ],
  template: `
    <div class="page-header">
      <h2 class="page-title">Suscripciones</h2>
      <div class="header-right">
        <span class="total-badge">{{ svc.total() }} usuarios</span>
        <button class="btn btn-ghost export-btn"
                [disabled]="csvExport.downloading() === 'subscriptions.csv'"
                (click)="exportCsv()">
          <svg lucideDownload [size]="16"></svg> Exportar CSV
        </button>
      </div>
    </div>

    <!-- Aviso: pagos simulados -->
    <div class="notice">
      Los pagos son <strong>simulados</strong> (sin pasarela real ni facturas). Se muestra el
      estado de suscripción por usuario; los ingresos son <strong>estimados</strong>.
    </div>

    <!-- KPIs -->
    @if (svc.summary(); as s) {
      <div class="kpi-row">
        <div class="kpi-card">
          <div class="kpi-icon premium"><svg lucideCrown [size]="18"></svg></div>
          <div>
            <span class="kpi-value">{{ s.premium_active }}</span>
            <span class="kpi-label">Premium activos</span>
          </div>
        </div>
        <div class="kpi-card">
          <div class="kpi-icon"><svg lucideUsers [size]="18"></svg></div>
          <div>
            <span class="kpi-value">{{ s.free }}</span>
            <span class="kpi-label">Gratuitos</span>
          </div>
        </div>
        <div class="kpi-card">
          <div class="kpi-icon trial"><svg lucideClock [size]="18"></svg></div>
          <div>
            <span class="kpi-value">{{ s.trial }}</span>
            <span class="kpi-label">En prueba gratis</span>
          </div>
        </div>
        <div class="kpi-card">
          <div class="kpi-icon revenue"><svg lucideTrendingUp [size]="18"></svg></div>
          <div>
            <span class="kpi-value">\${{ s.estimated_mrr_usd | number: '1.2-2' }}</span>
            <span class="kpi-label">MRR estimado · mensual {{ s.monthly }} / anual {{ s.annual }}</span>
          </div>
        </div>
      </div>
    }

    <!-- Filtros -->
    <div class="filters-row">
      <div class="form-group search-field">
        <div class="input-wrapper">
          <input
            class="form-input"
            [(ngModel)]="searchTerm"
            (keyup.enter)="applyFilters()"
            placeholder="Buscar por email, usuario o nombre..."
          />
          <svg lucideSearch [size]="16" class="input-trail-icon"></svg>
        </div>
      </div>

      <div class="form-group filter-field">
        <select class="form-select" [(ngModel)]="filterStatus" (change)="applyFilters()">
          <option value="">Todos los estados</option>
          <option value="premium">Premium</option>
          <option value="free">Gratuitos</option>
        </select>
      </div>

      <div class="form-group filter-field">
        <select class="form-select" [(ngModel)]="filterPlan" (change)="applyFilters()">
          <option value="">Todos los planes</option>
          <option value="monthly">Mensual</option>
          <option value="annual">Anual</option>
          <option value="trial">Prueba gratis</option>
        </select>
      </div>

      <button class="btn btn-ghost" (click)="clearFilters()">
        <svg lucideX [size]="16"></svg> Limpiar
      </button>
    </div>

    @if (svc.isLoading()) {
      <div class="loading-container">
        <svg lucideLoader [size]="32" class="spinner icon-primary"></svg>
      </div>
    }

    @if (!svc.isLoading()) {
      <div class="table-container">
        <table class="table">
          <thead>
            <tr>
              <th>Usuario</th>
              <th>Estado</th>
              <th>Plan</th>
              <th>Inicio</th>
              <th>Vence</th>
              <th>Días restantes</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            @for (sub of svc.subscriptions(); track sub.id) {
              <tr>
                <td>
                  <div>
                    <span class="username">{{ sub.username }}</span>
                    <span class="fullname">{{ sub.email }}</span>
                  </div>
                </td>
                <td>
                  @if (sub.is_premium) {
                    <span class="chip chip-solid-success">Premium</span>
                  } @else if (sub.subscription_status === 'premium') {
                    <span class="chip chip-solid-warning">Vencido</span>
                  } @else {
                    <span class="chip">Gratuito</span>
                  }
                </td>
                <td>{{ sub.plan_label || '—' }}</td>
                <td>{{ sub.subscription_started_at ? (sub.subscription_started_at | date: 'dd/MM/yyyy') : '—' }}</td>
                <td>{{ sub.subscription_expires_at ? (sub.subscription_expires_at | date: 'dd/MM/yyyy') : '—' }}</td>
                <td>
                  @if (sub.is_premium && sub.days_until_expiry !== null) {
                    <span [class.expiring]="sub.days_until_expiry <= 7">{{ sub.days_until_expiry }} días</span>
                  } @else {
                    —
                  }
                </td>
                <td>
                  @if (sub.is_premium) {
                    <button class="btn btn-ghost grant-btn" (click)="cancel(sub)">Cancelar</button>
                  } @else {
                    <div class="grant-action">
                      <select class="form-select grant-select" [(ngModel)]="grantPlans[sub.id]">
                        <option value="monthly">Mensual</option>
                        <option value="annual">Anual</option>
                        <option value="trial">Prueba</option>
                      </select>
                      <button class="btn btn-ghost grant-btn" (click)="grant(sub)">Dar premium</button>
                    </div>
                  }
                </td>
              </tr>
            }
            @if (svc.subscriptions().length === 0) {
              <tr><td colspan="7" class="empty">No hay suscripciones que coincidan.</td></tr>
            }
          </tbody>
        </table>
      </div>

      <!-- Paginación -->
      <div class="pagination">
        <span>{{ svc.total() }} resultados</span>
        <select [(ngModel)]="pageSize" (change)="applyFilters()">
          <option [value]="10">10</option>
          <option [value]="20">20</option>
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
    }
  `,
  styles: [`
    :host { display: block; }

    .page-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }
    .header-right { display: flex; align-items: center; gap: 12px; }
    .export-btn { display: inline-flex; align-items: center; gap: 6px; }
    .page-title { color: var(--color-primary); font-size: 22px; margin: 0; }
    .total-badge { font-size: 13px; color: var(--text-muted); background: var(--bg-elevated); padding: 4px 12px; border-radius: 12px; }

    .notice { font-size: 13px; color: var(--text-muted); background: var(--bg-surface-alt); border: 1px solid var(--bg-border); border-radius: 10px; padding: 10px 14px; margin-bottom: 16px; }

    .kpi-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin-bottom: 20px; }
    .kpi-card { display: flex; align-items: center; gap: 12px; background: var(--bg-surface); border: 1px solid var(--bg-border); border-radius: 12px; padding: 14px 16px; }
    .kpi-icon { width: 38px; height: 38px; border-radius: 10px; display: flex; align-items: center; justify-content: center; background: var(--bg-elevated); color: var(--text-muted); flex-shrink: 0; }
    .kpi-icon.premium { background: var(--color-success-subtle); color: var(--color-success); }
    .kpi-icon.trial { background: var(--color-warning-subtle); color: var(--color-warning); }
    .kpi-icon.revenue { background: var(--color-primary-subtle); color: var(--color-primary); }
    .kpi-value { display: block; font-size: 22px; font-weight: 700; color: var(--text-primary); line-height: 1.1; }
    .kpi-label { display: block; font-size: 11.5px; color: var(--text-dimmed); margin-top: 2px; }

    .filters-row { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; margin-bottom: 16px; }
    .search-field { flex: 1; min-width: 220px; }
    .filter-field { width: 180px; }
    .input-wrapper { position: relative; }
    .input-trail-icon { position: absolute; right: 12px; top: 50%; transform: translateY(-50%); color: var(--text-dimmed); pointer-events: none; }

    .loading-container { display: flex; justify-content: center; padding: 64px; }
    .spinner { animation: spin 1s linear infinite; }
    @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

    .username { display: block; font-weight: 500; color: var(--color-primary); font-size: 14px; }
    .fullname { display: block; font-size: 12px; color: var(--text-dimmed); }
    .chip-solid-warning { background: var(--color-warning); color: #fff; }
    .expiring { color: var(--color-warning); font-weight: 600; }
    .empty { text-align: center; color: var(--text-dimmed); padding: 32px; }

    .grant-action { display: flex; gap: 6px; align-items: center; }
    .grant-select { height: 32px; padding: 2px 8px; font-size: 12px; width: auto; min-width: 92px; }
    .grant-btn { padding: 5px 10px; font-size: 12px; white-space: nowrap; }
  `],
})
export class SubscriptionListComponent implements OnInit {
  readonly svc = inject(SubscriptionAdminService);
  readonly csvExport = inject(CsvExportService);
  private readonly snackBar = inject(MatSnackBar);

  pageSize = 20;
  currentPage = 1;
  searchTerm = '';
  filterStatus = '';
  filterPlan = '';
  // Plan elegido para "Dar premium", por fila (id de usuario → plan).
  grantPlans: Record<string, string> = {};

  ngOnInit(): void {
    this.refresh();
  }

  grant(sub: AdminSubscription): void {
    const plan = this.grantPlans[sub.id] || 'monthly';
    this.svc.grant(sub.id, plan).subscribe({
      next: () => {
        this.snackBar.open(`Premium otorgado a ${sub.username}`, 'OK', { duration: 3000 });
        this.refresh();
      },
      error: () => this.snackBar.open('Error al otorgar premium', 'OK', { duration: 3000 }),
    });
  }

  cancel(sub: AdminSubscription): void {
    if (!confirm(`¿Cancelar la suscripción de ${sub.username}?`)) return;
    this.svc.cancel(sub.id).subscribe({
      next: () => {
        this.snackBar.open(`Suscripción de ${sub.username} cancelada`, 'OK', { duration: 3000 });
        this.refresh();
      },
      error: () => this.snackBar.open('Error al cancelar', 'OK', { duration: 3000 }),
    });
  }

  private refresh(): void {
    this.svc.loadSummary().subscribe();
    this.load();
  }

  totalPages(): number {
    return Math.max(1, Math.ceil(this.svc.total() / this.pageSize));
  }

  applyFilters(): void {
    this.currentPage = 1;
    this.load();
  }

  clearFilters(): void {
    this.searchTerm = '';
    this.filterStatus = '';
    this.filterPlan = '';
    this.currentPage = 1;
    this.load();
  }

  changePage(delta: number): void {
    this.currentPage += delta;
    this.load();
  }

  exportCsv(): void {
    this.csvExport.exportSubscriptions({
      search: this.searchTerm || undefined,
      status: this.filterStatus || undefined,
      plan: this.filterPlan || undefined,
    });
  }

  private load(): void {
    this.svc.loadSubscriptions({
      page: this.currentPage,
      limit: this.pageSize,
      search: this.searchTerm || undefined,
      status: this.filterStatus || undefined,
      plan: this.filterPlan || undefined,
    }).subscribe();
  }
}
