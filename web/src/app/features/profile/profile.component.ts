import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { LucideUser, LucideCamera, LucideSave, LucideLock, LucideLogOut } from '@lucide/angular';

import { AuthService } from '../../core/services/auth.service';
import { StorageService } from '../../core/services/storage.service';
import { User } from '../../core/models/user.model';
import { environment } from '../../../environments/environment';

interface ProfileForm {
  full_name: string;
  username: string;
  bio: string;
  avatar_url: string;
}

interface PasswordForm {
  current_password: string;
  new_password: string;
  confirm_password: string;
}

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [CommonModule, FormsModule, LucideUser, LucideCamera, LucideSave, LucideLock, LucideLogOut],
  template: `
    <div class="profile-page">
      <h2 class="page-heading">Mi Perfil</h2>

      <!-- Avatar + info básica -->
      <div class="profile-header">
        <div class="avatar-wrapper">
          @if (user()?.avatar_url) {
            <img [src]="user()!.avatar_url" alt="Avatar" class="avatar-img" />
          } @else {
            <div class="avatar-placeholder">
              <svg lucideUser [size]="40"></svg>
            </div>
          }
          <label class="avatar-edit" title="Cambiar avatar">
            <svg lucideCamera [size]="16"></svg>
            <input type="file" accept="image/*" (change)="onAvatarChange($event)" hidden />
          </label>
        </div>
        <div class="profile-meta">
          <span class="profile-name">{{ user()?.full_name }}</span>
          <span class="profile-email">{{ user()?.email }}</span>
          <span class="profile-provider">
            Proveedor: {{ user()?.auth_provider === 'email' ? 'Email' : 'Google' }}
          </span>
        </div>
      </div>

      <!-- Formulario de perfil -->
      <section class="section">
        <h3 class="section-title">Información personal</h3>
        <form class="profile-form" (ngSubmit)="saveProfile()">
          <div class="form-row">
            <div class="form-group">
              <label for="full_name">Nombre completo</label>
              <input id="full_name" class="form-input" type="text"
                     [(ngModel)]="profileForm.full_name" name="full_name"
                     placeholder="Tu nombre completo" required />
            </div>
            <div class="form-group">
              <label for="username">Nombre de usuario</label>
              <input id="username" class="form-input" type="text"
                     [(ngModel)]="profileForm.username" name="username"
                     placeholder="username" required minlength="3" maxlength="50"
                     pattern="^[a-zA-Z0-9_]+$" />
            </div>
          </div>
          <div class="form-group">
            <label for="bio">Biografía</label>
            <textarea id="bio" class="form-textarea" rows="3"
                      [(ngModel)]="profileForm.bio" name="bio"
                      placeholder="Cuéntanos sobre ti..." maxlength="1000"></textarea>
          </div>
          <div class="form-group">
            <label for="avatar_url">URL del avatar</label>
            <input id="avatar_url" class="form-input" type="url"
                   [(ngModel)]="profileForm.avatar_url" name="avatar_url"
                   placeholder="https://ejemplo.com/avatar.jpg" />
          </div>
          <div class="form-actions">
            <button type="submit" class="btn btn-primary" [disabled]="savingProfile()">
              <svg lucideSave [size]="16"></svg>
              {{ savingProfile() ? 'Guardando...' : 'Guardar cambios' }}
            </button>
          </div>
          @if (profileMessage()) {
            <p class="msg" [class.msg-success]="profileSuccess()" [class.msg-error]="!profileSuccess()">
              {{ profileMessage() }}
            </p>
          }
        </form>
      </section>

      <!-- Cambiar contraseña -->
      @if (user()?.auth_provider === 'email') {
        <section class="section">
          <h3 class="section-title">
            <svg lucideLock [size]="18"></svg>
            Cambiar contraseña
          </h3>
          <form class="profile-form" (ngSubmit)="changePassword()">
            <div class="form-group">
              <label for="current_password">Contraseña actual</label>
              <input id="current_password" class="form-input" type="password"
                     [(ngModel)]="passwordForm.current_password" name="current_password"
                     required />
            </div>
            <div class="form-row">
              <div class="form-group">
                <label for="new_password">Nueva contraseña</label>
                <input id="new_password" class="form-input" type="password"
                       [(ngModel)]="passwordForm.new_password" name="new_password"
                       required minlength="8" />
              </div>
              <div class="form-group">
                <label for="confirm_password">Confirmar contraseña</label>
                <input id="confirm_password" class="form-input" type="password"
                       [(ngModel)]="passwordForm.confirm_password" name="confirm_password"
                       required minlength="8" />
              </div>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary" [disabled]="savingPassword()">
                <svg lucideSave [size]="16"></svg>
                {{ savingPassword() ? 'Cambiando...' : 'Cambiar contraseña' }}
              </button>
            </div>
            @if (passwordMessage()) {
              <p class="msg" [class.msg-success]="passwordSuccess()" [class.msg-error]="!passwordSuccess()">
                {{ passwordMessage() }}
              </p>
            }
          </form>
        </section>
      }

      <!-- Info de cuenta -->
      <section class="section">
        <h3 class="section-title">Información de la cuenta</h3>
        <div class="info-grid">
          <div class="info-item">
            <span class="info-label">Email</span>
            <span class="info-value">{{ user()?.email }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">Rol</span>
            <span class="info-value">{{ user()?.is_admin ? 'Administrador' : 'Usuario' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">Estado</span>
            <span class="info-value">{{ user()?.is_active ? 'Activo' : 'Inactivo' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">Registro</span>
            <span class="info-value">{{ user()?.created_at | date:'d MMM y' }}</span>
          </div>
        </div>
      </section>

      <!-- Cerrar sesión -->
      <section class="section">
        <button class="btn btn-logout" (click)="logout()">
          <svg lucideLogOut [size]="18"></svg>
          Cerrar sesión
        </button>
      </section>
    </div>
  `,
  styles: [`
    .profile-page {
      max-width: 720px;
      padding: 32px;
    }

    .page-heading {
      font-size: 22px;
      font-weight: 700;
      color: var(--text-primary);
      margin: 0 0 32px;
    }

    /* Avatar header */
    .profile-header {
      display: flex;
      align-items: center;
      gap: 24px;
      margin-bottom: 40px;
    }

    .avatar-wrapper {
      position: relative;
      width: 88px;
      height: 88px;
      flex-shrink: 0;
    }

    .avatar-img {
      width: 88px;
      height: 88px;
      border-radius: 50%;
      object-fit: cover;
    }

    .avatar-placeholder {
      width: 88px;
      height: 88px;
      border-radius: 50%;
      background: var(--bg-hover);
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--text-dimmed);
    }

    .avatar-edit {
      position: absolute;
      bottom: 0;
      right: 0;
      width: 28px;
      height: 28px;
      border-radius: 50%;
      background: var(--color-primary);
      color: #fff;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: opacity 0.15s;
    }

    .avatar-edit:hover {
      opacity: 0.85;
    }

    .profile-meta {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .profile-name {
      font-size: 18px;
      font-weight: 600;
      color: var(--text-primary);
    }

    .profile-email {
      font-size: 14px;
      color: var(--text-muted);
    }

    .profile-provider {
      font-size: 12px;
      color: var(--text-dimmed);
    }

    /* Sections */
    .section {
      margin-bottom: 40px;
    }

    .section-title {
      font-size: 15px;
      font-weight: 600;
      color: var(--text-secondary);
      margin: 0 0 20px;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    /* Form */
    .profile-form {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .form-row {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
    }

    .form-actions {
      display: flex;
      padding-top: 4px;
    }

    .form-actions .btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
    }

    /* Messages */
    .msg {
      font-size: 13px;
      font-weight: 500;
      margin: 0;
    }

    .msg-success { color: var(--color-success); }
    .msg-error { color: var(--color-error); }

    /* Info grid */
    .info-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
    }

    .info-item {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .info-label {
      font-size: 12px;
      font-weight: 500;
      color: var(--text-dimmed);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .info-value {
      font-size: 14px;
      color: var(--text-secondary);
    }

    @media (max-width: 600px) {
      .profile-page { padding: 20px 16px; }
      .form-row { grid-template-columns: 1fr; }
      .info-grid { grid-template-columns: 1fr; }
      .profile-header { flex-direction: column; text-align: center; align-items: center; }
    }

    .btn-logout {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 10px 20px;
      border: 1px solid var(--color-error);
      background: none;
      color: var(--color-error);
      border-radius: 8px;
      font-size: 14px;
      font-weight: 500;
      cursor: pointer;
      transition: background 0.15s, color 0.15s;
    }

    .btn-logout:hover {
      background: var(--color-error);
      color: #fff;
    }
  `],
})
export class ProfileComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly storage = inject(StorageService);
  private readonly http = inject(HttpClient);
  private readonly apiUrl = `${environment.apiBaseUrl}/auth`;

  readonly user = this.authService.currentUser;

  profileForm: ProfileForm = { full_name: '', username: '', bio: '', avatar_url: '' };
  passwordForm: PasswordForm = { current_password: '', new_password: '', confirm_password: '' };

  readonly savingProfile = signal(false);
  readonly profileMessage = signal('');
  readonly profileSuccess = signal(false);

  readonly savingPassword = signal(false);
  readonly passwordMessage = signal('');
  readonly passwordSuccess = signal(false);

  ngOnInit(): void {
    const u = this.user();
    if (u) {
      this.profileForm = {
        full_name: u.full_name || '',
        username: u.username || '',
        bio: u.bio || '',
        avatar_url: u.avatar_url || '',
      };
    }
  }

  saveProfile(): void {
    this.savingProfile.set(true);
    this.profileMessage.set('');

    const body: Record<string, string | null> = {};
    if (this.profileForm.full_name) body['full_name'] = this.profileForm.full_name;
    if (this.profileForm.username) body['username'] = this.profileForm.username;
    body['bio'] = this.profileForm.bio || null;
    body['avatar_url'] = this.profileForm.avatar_url || null;

    this.http.put<User>(`${this.apiUrl}/me`, body).subscribe({
      next: (updated) => {
        this.authService.currentUser.set(updated);
        this.authService.currentUser$.next(updated);
        this.storage.setUser(updated);
        this.profileMessage.set('Perfil actualizado correctamente');
        this.profileSuccess.set(true);
        this.savingProfile.set(false);
      },
      error: (err) => {
        const detail = err.error?.detail;
        this.profileMessage.set(
          typeof detail === 'string' ? detail : 'Error al actualizar el perfil'
        );
        this.profileSuccess.set(false);
        this.savingProfile.set(false);
      },
    });
  }

  changePassword(): void {
    if (this.passwordForm.new_password !== this.passwordForm.confirm_password) {
      this.passwordMessage.set('Las contraseñas no coinciden');
      this.passwordSuccess.set(false);
      return;
    }
    if (this.passwordForm.new_password.length < 8) {
      this.passwordMessage.set('La contraseña debe tener al menos 8 caracteres');
      this.passwordSuccess.set(false);
      return;
    }

    this.savingPassword.set(true);
    this.passwordMessage.set('');

    this.http.put<{ message: string }>(`${this.apiUrl}/change-password`, {
      current_password: this.passwordForm.current_password,
      new_password: this.passwordForm.new_password,
    }).subscribe({
      next: (res) => {
        this.passwordMessage.set(res.message || 'Contraseña actualizada correctamente');
        this.passwordSuccess.set(true);
        this.passwordForm = { current_password: '', new_password: '', confirm_password: '' };
        this.savingPassword.set(false);
      },
      error: (err) => {
        const detail = err.error?.detail;
        this.passwordMessage.set(
          typeof detail === 'string' ? detail : 'Error al cambiar la contraseña'
        );
        this.passwordSuccess.set(false);
        this.savingPassword.set(false);
      },
    });
  }

  onAvatarChange(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (!input.files?.length) return;

    const file = input.files[0];
    const reader = new FileReader();
    reader.onload = () => {
      // For now, just set the data URL as preview — a real impl would upload to backend
      this.profileForm.avatar_url = reader.result as string;
    };
    reader.readAsDataURL(file);
  }

  logout(): void {
    this.authService.logout();
  }
}
