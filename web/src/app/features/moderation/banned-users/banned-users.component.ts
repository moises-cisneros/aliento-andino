import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucideShieldCheck,
  LucideUnlock,
} from '@lucide/angular';

import { ModerationService } from '../../../core/services/moderation.service';

interface BannedUserRow {
  id: string;
  username: string;
  full_name: string;
  ban_reason: string | null;
}

@Component({
  selector: 'app-banned-users',
  standalone: true,
  imports: [CommonModule, LucideShieldCheck, LucideUnlock],
  template: `
    <div class="banned-users">
      <div class="header-row">
        <h2>Usuarios baneados</h2>
      </div>

      @if (bannedUsers().length === 0) {
        <div class="empty-state">
          <svg lucideShieldCheck [size]="48" class="icon-success"></svg>
          <p>No hay usuarios baneados</p>
        </div>
      } @else {
        <div class="table-container">
          <table class="table">
            <thead>
              <tr>
                <th>Nombre</th>
                <th>Usuario</th>
                <th>Motivo</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              @for (u of bannedUsers(); track u.id) {
                <tr>
                  <td>{{ u.full_name }}</td>
                  <td>&#64;{{ u.username }}</td>
                  <td>{{ u.ban_reason ?? 'Sin especificar' }}</td>
                  <td>
                    <button class="btn btn-primary btn-sm" (click)="unbanUser(u)">
                      <svg lucideUnlock [size]="14"></svg> Desbanear
                    </button>
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
    .banned-users { }
    .header-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
    .header-row h2 { margin: 0; color: var(--color-primary); font-size: 22px; }
    .empty-state { text-align: center; padding: 48px; color: var(--text-dimmed); }
    .icon-success { color: var(--color-success); }
  `],
})
export class BannedUsersComponent implements OnInit {
  private readonly moderationService = inject(ModerationService);
  private readonly snackBar = inject(MatSnackBar);

  readonly bannedUsers = signal<BannedUserRow[]>([]);

  ngOnInit(): void {
    this.loadBannedUsers();
  }

  loadBannedUsers(): void {
    this.moderationService.loadSocialStats().subscribe();
    this.moderationService.loadReports({ status: 'resolved', limit: 100 }).subscribe({
      next: (res) => {
        const seen = new Set<string>();
        const rows: BannedUserRow[] = [];
        for (const r of res.items) {
          if (r.reported_user_id && r.reported_username && !seen.has(r.reported_user_id)) {
            seen.add(r.reported_user_id);
            rows.push({
              id: r.reported_user_id,
              username: r.reported_username,
              full_name: r.reported_username,
              ban_reason: r.description,
            });
          }
        }
        this.bannedUsers.set(rows);
      },
    });
  }

  unbanUser(user: BannedUserRow): void {
    if (!confirm('¿Desbanear a ' + user.full_name + '?')) return;
    this.moderationService.unbanUser(user.id).subscribe({
      next: () => {
        this.snackBar.open(user.full_name + ' desbaneado', 'OK', { duration: 3000 });
        this.bannedUsers.set(this.bannedUsers().filter((u) => u.id !== user.id));
      },
      error: (err) => this.snackBar.open(err.error?.detail || 'Error', 'OK', { duration: 3000 }),
    });
  }
}
