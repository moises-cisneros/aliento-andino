import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucideX,
  LucideBan,
  LucideCheckCircle,
  LucideAlertTriangle,
  LucideShield,
  LucideKey,
} from '@lucide/angular';

import { AdminUser } from '../../../core/models/admin-user.model';
import { UserAdminService, AdminUserDetail } from '../../../core/services/user-admin.service';

@Component({
  selector: 'app-user-detail-dialog',
  standalone: true,
  imports: [
    CommonModule,
    MatDialogModule,
    LucideX,
    LucideBan,
    LucideCheckCircle,
    LucideAlertTriangle,
    LucideShield,
    LucideKey,
  ],
  template: `
    <div class="dialog-wrapper">
      <div class="header">
        <div
          class="avatar"
          [style.backgroundImage]="
            'url(' +
            (user.avatar_url ||
              'https://ui-avatars.com/api/?name=' +
                user.full_name +
                '&background=06b6d4&color=fff') +
            ')'
          "
        ></div>
        <div class="header-info">
          <h2>{{ user.full_name }}</h2>
          <span class="username-label">&#64;{{ user.username }}</span>
          @if (user.is_admin) {
            <span class="chip chip-purple">Admin</span>
          }
          @if (user.is_banned) {
            <span class="chip chip-solid-error">Baneado</span>
          }
        </div>
        <button class="btn-icon close-btn" mat-dialog-close>
          <svg lucideX [size]="18"></svg>
        </button>
      </div>

      <hr class="divider" />

      <div class="body">
        <div class="info-grid">
          <div class="info-item">
            <span class="label">Email</span>
            <span class="value">{{ user.email }}</span>
          </div>
          <div class="info-item">
            <span class="label">Nivel XP</span>
            <span class="value level">Lv. {{ user.xp_level }}</span>
          </div>
          <div class="info-item">
            <span class="label">Posts</span>
            <span class="value">{{ user.posts_count }}</span>
          </div>
          <div class="info-item">
            <span class="label">Seguidores</span>
            <span class="value">{{ user.followers_count }}</span>
          </div>
          <div class="info-item">
            <span class="label">Registrado</span>
            <span class="value">{{ user.created_at | date: 'dd/MM/yyyy HH:mm' }}</span>
          </div>
          <div class="info-item">
            <span class="label">Estado</span>
            <span class="value">{{ user.is_active ? 'Activo' : 'Inactivo' }}</span>
          </div>
        </div>

        @if (detail(); as d) {
          <div class="activity">
            <div class="activity-item">
              <span class="a-val">{{ d.practice.sessions }}</span><span class="a-lbl"
                >Prácticas</span
              >
            </div>
            <div class="activity-item">
              <span class="a-val">{{
                d.practice.avg_score !== null ? d.practice.avg_score + '%' : '—'
              }}</span><span class="a-lbl">Score promedio</span>
            </div>
            <div class="activity-item">
              <span class="a-val">{{ d.practice.distinct_lessons }}</span><span class="a-lbl"
                >Lecciones</span
              >
            </div>
            <div class="activity-item">
              <span class="a-val" [class.premium]="d.is_premium">{{
                d.is_premium ? 'Premium' : 'Free'
              }}</span><span class="a-lbl">Suscripción</span>
            </div>
          </div>
        }

        @if (user.is_banned && user.ban_reason) {
          <div class="ban-info">
            <svg lucideAlertTriangle [size]="20" class="icon-error"></svg>
            <div>
              <strong>Motivo del ban:</strong>
              <p>{{ user.ban_reason }}</p>
            </div>
          </div>
        }
      </div>

      <hr class="divider" />

      <div class="actions">
        @if (!user.is_banned) {
          <button class="btn btn-danger" (click)="ban()">
            <svg lucideBan [size]="16"></svg> Banear usuario
          </button>
        } @else {
          <button class="btn btn-success" (click)="unban()">
            <svg lucideCheckCircle [size]="16"></svg> Desbanear usuario
          </button>
        }
        <button class="btn btn-ghost" (click)="toggleAdmin()">
          <svg lucideShield [size]="16"></svg> {{ user.is_admin ? 'Quitar admin' : 'Hacer admin' }}
        </button>
        <button class="btn btn-ghost" (click)="resetPassword()">
          <svg lucideKey [size]="16"></svg> Resetear contraseña
        </button>
        <button class="btn btn-ghost" mat-dialog-close>Cerrar</button>
      </div>
    </div>
  `,
  styles: [
    `
      .dialog-wrapper {
        color: var(--text-secondary);
      }

      .header {
        display: flex;
        align-items: center;
        gap: 16px;
        padding: 20px 24px 16px;
        position: relative;
      }
      .avatar {
        width: 60px;
        height: 60px;
        border-radius: 50%;
        background-size: cover;
        background-position: center;
        background-color: var(--bg-muted);
        flex-shrink: 0;
      }
      .header-info {
        display: flex;
        flex-direction: column;
        gap: 4px;
      }
      .header-info h2 {
        margin: 0;
        font-size: 18px;
        color: var(--text-primary);
      }
      .username-label {
        color: var(--color-primary);
        font-size: 14px;
      }
      .close-btn {
        position: absolute;
        right: 12px;
        top: 12px;
      }

      .divider {
        border: none;
        border-top: 1px solid var(--bg-border);
        margin: 0;
      }

      .body {
        padding: 20px 24px;
      }
      .info-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 16px;
      }
      .info-item {
        display: flex;
        flex-direction: column;
        gap: 2px;
      }
      .label {
        font-size: 12px;
        color: var(--text-dimmed);
        text-transform: uppercase;
        letter-spacing: 0.5px;
      }
      .value {
        font-size: 15px;
        color: var(--text-secondary);
      }
      .value.level {
        background: linear-gradient(135deg, var(--color-primary), var(--color-success));
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        font-weight: 700;
      }

      .ban-info {
        display: flex;
        gap: 10px;
        background: var(--color-error-subtle);
        border: 1px solid rgba(239, 68, 68, 0.3);
        border-radius: 8px;
        padding: 12px;
        margin-top: 16px;
      }
      .ban-info strong {
        color: var(--color-error);
      }
      .ban-info p {
        margin: 4px 0 0;
        color: var(--text-tertiary);
        font-size: 14px;
      }

      .actions {
        display: flex;
        justify-content: flex-end;
        gap: 10px;
        padding: 16px 24px;
        flex-wrap: wrap;
      }

      .activity {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 10px;
        margin-top: 18px;
      }
      .activity-item {
        background: var(--bg-surface-alt);
        border: 1px solid var(--bg-border);
        border-radius: 10px;
        padding: 10px;
        text-align: center;
      }
      .a-val {
        display: block;
        font-size: 17px;
        font-weight: 700;
        color: var(--text-primary);
      }
      .a-val.premium {
        color: var(--color-success);
      }
      .a-lbl {
        display: block;
        font-size: 11px;
        color: var(--text-dimmed);
        margin-top: 2px;
      }
    `,
  ],
})
export class UserDetailDialogComponent implements OnInit {
  readonly user: AdminUser = inject(MAT_DIALOG_DATA);
  private readonly dialogRef = inject(MatDialogRef<UserDetailDialogComponent>);
  private readonly userService = inject(UserAdminService);
  private readonly snackBar = inject(MatSnackBar);

  readonly detail = signal<AdminUserDetail | null>(null);

  ngOnInit(): void {
    this.userService.getUserDetail(this.user.id).subscribe({
      next: (d) => this.detail.set(d),
      error: () => {
        this.snackBar.open('Error al cargar el detalle del usuario', 'OK', { duration: 3000 });
      },
    });
  }

  toggleAdmin(): void {
    const makeAdmin = !this.user.is_admin;
    const verb = makeAdmin ? 'dar admin a' : 'quitar admin a';
    if (!confirm(`¿Seguro que querés ${verb} ${this.user.username}?`)) return;
    this.userService.setAdmin(this.user.id, makeAdmin).subscribe({
      next: () => {
        this.snackBar.open(`Rol actualizado para ${this.user.username}`, 'OK', { duration: 3000 });
        this.dialogRef.close('refresh');
      },
      error: () => this.snackBar.open('Error al cambiar el rol', 'OK', { duration: 3000 }),
    });
  }

  resetPassword(): void {
    if (!confirm(`¿Enviar email de reseteo de contraseña a ${this.user.username}?`)) return;
    this.userService.resetPassword(this.user.id).subscribe({
      next: (r) => this.snackBar.open(r.message, 'OK', { duration: 4000 }),
      error: () => this.snackBar.open('Error al resetear', 'OK', { duration: 3000 }),
    });
  }

  ban(): void {
    const reason = prompt('Motivo del baneo:');
    if (!reason) return;

    this.userService.banUser(this.user.id, reason).subscribe({
      next: () => {
        this.snackBar.open(this.user.username + ' baneado', 'OK', { duration: 3000 });
        this.dialogRef.close('refresh');
      },
      error: () => this.snackBar.open('Error al banear', 'OK', { duration: 3000 }),
    });
  }

  unban(): void {
    this.userService.unbanUser(this.user.id).subscribe({
      next: () => {
        this.snackBar.open(this.user.username + ' desbaneado', 'OK', { duration: 3000 });
        this.dialogRef.close('refresh');
      },
      error: () => this.snackBar.open('Error al desbanear', 'OK', { duration: 3000 }),
    });
  }
}
