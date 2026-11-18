import { Component, signal, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { Router, ActivatedRoute, RouterLink } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { LucideEye, LucideEyeOff } from '@lucide/angular';

import { AuthService } from '../../../core/services/auth.service';
import { AuthResponse } from '../../../core/models/user.model';
import { LoadingSpinnerComponent } from '../../../shared/components/loading-spinner/loading-spinner.component';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    RouterLink,
    LoadingSpinnerComponent,
    LucideEye,
    LucideEyeOff,
  ],
  template: `
    <div class="login-page">
      <div class="login-container">
        <!-- Brand -->
        <div class="brand">
          <img src="logo.svg" alt="Aliento Andino" class="brand-logo" />
          <h1 class="brand-name">Aliento<span class="brand-ai">Andino</span></h1>
        </div>

        <!-- Form -->
        <form [formGroup]="loginForm" (ngSubmit)="onSubmit()" class="login-form">
          <div class="field">
            <input formControlName="email" type="email" placeholder="Email" autocomplete="email" />
            @if (loginForm.get('email')?.hasError('required') && loginForm.get('email')?.touched) {
              <span class="field-error">El email es obligatorio</span>
            }
            @if (loginForm.get('email')?.hasError('email') && loginForm.get('email')?.touched) {
              <span class="field-error">Email inválido</span>
            }
          </div>

          <div class="field">
            <div class="password-field">
              <input
                formControlName="password"
                [type]="hidePassword() ? 'password' : 'text'"
                placeholder="Contraseña"
                autocomplete="current-password"
              />
              <button type="button" class="toggle-pw" (click)="hidePassword.set(!hidePassword())">
                @if (hidePassword()) {
                  <svg lucideEyeOff [size]="16"></svg>
                } @else {
                  <svg lucideEye [size]="16"></svg>
                }
              </button>
            </div>
            @if (
              loginForm.get('password')?.hasError('required') && loginForm.get('password')?.touched
            ) {
              <span class="field-error">La contraseña es obligatoria</span>
            }
          </div>

          <button class="login-btn" type="submit" [disabled]="isLoading()">
            @if (isLoading()) {
              <app-loading-spinner />
            } @else {
              Iniciar sesión
            }
          </button>
        </form>

        <a routerLink="/auth/forgot-password" class="forgot">¿Olvidaste tu contraseña?</a>
      </div>
    </div>
  `,
  styles: [
    `
      .login-page {
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        background: var(--bg-body);
      }

      .login-container {
        width: 100%;
        max-width: 360px;
        padding: 0 24px;
        display: flex;
        flex-direction: column;
        align-items: center;
      }

      /* ── Brand ── */
      .brand {
        display: flex;
        flex-direction: column;
        align-items: center;
        margin-bottom: 48px;
      }

      .brand-logo {
        width: 56px;
        height: 56px;
        margin-bottom: 16px;
        filter: drop-shadow(0 0 8px var(--color-primary))
          drop-shadow(0 0 20px rgba(6, 182, 212, 0.3));
      }

      .brand-name {
        font-size: 26px;
        font-weight: 700;
        letter-spacing: -0.5px;
        color: var(--text-primary);
      }

      .brand-ai {
        color: var(--color-primary);
        margin-left: 6px;
        font-weight: 600;
      }

      /* ── Form ── */
      .login-form {
        width: 100%;
        display: flex;
        flex-direction: column;
        gap: 16px;
      }

      .field {
        display: flex;
        flex-direction: column;
      }

      .field input,
      .password-field input {
        width: 100%;
        height: 48px;
        padding: 0 16px;
        background: var(--bg-surface);
        border: 1px solid var(--bg-border);
        border-radius: 10px;
        color: var(--text-secondary);
        font-size: 14px;
        outline: none;
        transition: border-color 0.2s;
      }

      .field input::placeholder,
      .password-field input::placeholder {
        color: var(--text-dimmed);
      }

      .field input:focus,
      .password-field input:focus {
        border-color: var(--color-primary);
      }

      .password-field {
        position: relative;
      }

      .password-field input {
        padding-right: 44px;
      }

      .toggle-pw {
        position: absolute;
        right: 4px;
        top: 50%;
        transform: translateY(-50%);
        width: 36px;
        height: 36px;
        display: flex;
        align-items: center;
        justify-content: center;
        border: none;
        background: none;
        color: var(--text-dimmed);
        cursor: pointer;
        border-radius: 8px;
        transition: color 0.15s;
      }

      .toggle-pw:hover {
        color: var(--text-secondary);
      }

      .field-error {
        font-size: 12px;
        color: var(--color-error);
        margin-top: 6px;
        padding-left: 2px;
      }

      /* ── Button ── */
      .login-btn {
        width: 100%;
        height: 48px;
        margin-top: 8px;
        border: none;
        border-radius: 10px;
        background: var(--color-primary);
        color: #fff;
        font-size: 15px;
        font-weight: 600;
        cursor: pointer;
        transition: opacity 0.2s;
      }

      .login-btn:hover:not(:disabled) {
        opacity: 0.9;
      }
      .login-btn:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }

      /* ── Forgot ── */
      .forgot {
        margin-top: 24px;
        font-size: 13px;
        color: var(--text-dimmed);
        transition: color 0.15s;
      }

      .forgot:hover {
        color: var(--color-primary);
      }
    `,
  ],
})
export class LoginComponent implements OnInit {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private snackBar = inject(MatSnackBar);

  readonly hidePassword = signal(true);
  readonly isLoading = signal(false);

  loginForm: FormGroup = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required]],
  });

  ngOnInit(): void {
    const errorParam = this.route.snapshot.queryParamMap.get('error');
    if (errorParam === 'admin_required') {
      this.snackBar.open('No tenés permisos de administrador', 'Cerrar', {
        duration: 5000,
        panelClass: ['snackbar-error'],
      });
    }

    if (this.authService.isAuthenticated() && this.authService.isAdminUser()) {
      this.router.navigate(['/admin/dashboard']);
    }
  }

  onSubmit(): void {
    if (this.loginForm.invalid) {
      this.loginForm.markAllAsTouched();
      return;
    }

    this.isLoading.set(true);
    const { email, password } = this.loginForm.value;

    this.authService.login(email, password).subscribe({
      next: (res: AuthResponse) => {
        this.isLoading.set(false);

        if (!res.user.is_admin) {
          this.authService.logout();
          this.snackBar.open('No tenés permisos de administrador', 'Cerrar', {
            duration: 5000,
            panelClass: ['snackbar-error'],
          });
          return;
        }

        this.snackBar.open('Bienvenido, ' + res.user.full_name, 'OK', {
          duration: 3000,
          panelClass: ['snackbar-success'],
        });
        this.router.navigate(['/admin/dashboard']);
      },
      error: (err: { error?: { detail?: string } }) => {
        this.isLoading.set(false);
        const message = err.error?.detail ?? 'Error al iniciar sesión';
        this.snackBar.open(message, 'Cerrar', {
          duration: 5000,
          panelClass: ['snackbar-error'],
        });
      },
    });
  }
}
