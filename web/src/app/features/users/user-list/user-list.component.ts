import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucideSearch,
  LucideX,
  LucideEye,
  LucideBan,
  LucideCheckCircle,
  LucideChevronLeft,
  LucideChevronRight,
  LucideLoader,
  LucideDownload,
} from '@lucide/angular';

import { UserAdminService } from '../../../core/services/user-admin.service';
import { CsvExportService } from '../../../core/services/csv-export.service';
import { AdminUser } from '../../../core/models/admin-user.model';
import { UserDetailDialogComponent } from '../user-detail-dialog/user-detail-dialog.component';

@Component({
  selector: 'app-user-list',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    LucideSearch, LucideX, LucideEye, LucideBan, LucideCheckCircle,
    LucideChevronLeft, LucideChevronRight, LucideLoader, LucideDownload,
  ],
  template: `
    <div class="page-header">
      <h2 class="page-title">Gestión de Usuarios</h2>
      <div class="header-right">
        <span class="total-badge">{{ userService.totalUsers() }} usuarios</span>
        <button class="btn btn-ghost export-btn"
                [disabled]="csvExport.downloading() === 'users.csv'"
                (click)="exportCsv()">
          <svg lucideDownload [size]="16"></svg> Exportar CSV
        </button>
      </div>
    </div>

    <!-- Filtros -->
    <div class="filters-row">
      <div class="form-group search-field">
        <div class="input-wrapper">
          <input
            class="form-input"
            [(ngModel)]="searchTerm"
            (keyup.enter)="applyFilters()"
            placeholder="Buscar por nombre, email o username..."
          />
          <svg lucideSearch [size]="16" class="input-trail-icon"></svg>
        </div>
      </div>

      <div class="form-group filter-field">
        <select class="form-select" [(ngModel)]="filterBanned" (change)="applyFilters()">
          <option [ngValue]="undefined">Todos los estados</option>
          <option [ngValue]="false">Activos</option>
          <option [ngValue]="true">Baneados</option>
        </select>
      </div>

      <div class="form-group filter-field">
        <select class="form-select" [(ngModel)]="filterAdmin" (change)="applyFilters()">
          <option [ngValue]="undefined">Todos los roles</option>
          <option [ngValue]="true">Admin</option>
          <option [ngValue]="false">Usuario</option>
        </select>
      </div>

      <button class="btn btn-ghost" (click)="clearFilters()">
        <svg lucideX [size]="16"></svg> Limpiar
      </button>
    </div>

    @if (userService.isLoading()) {
      <div class="loading-container">
        <svg lucideLoader [size]="32" class="spinner icon-primary"></svg>
      </div>
    }

    @if (!userService.isLoading()) {
      <div class="table-container">
        <table class="table">
          <thead>
            <tr>
              <th>Usuario</th>
              <th>Email</th>
              <th>Nivel</th>
              <th>Posts / Seguidores</th>
              <th>Estado</th>
              <th>Registro</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            @for (u of userService.users(); track u.id) {
              <tr>
                <td>
                  <div class="user-cell">
                    <div class="avatar" [style.backgroundImage]="'url(' + (u.avatar_url || 'https://ui-avatars.com/api/?name=' + u.full_name + '&background=06b6d4&color=fff') + ')'"></div>
                    <div>
                      <span class="username">{{ u.username }}</span>
                      <span class="fullname">{{ u.full_name }}</span>
                    </div>
                  </div>
                </td>
                <td>{{ u.email }}</td>
                <td><span class="level-badge">Lv. {{ u.xp_level }}</span></td>
                <td>{{ u.posts_count }} / {{ u.followers_count }}</td>
                <td>
                  @if (u.is_admin) {
                    <span class="chip chip-purple">Admin</span>
                  }
                  @if (u.is_banned) {
                    <span class="chip chip-solid-error">Baneado</span>
                  }
                  @if (!u.is_banned && !u.is_admin) {
                    <span class="chip chip-solid-success">Activo</span>
                  }
                </td>
                <td>{{ u.created_at | date: 'dd/MM/yyyy' }}</td>
                <td>
                  <div class="action-buttons">
                    <button class="btn-icon" title="Ver detalle" (click)="openDetail(u)">
                      <svg lucideEye [size]="16"></svg>
                    </button>
                    @if (!u.is_banned) {
                      <button class="btn-icon danger" title="Banear" (click)="banUser(u)">
                        <svg lucideBan [size]="16"></svg>
                      </button>
                    } @else {
                      <button class="btn-icon success" title="Desbanear" (click)="unbanUser(u)">
                        <svg lucideCheckCircle [size]="16"></svg>
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
        <span>{{ userService.totalUsers() }} resultados</span>
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

    .page-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px; }
    .page-title { color: var(--color-primary); font-size: 22px; margin: 0; }
    .header-right { display: flex; align-items: center; gap: 12px; }
    .total-badge { font-size: 13px; color: var(--text-muted); background: var(--bg-border); padding: 4px 12px; border-radius: 12px; }
    .export-btn { display: inline-flex; align-items: center; gap: 6px; }

    .filters-row { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; margin-bottom: 16px; }
    .search-field { flex: 1; min-width: 220px; }
    .filter-field { width: 180px; }

    .input-wrapper { position: relative; }
    .input-trail-icon { position: absolute; right: 12px; top: 50%; transform: translateY(-50%); color: var(--text-dimmed); pointer-events: none; }

    .loading-container { display: flex; justify-content: center; padding: 64px; }
    .spinner { animation: spin 1s linear infinite; }
    @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

    .user-cell { display: flex; align-items: center; gap: 10px; }
    .avatar { width: 36px; height: 36px; border-radius: 50%; background-size: cover; background-position: center; background-color: var(--bg-muted); flex-shrink: 0; }
    .username { display: block; font-weight: 500; color: var(--color-primary); font-size: 14px; }
    .fullname { display: block; font-size: 12px; color: var(--text-dimmed); }
    .level-badge { background: linear-gradient(135deg, var(--color-primary), var(--color-success)); color: #fff; padding: 2px 10px; border-radius: 10px; font-size: 12px; font-weight: 600; white-space: nowrap; }

    .action-buttons { display: flex; gap: 2px; }
  `],
})
export class UserListComponent implements OnInit {
  readonly userService = inject(UserAdminService);
  readonly csvExport = inject(CsvExportService);
  private readonly dialog = inject(MatDialog);
  private readonly snackBar = inject(MatSnackBar);

  pageSize = 20;
  currentPage = 1;
  searchTerm = '';
  filterBanned: boolean | undefined = undefined;
  filterAdmin: boolean | undefined = undefined;

  ngOnInit(): void {
    this.loadUsers();
  }

  totalPages(): number {
    return Math.max(1, Math.ceil(this.userService.totalUsers() / this.pageSize));
  }

  applyFilters(): void {
    this.currentPage = 1;
    this.loadUsers();
  }

  clearFilters(): void {
    this.searchTerm = '';
    this.filterBanned = undefined;
    this.filterAdmin = undefined;
    this.currentPage = 1;
    this.loadUsers();
  }

  changePage(delta: number): void {
    this.currentPage += delta;
    this.loadUsers();
  }

  exportCsv(): void {
    this.csvExport.exportUsers({
      search: this.searchTerm || undefined,
      is_banned: this.filterBanned,
      is_admin: this.filterAdmin,
    });
  }

  openDetail(user: AdminUser): void {
    const dialogRef = this.dialog.open(UserDetailDialogComponent, {
      width: '520px',
      data: user,
    });

    dialogRef.afterClosed().subscribe((result) => {
      if (result === 'refresh') {
        this.loadUsers();
      }
    });
  }

  banUser(user: AdminUser): void {
    const reason = prompt('Motivo del baneo:');
    if (!reason) return;

    this.userService.banUser(user.id, reason).subscribe({
      next: () => {
        this.snackBar.open(user.username + ' baneado', 'OK', { duration: 3000 });
        this.loadUsers();
      },
      error: () => this.snackBar.open('Error al banear usuario', 'OK', { duration: 3000 }),
    });
  }

  unbanUser(user: AdminUser): void {
    this.userService.unbanUser(user.id).subscribe({
      next: () => {
        this.snackBar.open(user.username + ' desbaneado', 'OK', { duration: 3000 });
        this.loadUsers();
      },
      error: () => this.snackBar.open('Error al desbanear usuario', 'OK', { duration: 3000 }),
    });
  }

  private loadUsers(): void {
    this.userService.loadUsers({
      page: this.currentPage,
      limit: this.pageSize,
      search: this.searchTerm || undefined,
      is_banned: this.filterBanned,
      is_admin: this.filterAdmin,
    }).subscribe();
  }
}
