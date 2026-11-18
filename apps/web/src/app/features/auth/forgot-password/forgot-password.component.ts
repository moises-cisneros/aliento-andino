import { Component, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { LucideArrowLeft, LucideCheckCircle } from '@lucide/angular';

import { AuthService } from '../../../core/services/auth.service';
import { LoadingSpinnerComponent } from '../../../shared/components/loading-spinner/loading-spinner.component';

@Component({
  selector: 'app-forgot-password',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    RouterLink,
    LoadingSpinnerComponent,
    LucideArrowLeft,
    LucideCheckCircle,
  ],
  template: `
    <div class="page">
      <div class="container">
        <!-- Brand -->
        <div class="brand">
          <img src="logo.svg" alt="Aliento Andino" class="brand-logo" />
          <h1 class="brand-name">Aliento<span class="brand-ai">Andino</span></h1>
        </div>

        @if (!emailSent()) {
          <p class="subtitle">Ingresá tu email para recuperar tu contraseña</p>

          <form [formGroup]="forgotForm" (ngSubmit)="onSubmit()" class="form">
            <div class="field">
              <input
                formControlName="email"
                type="email"
                placeholder="Email"
                autocomplete="email"
              />
              @if (
                forgotForm.get('email')?.hasError('required') && forgotForm.get('email')?.touched
              ) {
                <span class="field-error">El email es obligatorio</span>
              }
              @if (forgotForm.get('email')?.hasError('email') && forgotForm.get('email')?.touched) {
                <span class="field-error">Email inválido</span>
              }
            </div>

            <button class="action-btn" type="submit" [disabled]="isLoading()">
              @if (isLoading()) {
                <app-loading-spinner />
              } @else {
                Enviar código
              }
            </button>
          </form>
        } @else {
          <div class="success">
            <svg lucideCheckCircle [size]="40" class="success-icon"></svg>
            <p class="success-text">Te enviamos un código de 6 dígitos a tu email.</p>
            <button class="action-btn" (click)="goToReset()">Ingresar código</button>
          </div>
        }

        <a routerLink="/auth/login" class="back-link">
          <svg lucideArrowLeft [size]="15"></svg>
          Volver al inicio de sesión
        </a>
      </div>
    </div>
  `,
  styles: [
    `
      .page {
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        background: var(--bg-body);
      }

      .container {
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
        margin-bottom: 32px;
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

      .subtitle {
        color: var(--text-dimmed);
        font-size: 14px;
        text-align: center;
        margin-bottom: 32px;
      }

      /* ── Form ── */
      .form {
        width: 100%;
        display: flex;
        flex-direction: column;
        gap: 16px;
      }

      .field {
        display: flex;
        flex-direction: column;
      }

      .field input {
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

      .field input::placeholder {
        color: var(--text-dimmed);
      }
      .field input:focus {
        border-color: var(--color-primary);
      }

      .field-error {
        font-size: 12px;
        color: var(--color-error);
        margin-top: 6px;
        padding-left: 2px;
      }

      /* ── Button ── */
      .action-btn {
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

      .action-btn:hover:not(:disabled) {
        opacity: 0.9;
      }
      .action-btn:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }

      /* ── Success ── */
      .success {
        width: 100%;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 16px;
      }

      .success-icon {
        color: var(--color-success);
      }

      .success-text {
        color: var(--text-muted);
        font-size: 14px;
        text-align: center;
        line-height: 1.5;
      }

      /* ── Back ── */
      .back-link {
        margin-top: 28px;
        font-size: 13px;
        color: var(--text-dimmed);
        display: inline-flex;
        align-items: center;
        gap: 4px;
        transition: color 0.15s;
      }

      .back-link:hover {
        color: var(--color-primary);
      }
    `,
  ],
})
export class ForgotPasswordComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private snackBar = inject(MatSnackBar);
  private router = inject(Router);

  readonly isLoading = signal(false);
  readonly emailSent = signal(false);

  forgotForm: FormGroup = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
  });

  onSubmit(): void {
    if (this.forgotForm.invalid) {
      this.forgotForm.markAllAsTouched();
      return;
    }

    this.isLoading.set(true);
    const { email } = this.forgotForm.value;

    this.authService.forgotPassword(email).subscribe({
      next: () => {
        this.isLoading.set(false);
        this.emailSent.set(true);
      },
      error: (err: { error?: { detail?: string } }) => {
        this.isLoading.set(false);
        const message = err.error?.detail ?? 'Error al enviar el email';
        this.snackBar.open(message, 'Cerrar', {
          duration: 5000,
          panelClass: ['snackbar-error'],
        });
      },
    });
  }

  goToReset(): void {
    this.router.navigate(['/auth/reset-password']);
  }
}
